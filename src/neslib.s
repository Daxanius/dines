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
NAME_TABLE_1_ADDRESS = $2800
ATTRIBUTE_TABLE_1_ADDRESS = $2BC0

.segment "ZEROPAGE"
nmi_ready: .res 1

ppu_ctl: .res 1
ppu_mask: .res 1

ppu_scroll_x: .res 1

gamepad: .res 1

last_oam_idx: .res 1 ; Used to optimize the cactus delete function
oam_idx: .res 1 ; The current index of the OAM we're drawing to
oam_px: .res 1  ; Determines the x position the next sprite will be drawn to
oam_py: .res 1  ; Determines the Y position the next sprite will be drawn to

sfx_channel: .res 1 ; Sound effect channel to use

operation_address: .res 2 ; The address used for multiple functions such as for text drawing, multiplication and division
seed: .res 2 ; Defined a seed variable
temp: .res 6

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
.proc clear_nametable0
        LDA PPU_STATUS  ; Resets the PPU w latch

        ; Starting at PPU ADDRESS 2000 we will start resetting everything
        LDA #>NAME_TABLE_0_ADDRESS  ; Stores 20 into a, which will be set as the VRAM address
        STA PPU_VRAM_ADDRESS        ; Store 20 into the PPU VRAM address

        LDA #<NAME_TABLE_0_ADDRESS  ; Set a to 00
        STA PPU_VRAM_ADDRESS ; Store 00 into the PPU VRAM address

        LDA #0  ; Set a to 0, which will be used to set the PPU nametable value to 0
        LDY #30 ; Rows
    @rowloop:
        LDX #32 ; Columns
        @columnloop:
            STA PPU_VRAM_IO ; Store A in the current PPU Vram slot
            DEX             ; Decrement the column index
            BNE @columnloop  ; Jump back to columnloop if we aren't done yet
            DEY             ; Decrement the row index
            BNE @rowloop     ; Jump back to row loop if there's rows left
    
    LDX #64 ; Clear the attribute table containing 64 elements
    @loop:
        STA PPU_VRAM_IO ; Store A into the attribute table address
        DEX             ; Decrement the index
        BNE @loop        ; Continue looping through the attribute table if we aren't done yet

    RTS
.endproc

; Clears the second nametable
.proc clear_nametable1
        LDA PPU_STATUS  ; Resets the PPU w latch

        ; Starting at PPU ADDRESS 2000 we will start resetting everything
        LDA #>NAME_TABLE_1_ADDRESS  ; Stores 20 into a, which will be set as the VRAM address
        STA PPU_VRAM_ADDRESS        ; Store 20 into the PPU VRAM address

        LDA #<NAME_TABLE_1_ADDRESS  ; Set a to 00
        STA PPU_VRAM_ADDRESS        ; Store 00 into the PPU VRAM address

        LDA #0  ; Set a to 0, which will be used to set the PPU nametable value to 0
        LDY #30 ; Rows
    @rowloop:
        LDX #32 ; Columns
        @columnloop:
            STA PPU_VRAM_IO ; Store A in the current PPU Vram slot
            DEX             ; Decrement the column index
            BNE @columnloop  ; Jump back to columnloop if we aren't done yet
            DEY             ; Decrement the row index
            BNE @rowloop     ; Jump back to row loop if there's rows left
    
    LDX #64 ; Clear the attribute table containing 64 elements
    @loop:
        STA PPU_VRAM_IO ; Store A into the attribute table address
        DEX             ; Decrement the index
        BNE @loop        ; Continue looping through the attribute table if we aren't done yet

    RTS
.endproc

; Fetches the gamepad state bit by bit
.proc gamepad_poll
        LDA #1      ; Set the listen bit to 1
        STA JOYPAD1 ; Send a to the first joypad, indicating that we are listening
        LDA #0      ; Stop the polling
        STA JOYPAD1 ; Send the stop request to the joypay
        LDX #8      ; Since a byte is 8 bits, we only need to loop 8 times
    @loop:
        PHA         ; Store A which holds the current in progress joypad byte
        LDA JOYPAD1 ; Get the next joypad bit 
        AND #%00000011 ; Only use the relevant bits the joypad sent
        CMP #%00000001 ; Move the joypad button bit into the status
        PLA            ; Get a from the stack
        ROR            ; Rotate the joypad value into A from the status
        DEX            ; Decrement X for the loop
        BNE @loop       ; Continue looping until all 8 bits are read

    STA gamepad        ; Store a into the gamepad value
    RTS                ; Return from the subroutine
