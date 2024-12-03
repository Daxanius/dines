;******************************************************************
; neslib.s: NES Function Library
;******************************************************************

; Define PPU Registers
PPU_CONTROL = $2000
PPU_MASK = $2001
PPU_STATUS = $2002         ; Current status of the PPU https://www.nesdev.org/wiki/PPU_registers#PPUSTATUS
PPU_SPRRAM_ADDRESS = $2003
PPU_SPRRAM_IO = $2004
PPU_SCROLL_ADDRESS = $2005 ; The PPU scroll adress
PPU_VRAM_ADDRESS = $2006  ; The PPU VRam set address
PPU_VRAM_IO = $2007       ; VRAM Data, accessing this register increments the VRAM, data can be reat to the PPU with this https://www.nesdev.org/wiki/PPU_registers#PPUDATA
SPRITE_DMA = $4014        ; A register that suspends the CPU and quickly copies 256 bytes of data to the PPU OAM https://www.nesdev.org/wiki/PPU_registers#OAMDMA_-_Sprite_DMA_($4014_write)

; Control register masks for the PPU
NT_2000 = $00
NT_2400 = $01
NT_2800 = $02
NT_2C00 = $03
VRAM_DOWN = $04
OBJ_0000 = $00
OBJ_1000 = $08
OBJ_8X16 = $20
BG_0000 = $00 ;
BG_1000 = $10
VBLANK_NMI = $80
BG_OFF = $00
BG_CLIP = $08
BG_ON = $0A
OBJ_OFF = $00
OBJ_CLIP = $10
OBJ_ON = $14

; OAM attributes
OAM_PALLETTE0 = 0
OAM_PALLETTE1 = 1
OAM_PALLETTE2 = 2
OAM_PALLETTE3 = 3
OAM_BEHIND_BACKGROUND = 8
OAM_FLIP_HORIZONTAL = 16
OAM_FLIP_VERTICAL = 32

; APU Register values
APU_DM_CONTROL = $4010
APU_CLOCK = $4015

; Joystick/Controller values
JOYPAD1 = $4016
JOYPAD2 = $4017

; Gamepad bit values
PAD_A = $01
PAD_B = $02
PAD_SELECT = $04
PAD_START = $08
PAD_U = $10
PAD_D = $20
PAD_L = $40
PAD_R = $80

; Useful PPU memory addresses
NAME_TABLE_0_ADDRESS = $2000
ATTRIBUTE_TABLE_0_ADDRESS = $23C0
NAME_TABLE_1_ADDRESS = $2400
ATTRIBUTE_TABLE_1_ADDRESS = $27C0

.segment "ZEROPAGE"

nmi_ready: .res 1

ppu_ctl: .res 1
ppu_mask: .res 1

gamepad: .res 1

operation_address: .res 2 ; The address used for multiple functions such as for text drawing, multiplication and division

seed: .res 2 ; Defined a seed variable

.include "macros.s"

.segment "CODE"

.proc wait_frame    ; Waits until the nmi interrupt has been called, allowing us to update the PPU
    INC nmi_ready   ; Increments nmi ready so that we can wait for a frame
@loop:
    LDA nmi_ready   ; Check the status of the screen
    BNE @loop
    RTS
.endproc

.proc ppu_update
    LDA ppu_ctl
    ORA #VBLANK_NMI
    STA ppu_ctl
    STA PPU_CONTROL
    LDA ppu_mask
    ORA #OBJ_ON|BG_ON
    STA ppu_mask
    JSR wait_frame
    RTS
.endproc

.proc ppu_off
    JSR wait_frame
    LDA ppu_ctl
    AND #%01111111
    STA ppu_ctl
    STA PPU_CONTROL
    LDA ppu_mask
    AND #%11100001
    STA ppu_mask
    STA PPU_MASK
    RTS
.endproc

; Clears the background (nametable + attribute table)
.proc clear_nametable
        LDA PPU_STATUS  ; Resets the PPU w latch

        ; Starting at PPU ADDRESS 2000 we will start resetting everything
        LDA #$20             ; Stores 20 into a, which will be set as the VRAM address
        STA PPU_VRAM_ADDRESS ; Store 20 into the PPU VRAM address

        LDA #$00             ; Set a to 00
        STA PPU_VRAM_ADDRESS ; Store 00 into the PPU VRAM address

        LDA #0  ; Set a to 0, which will be used to set the PPU nametable value to 0
        LDY #30 ; Rows
    rowloop:
        LDX #32 ; Columns
        columnloop:
            STA PPU_VRAM_IO ; Store A in the current PPU Vram slot
            DEX             ; Decrement the column index
            BNE columnloop  ; Jump back to columnloop if we aren't done yet
            DEY             ; Decrement the row index
            BNE rowloop     ; Jump back to row loop if there's rows left
    
    LDX #64 ; Clear the attribute table containing 64 elements
    loop:
        STA PPU_VRAM_IO ; Store A into the attribute table address
        DEX             ; Decrement the index
        BNE loop        ; Continue looping through the attribute table if we aren't done yet

    RTS
.endproc

