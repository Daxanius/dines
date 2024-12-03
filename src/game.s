.segment "HEADER"
INES_MAPPER = 0 ; nrom
INES_MIRROR = 0 ; 0 = horizontal mirroring, 1 = vertical mirroring
INES_SRAM = 0 ; Battery backed sram

.byte 'N', 'E', 'S', $1A ; ID
.byte $02 ; 16K PRG bank count
.byte $01 ; 8K CHR bank count
.byte INES_MIRROR | (INES_SRAM << 1) | ((INES_MAPPER & $f) << 4)
.byte (INES_MAPPER & %11110000)
.byte $0, $0, $0, $0, $0, $0, $0, $0 ; Padding

.segment "TILES"
.incbin "dino.chr" ; Import the background and sprite character sets

.segment "VECTORS" ; The part that has all the interrupt handlers
.word handle_vblank
.word handle_reset
.word irq

.segment "ZEROPAGE" ; Variables
paddr: .res 2

.segment "OAM"
oam: .res 256 ; Sprite OAM data

.include "neslib.s"
.include "dinolib.s"
.include "cactuslib.s" 

.segment "BSS"
palette: .res 32 ; Current palette buffer

.segment "RODATA"
default_palette:
    .byte $0F,$15,$26,$37
    .byte $0F,$19,$29,$39
    .byte $0F,$11,$21,$31
    .byte $0F,$00,$10,$30
    .byte $0F,$28,$21,$11
    .byte $0F,$14,$24,$34
    .byte $0F,$1B,$2B,$3B
    .byte $0F,$12,$22,$32

;*****************************************************************
; Main application entry point for startup/reset
;*****************************************************************
.segment "CODE"
title_text:
    .byte "D I N E S",0

press_play_text:
    .byte "PRESS A TO JUMP",0

cool_text:
    .byte "GAME",0

title_colors:
    .byte %00000101,%00000101,%00000101,%00000101
    .byte %00000101,%00000101,%00000101,%00000101
    
irq:
    RTI

; First code that runs the NES boots or the reset interrupt is called
.proc handle_reset
    SEI             ; Disable interupts
    LDA #0          ; Set a ti 0
    STA PPU_CONTROL ; Store 0 to PPU to reset it
    STA PPU_MASK    ; Reset the PPU MASK
    STA APU_DM_CONTROL ; Reset APU control

    LDA #$40        ; Store 40 to reset the joypad
    STA JOYPAD2     ; Reset the joypad
    CLD             ; Clear double mode

    LDX #$FF        ; Store FF into X, which is the start of the downward growing stack
    TXS             ; Set the stack pointer to its start by moving X into SP

    BIT PPU_STATUS ; Reset the PPU status

    ; Wait for the vblank before we can start resetting everything
    wait_vblank:
        BIT PPU_STATUS  ; Get the PPU w register
        BPL wait_vblank ; Jump to wait for the VBlank

    LDA #0          ; Set the A register to 0
    LDX #0          ; Set the X register to 0

    ; Clear the RAM memory by looping and repetitively incrementing X going through the entire RAM
    clear_ram:
        STA $0000,x 
        STA $0100,x
        STA $0200,x
        STA $0300,x
        STA $0400,x
        STA $0500,x
        STA $0600,x
        STA $0700,x
        INX
        BNE clear_ram

    ; Reset x and A
    LDA #255
    LDX #0

    ; Clears the OAM by looping through the addresses of X
    clear_oam:
        STA oam,x   ; Stores the current value of A into the oam

        ; Skipping bytes
        INX         ; Byte 1 of an object
        INX         ; Byte 2 of an object
        INX         ; Byte 3 of an object
        INX         ; Byte 4 of an object
        BNE clear_oam

    ; Wait for the VBlank again before we can start changing PPU settingss
    wait_vblank2:
        BIT PPU_STATUS
        BPL wait_vblank2

    LDA #%10001000  ; PPU Control settings, can be found https://www.nesdev.org/wiki/PPU_registers#PPUCTRL
    STA PPU_CONTROL ; Store A in PPU control, applying our settings

    JMP main ; Finally, start the main part of our program
.endproc

; Handles the VBlank interrupt, all CPU PPU variables will be written to the PPU here
.proc handle_vblank 
    PHA             ; Push A to the stack
    TXA             ; Move x to a
    PHA             ; Push a to the stack, x is now on the stack
    TYA             ; Move y to a
    PHA             ; Push a to the stack, y, and thus all registers are now stored on the stack

    BIT PPU_STATUS  ; Clear the PPU w register without modifying A

    LDA #>oam       ; Store the CPU OAM data adress into A
    STA SPRITE_DMA  ; Tell the CPU to copy the OAM data to the PPU

    m_vram_set_address $3F00 ; Set the PPU Vram addreesss to the start of the palette index https://www.nesdev.org/wiki/PPU_memory_map

    LDX #0 ; Reset x to use for looping

    ; Start storing the palette into the PPU byte by byte
    @loop:
        LDA palette, x  ; Get part of the palette indexed by X
        STA PPU_VRAM_IO ; Send it to the PPU
        INX             ; Increment X
        CPX #32         ; Check if X has not hit 32 yet
        BCC @loop       ; Continue looping as long as we haven't gone through the palette yet

    LDA #0                  ; Reset A

    STA PPU_SCROLL_ADDRESS   ; Reset the scroll address on th X axis
    STA PPU_SCROLL_ADDRESS   ; Reset the scroll adress on the Y axis

    LDA ppu_ctl              ; Get the PPU control settings
    STA PPU_CONTROL          ; Send the PPU control settings to the PPU

    LDA ppu_mask             ; Get PPU_MASK info
    STA PPU_MASK             ; Send the mask to the PPU

    LDX #0        ; Reset X
    STX nmi_ready ; Reset nmi_ready, resulting in the game to move on after the frame according to wait_frame

    ; Put all previous register values back into their respective registers
    PLA ; Pop Y from the stack into A
    TAY ; Store Y from A back into Y
    PLA ; Get X from the stack into A
    TAX ; Store X from A back into X
    PLA ; Get A from the stack
    RTI ; Return from the interuupt