.endproc

; Writes text stored in operation_address to the PPU VRam until a null terminator is encountered
; This function assumes the PPU Vram address pointer is set to a valid OAM or nametable address
.proc write_text
    LDY #0  ; The index of the loop used to index characters
    @loop:
        LDA (operation_address),y ; Store the current letter with offset y into a
        BEQ @exit             ; If we encountered 0, which is the null terminator, return from the loop
        STA PPU_VRAM_IO      ; Store the character into the PPU vram
        INY                  ; Increment the indexing
        JMP @loop             ; Loop again (no null terminator encountered yet)
    @exit:                    ; Just an exit label to make exiting early from the loop easy
        RTS
.endproc

; Multiplies the 8 bit value in operation address by A and stores the result in A
.proc multiply
    CMP #0 ; Check if A is not already 0
    TAY    ; Moves A into y
    LDA #0 ; Gets the value that should by multiplied by A
    @loop:
        BEQ @loop               ; Loop if we haven't reached zero yet
        CLC                    ; Clear the carry
        ADC operation_address  ; Add a to operation_address
        DEY                    ; Decrements Y
    RTS
.endproc

; Divides A by the 8 bit value stored in operation address, stores the result in A and the remainder in Y
.proc divide
    LDX #0                ; Put 0 in X
    LDY #0                ; Initialize the remainder (Y) to 0

    CPX operation_address ; Check if the operation_address is 0
    BEQ @return           ; If operation_address is 0 we can't divide so branch to a subroutine exit
    
@divide_loop:
    CMP operation_address ; Compare current remainder (A) to divisor
    BCC @done_divide      ; If remainder < divisor, division is complete
    SEC                   ; Set the carry flag for subtraction
    SBC operation_address ; Subtract divisor from current remainder
    INX                   ; Increment quotient in X
    JMP @divide_loop      ; Repeat until remainder < divisor

@done_divide:
    TAY                   ; Move the remainder from A to Y
    TXA                   ; Store the quotient in A

@return:
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

.proc add_score
    CLC
    ADC score
    sta score
    cmp #99
    bcc @skip

    SEC
    SBC #100
    STA score
    INC score+1
    LDA score+1
    CMP #99
    BCC @skip

    SEC
    SBC #100
    STA score+1
    INC score+2
    LDA score+2
    CMP #99
    BCC @skip
    SEC 
    SBC #100
    STA score+2

@skip:
    RTS
.endproc

;stores output in A and X
.proc dec99_to_string
    LDX #0
    CMP #50
    BCC @try20  ;branch if dec99 < 50
    SBC #50     
    LDX #5
    BNE @try20

@div20:
    INX
    INX
    SBC #20

@try20:
    CMP #20
    BCS @div20 ;branch if dec99 > 20


@try10:
    CMP #10     
    BCC @finished   ;branch if dec99 < 10
    SBC #10
    INX

@finished:
    RTS
.endproc

.proc display_score
    LDA score+2
    JSR dec99_to_string

    STX temp
    STA temp+1

    LDA score+1
    JSR dec99_to_string
    STX temp+2
    STA temp+3

    LDA score
    JSR dec99_to_string
    STX temp+4
    STA temp+5

    LDA #((255/2)-((8*6)/2)+4) ; The X position
    STA operation_address      ; Store it in op address

    LDX #252              ; Start at last OAM slot
    LDY #0                ; Store 0 in Y
    @loop:
        ; Store the character
        LDA temp, y  ; Get the to string converted character
        CLC          ; Clear carry
        ADC #48      ; Add 48 to get to character tiles
        STA oam+1, x ; Set the tile index

        ; Store the Y position
        LDA #8
        STA oam, x

        ; Store the X position
        LDA operation_address
        STA oam+3, x

        ; Store the properties
        LDA #0                ; No special properties
        STA oam+2, x

        ; Decrement X for the next oam entry
        DEX
        DEX
        DEX
        DEX

        ; Move to the next digit
        INY                   ; Increment Y

        ; Adjust X position for next sprite
        LDA operation_address
        CLC
        ADC #8
        STA operation_address

        CPY #6                ; If we have stored all characters
        BNE @loop             ; Then continue looping

    RTS