; Fetches the gamepad state bit by bit
.proc gamepad_poll
        LDA #1      ; Set the listen bit to 1
        STA JOYPAD1 ; Send a to the first joypad, indicating that we are listening
        LDA #0      ; Stop the polling
        STA JOYPAD1 ; Send the stop request to the joypay
        LDX #8      ; Since a byte is 8 bits, we only need to loop 8 times
    loop:
        PHA         ; Store A which holds the current in progress joypad byte
        LDA JOYPAD1 ; Get the next joypad bit 
        AND #%00000011 ; Only use the relevant bits the joypad sent
        CMP #%00000001 ; Move the joypad button bit into the status
        PLA            ; Get a from the stack
        ROR            ; Rotate the joypad value into A from the status
        DEX            ; Decrement X for the loop
        BNE loop       ; Continue looping until all 8 bits are read

    STA gamepad        ; Store a into the gamepad value
    RTS                ; Return from the subroutine
.endproc

; Writes text stored in operation_address to the PPU VRam until a null terminator is encountered
; This function assumes the PPU Vram address pointer is set to a valid OAM or nametable address
.proc write_text
    LDY #0  ; The index of the loop used to index characters
    loop:
        LDA (operation_address),y ; Store the current letter with offset y into a
        BEQ exit             ; If we encountered 0, which is the null terminator, return from the loop
        STA PPU_VRAM_IO      ; Store the character into the PPU vram
        INY                  ; Increment the indexing
        JMP loop             ; Loop again (no null terminator encountered yet)
    exit:                    ; Just an exit label to make exiting early from the loop easy
        RTS
.endproc

; Multiplies the 8 bit value in operation address by A and stores the result in A
.proc multiply
    CMP #0 ; Check if A is not already 0
    TAY    ; Moves A into y
    LDA #0 ; Gets the value that should by multiplied by A
    loop:
        BEQ loop               ; Loop if we haven't reached zero yet
        CLC                    ; Clear the carry
        ADC operation_address  ; Add a to operation_address
        DEY                    ; Decrements Y
    RTS
.endproc

; Divides A by the 8 bit value stored in operation address, stores the result in A and the remainder in Y
.proc divide
    LDX #0                ; Put 0 in X
    CPX operation_address ; Check if the operation_address is 0
    BEQ divide_by_zero    ; If operation_address is 0 we can't divide so branch to a subroutine exit

    LDY #0                ; Initialize the remainder (Y) to 0
    LDX #0                ; Initialize the quotient (X) to 0
    
divide_loop:
    CMP operation_address ; Compare current remainder (A) to divisor
    BCC done_divide       ; If remainder < divisor, division is complete
    SEC                   ; Set the carry flag for subtraction
    SBC operation_address ; Subtract divisor from current remainder
    INX                   ; Increment quotient in X
    JMP divide_loop       ; Repeat until remainder < divisor

done_divide:
    TAY                   ; Move the remainder from A to Y
    TXA                   ; Store the quotient in A
    RTS                   ; Return with result

divide_by_zero:
    LDY #0                ; Set the remainder as 0
    RTS                   ; Leave subroutine
.endproc

; Returns a random 8-bit number in A (0-255), clobbers Y (unknown).
; I don't fully understand how this works, but it works, and that's what matters
.proc prng
	LDA seed+1
	TAY ; store copy of high byte

	LSR ; shift to consume zeroes on left...
	LSR
	LSR
	STA seed+1 ; now recreate the remaining bits in reverse order... %111
	LSR
	EOR seed+1
	LSR
	EOR seed+1
	EOR seed+0 ; recombine with original low byte
	STA seed+1

	; compute seed+0 ($39 = %111001)
	TYA ; original high byte
	STA seed+0
	ASL
	EOR seed+0
	ASL
	EOR seed+0
	ASL
	ASL
	ASL
	EOR seed+0
	STA seed+0
	RTS
.endproc

; Sets A to its absolute value
.proc abs
    CMP #0
    BPL done          ; If A is positive (bit 7 is 0), skip the negation
    EOR #$FF          ; Invert all bits (Two's complement step 1)
    CLC               ; Clear carry for addition
    ADC #$01          ; Add 1 (Two's complement step 2)
done:
    RTS               ; Return from subroutine
.endproc

; Checks collision between 2 OAM sprites stored in Y and X, sets A to 1 if there was a collision detected
.proc check_collision
    ; Calculate the difference in X positions
    LDA oam+3, x     ; Load X position of sprite X
    CLC
    SBC oam+3, y     ; Subtract X position of sprite Y
    JSR abs          ; Get the absolute value for the distance
    CMP #8           ; Check if result is within sprite width
    BPL no_overlap   ; If result >= 8, no overlap on X-axis

    ; Calculate the difference in Y positions
    LDA oam, x       ; Load Y position of sprite X
    CLC
    SBC oam, y       ; Subtract Y position of sprite Y
    JSR abs          ; Get the absolute value for the distance
    CMP #8           ; Check if result is within sprite height
    BPL no_overlap   ; If result >= 8, no overlap on Y-axis

    ; If both X and Y overlap, return true
    LDA #1             ; Set A to 1 to indicate collision
    RTS

no_overlap:
    ; No collision
    LDA #0             ; Set A to 0 to indicate no collision
    RTS
.endproc