.endproc

.proc main
    LDX #0 ; Reset X for the loop
     
    ; Store the default palette into the palette area which will be put in the PPU on a vblank interrupt
    paletteloop:
        LDA default_palette, x ; Loop through the default palette
        STA palette, x         ; Store the default palette value into palette
        INX                    ; Increment x
        CPX #32                ; Check if we aren't at the end of the palette
        BCC paletteloop        ; Keeping copying over palette bytes if we aren't done yet

    JSR dino_start             ; Jump to the setup function for the main game
    JSR display_title_screen   ; Display the title screen

    ; These settings were getting in the way.. I don't even know what  they were supposed to do
    ; Thanks for being very clear book... Commenting them out fixed dino drawing
    ; Someone please figure this out for me
    ;LDA #VBLANK_NMI|BG_0000|OBJ_1000 ; Combine some PPU control settings into a composite byte 
    ; STA ppu_ctl                      ; Store the settings into PPU CTL

    ;LDA #BG_ON|OBJ_ON                ; Combine PPU mask settings into a composite byte
    ; STA ppu_mask                     ; Store the PPU mask settings
    ; JSR ppu_update                   ; Update the PPU

    ; The title loop simply keeps looping until any input
    titleloop:
        m_inc_16_i seed  ; Increment the seed while the user is in the titlescreen, gives a lil pseudo random seed
        JSR gamepad_poll ; Fetch the user input
        LDA gamepad      ; Put the user input into A
        AND #PAD_A       ; Listen only for the A button
        BEQ titleloop    ; Keep looping through the title if none of the buttons have been pressed (and resulted in 0)
    
    JSR display_game_screen ; Finally display the game screen after we are done with the title
    JSR dino_start             ; Jump to the setup function for the main game

    ; The main game loop
    mainloop:
        ; Skip looping if the previous frame has not been drawn
        LDA nmi_ready ; Grab the NMI status
        CMP #0        ; Check if it's done rendering the last frame
        BNE mainloop  ; Jump back to the start to wait until the frame has been drawn

        JSR gamepad_poll ; Fetch the user input
        JSR dino_update ; Jumps to the main dines updating loop
        JSR cactus_update ; Jumps to the cactus updating loop
        CLC
        m_adc_16_i distance,game_speed ;increments distance

        ; Ensure our changes are rendered
        LDA #1        ; Store true in A
        STA nmi_ready ; Make sure when we loop again, we wait until the VBlank interrupt is called before moving on

        LDA dino_state  ; Get the dino state
        AND #DINO_DEAD  ; Get the dino dead value
        CMP #DINO_DEAD  ; Check the dino dead value

        BNE mainloop    ; Loop again if the dino is shown to be alive
        CMP #DINO_DEAD

    game_over_loop:
        JMP handle_reset ; Just reset for now

    RTS
.endproc

.proc display_title_screen
    JSR ppu_off            ; Disable the PPU
    JSR clear_nametable    ; Clear the background

    m_vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 6) ; Set the address to the start nametable plus the position where we want to draw our text
    m_assign_16i operation_address, title_text                  ; Write our title to text address
    JSR write_text                                         ; Writes the text in operation_address to the nametable

    m_vram_set_address (NAME_TABLE_0_ADDRESS + 20 * 32 + 6) ; Set the address to the start nametable plus the position where we want to draw our text
    m_assign_16i operation_address, press_play_text              ; Write our ppress play text to text address
    JSR write_text                                          ; Writes the text in operation_address to the nametable

    m_vram_set_address (ATTRIBUTE_TABLE_0_ADDRESS + 8) ; Sets the vram address to the start of the attribute table
    m_assign_16i paddr, title_colors                   ; Moves title_colors into paddr

    LDY #0 ; Reset y to use for writing the colors to the PPU

    ; Writes paddr to the attribute table of the first nametable
    loop:
        LDA (paddr),y
        STA PPU_VRAM_IO
        INY
        CPY #8    ; We can only put 8 colors into the attribute table
        BNE loop

    JSR draw_dino   ; Draw the dinosaur on the start screen

    JSR ppu_update ; Update the PPU
    RTS
.endproc

; Literally just clears the screen for the game
.proc display_game_screen
    JSR ppu_off
    JSR clear_nametable
    JSR ppu_update
    RTS
.endproc