.endproc

; Sets A to its inverse
.proc inv
    EOR #$FF          ; Invert all bits (Two's complement step 1)
    CLC               ; Clear carry for addition
    ADC #$01          ; Add 1 (Two's complement step 2)
    RTS               ; Return from subroutine
.endproc

; Sets A to its absolute value
.proc abs
    CMP #0
    BPL @done          ; If A is positive (bit 7 is 0), skip the negation
    EOR #$FF          ; Invert all bits (Two's complement step 1)
    CLC               ; Clear carry for addition
    ADC #$01          ; Add 1 (Two's complement step 2)
@done:
    RTS               ; Return from subroutine
.endproc

; Checks collision between 2 OAM sprites stored in Y and X, sets A to 1 if there was a collision detected
.proc check_collision
    ; Calculate the difference in X positions
    LDA oam+3, x     ; Load X position of sprite X
    SEC              ; Set carry for subtraction
    SBC oam+3, y     ; Subtract X position of sprite Y

    ; JSR abs          ; Get the absolute value for the distance
    ; The absolute without JSR, saving 6 cycles
    CMP #0
    BPL @done_abs_x   ; If A is positive (bit 7 is 0), skip the negation
    EOR #$FF          ; Invert all bits (Two's complement step 1)
    CLC               ; Clear carry for addition
    ADC #$01          ; Add 1 (Two's complement step 2)

@done_abs_x:
    CMP #8           ; Check if result is within sprite width
    BCS @no_overlap  ; If result >= 8, no overlap on X-axis

    ; Calculate the difference in Y positions
    LDA oam, x       ; Load Y position of sprite X
    SEC              ; Set carry for subtraction
    SBC oam, y       ; Subtract Y position of sprite Y
    
    ;JSR abs          ; Get the absolute value for the distance
    ; The absolute without JSR, saving 6 cycles
    CMP #0
    BPL @done_abs_y   ; If A is positive (bit 7 is 0), skip the negation
    EOR #$FF          ; Invert all bits (Two's complement step 1)
    CLC               ; Clear carry for addition
    ADC #$01          ; Add 1 (Two's complement step 2)

@done_abs_y:
    CMP #8           ; Check if result is within sprite height
    BCS @no_overlap  ; If result >= 8, no overlap on Y-axis

    ; If both X and Y overlap, return true
    LDA #1           ; Set A to 1 to indicate collision
    RTS

@no_overlap:
    ; No collision
    LDA #0           ; Set A to 0 to indicate no collision
    RTS
.endproc

; Draws a sprite with index of A to the OAM, optionally, the value in operation_address may be used for properties
; Make sure to set it to 0 before drawing a sprite otherwise
.proc draw_sprite
	LDX oam_idx
	STA oam+1, x ; Store the tile index in the oam

	LDA oam_py   ; Load the desired y position
	STA oam, x   ; Store the desired y position in the oam

	LDA oam_px	  ; Load the desired x position
	sta oam+3, x  ; Store the x position in the oam

	LDA operation_address ; Sprite OAM properties, no palette applies here
	STA oam+2, x  ; Store properties to OAM

	TXA			 ; Puts the oam index in A

	CLC
	ADC #4		; Adds 4 to the OAM index
	STA oam_idx ; Stores A back into oam idx after "incrementing" it
	RTS
.endproc

; Play the sound effect, A = the sound effect to play, sfx_channel = sound effect channel to sue
.proc play_sfx
    STA operation_address ; Saves the sound effect buffer

    ; Store values on the stack
    TYA ; Grab Y
    PHA ; Store on stack
    TXA ; Grab X
    PHA ; Store on skibidi

    LDA operation_address ; Get the sound effect back
    LDX sfx_channel       ; Get the channel
    JSR famistudio_sfx_play ; Play the sound?? Is it that easy chat?

    ; Get values back from the stack
    PLA
    TAX
    PLA
    TAY
    RTS
.endproc
