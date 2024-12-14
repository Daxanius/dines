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

.segment "CODE"
; Famistudio config
FAMISTUDIO_CFG_EXTERNAL       = 1
FAMISTUDIO_CFG_DPCM_SUPPORT   = 1
FAMISTUDIO_CFG_SFX_SUPPORT    = 1
FAMISTUDIO_CFG_SFX_STREAMS    = 1
FAMISTUDIO_CFG_EQUALIZER      = 1
FAMISTUDIO_USE_VOLUME_TRACK   = 1
FAMISTUDIO_USE_PITCH_TRACK    = 1
FAMISTUDIO_USE_SLIDE_NOTES    = 1
FAMISTUDIO_USE_VIBRATO        = 1
FAMISTUDIO_USE_ARPEGGIO       = 1
FAMISTUDIO_CFG_SMOOTH_VIBRATO = 1
FAMISTUDIO_USE_RELEASE_NOTES  = 1
FAMISTUDIO_DPCM_OFF           = $e00

; Assembler config for famistudio
.define FAMISTUDIO_CA65_ZP_SEGMENT   ZEROPAGE
.define FAMISTUDIO_CA65_RAM_SEGMENT  BSS
.define FAMISTUDIO_CA65_CODE_SEGMENT CODE

.include "famistudio_ca65.s"
.include "sfx.s"

.segment "ZEROPAGE" ; Variables
paddr: .res 2

game_ticks: .res 1 ; Game ticks to listen to, can be used to time some things, note that it overflows
game_speed: .res 1 ; The current speed of the game

score: .res 3 ;3 bytes for score, each byte storing 2 digits
displayScore: .res 1

palette_idx: .res 1 ; The current palette index

.segment "OAM"
oam: .res 256 ; Sprite OAM data

.include "neslib.s"
.include "dinolib.s"
.include "obstaclelib.s" 

.segment "BSS"
palette: .res 32 ; Current palette buffer

.segment "RODATA"
PALLETE_COUNT = 3

palettes:
; Day palette
    ; Background palettes
    .byte $30,$0F,$0F,$0F
    .byte $30,$0F,$0F,$0F
    .byte $30,$0F,$0F,$0F
    .byte $30,$0F,$0F,$0F

    ; OAM palettes (very basic palettes)
    .byte $30,$0F,$0F,$0F ; Dino color
    .byte $30,$0F,$0F,$0F ; Cactus color
    .byte $30,$0F,$0F,$0F ; Bird color
    .byte $30,$0F,$0F,$0F ; Unused color

; Evening palette
    ; Background palettes
    .byte $00,$30,$30,$30
    .byte $00,$30,$30,$30
    .byte $00,$30,$30,$30
    .byte $00,$30,$30,$30

    ; OAM palettes (very basic palettes)
    .byte $00,$30,$30,$30 ; Dino color
    .byte $00,$30,$30,$30 ; Cactus color
    .byte $00,$30,$30,$30 ; Bird color
    .byte $00,$30,$30,$30 ; Unused color

; Night palette
    ; Background palettes
    .byte $0F,$2C,$2C,$2C
    .byte $0F,$2C,$2C,$2C
    .byte $0F,$2C,$2C,$2C
    .byte $0F,$2C,$2C,$2C

    ; OAM palettes (very basic palettes)
    .byte $0F,$2C,$2C,$2C ; Dino color
    .byte $0F,$2C,$2C,$2C ; Cactus color
    .byte $0F,$2C,$2C,$2C ; Bird color
    .byte $0F,$2C,$2C,$2C ; Unused color

; FLoor tile info
FLOOR_TILES_START = 34
FLOOR_TILES_END = 36

; Cloud tile info
CLOUD_LEFT_START = 24
CLOUD_LEFT_END = 25
CLOUD_RIGHT_START = 26
CLOUD_RIGHT_END = 27

MAX_SPEED = 4 ; The maximum game speed

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

game_over_text:
    .byte "GAME OVER", 0

restart_text:
    .byte "PRESS START TO RESTART", 0
    
irq:
    RTI

; First code that runs the NES boots or the reset interrupt is called
.proc handle_reset
    SEI             ; Disable interupts
    LDA #0          ; Set a to 0
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
    @wait_vblank:
        BIT PPU_STATUS  ; Get the PPU w register
        BPL @wait_vblank ; Jump to wait for the VBlank

    LDA #0          ; Set the A register to 0
    LDX #0          ; Set the X register to 0

    ; Clear the RAM memory by looping and repetitively incrementing X going through the entire RAM
    @clear_ram:
        STA $0000,x 
        STA $0100,x
        STA $0200,x
        STA $0300,x
        STA $0400,x
        STA $0500,x
        STA $0600,x
        STA $0700,x
        INX
        BNE @clear_ram

    LDA #2          ; Set the game speed to 2 
    STA game_speed  ; Reset the game speed

    ; Reset x and A
    LDA #255
    LDX #0

    ; Clears the OAM by looping through the addresses of X
    @clear_oam:
        STA oam,x   ; Stores the current value of A into the oam

        ; Skipping bytes
        INX         ; Byte 1 of an object
        INX         ; Byte 2 of an object
        INX         ; Byte 3 of an object
        INX         ; Byte 4 of an object
        BNE @clear_oam

    ; Wait for the VBlank again before we can start changing PPU settingss
    @wait_vblank2:
        BIT PPU_STATUS
        BPL @wait_vblank2

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

    LDA ppu_ctl              ; Get the PPU control settings
    STA PPU_CONTROL          ; Send the PPU control settings to the PPU

    LDA PPU_STATUS          ; Clear w (write latch) of the PPU, which keeps track of which byte is being written
    LDA ppu_scroll_x        ; Get the ppu scroll set variable
    STA PPU_SCROLL_ADDRESS  ; Store ppu scroll x to ppu scroll address

    LDA #0                   ; Reset ppu scroll y
    STA PPU_SCROLL_ADDRESS   ; Store ppu scroll 0 into y

    LDA ppu_mask             ; Get PPU_MASK info
    STA PPU_MASK             ; Send the mask to the PPU

    JSR famistudio_update    ; Calls the famistudio play routine every frame

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
    ; Initialize the sound engine
    LDA #1
    LDX #0
    LDY #0
    JSR famistudio_init

    LDX #.lobyte(sounds)
    LDY #.hibyte(sounds)
    JSR famistudio_sfx_init

    LDX #0 ; Reset X for the loop
     
    ; Store the day palette into the palette area which will be put in the PPU on a vblank interrupt
    @paletteloop:
        LDA palettes, x ; Loop through the default palette
        STA palette, x         ; Store the default palette value into palette
        INX                    ; Increment x
        CPX #32                ; Check if we aren't at the end of the palette
        BCC @paletteloop        ; Keeping copying over palette bytes if we aren't done yet

    JSR dino_start             ; Jump to the setup function for the main game
    JSR display_title_screen   ; Display the title screen

    ; The title loop simply keeps looping until any input
    @titleloop:
        m_inc_16_i seed  ; Increment the seed while the user is in the titlescreen, gives a lil pseudo random seed
        JSR gamepad_poll ; Fetch the user input
        LDA gamepad      ; Put the user input into A
        AND #PAD_A       ; Listen only for the A button
        BEQ @titleloop    ; Keep looping through the title if none of the buttons have been pressed (and resulted in 0)
    
    JSR display_game_screen ; Finally display the game screen after we are done with the title
    JSR dino_start          ; Jump to the setup function for the main game
    LDA #1
    STA displayScore

    ; The main game loop
    @mainloop:
        ; Skip looping if the previous frame has not been drawn
        LDA nmi_ready ; Grab the NMI status
        CMP #0        ; Check if it's done rendering the last frame
        BNE @mainloop  ; Jump back to the start to wait until the frame has been drawn

        JSR gamepad_poll    ; Fetch the user input
        JSR dino_update     ; Jumps to the main dines updating loop
        JSR obstacle_update ; Jumps to the cactus updating loop

        LDA #1          ; Always add 1 to the score, no matter the speed
        JSR add_score   ; Increment the score

        JSR display_score ; Draw the score

        ; Ensure our changes are rendered
        LDA #1        ; Store true in A
        STA nmi_ready ; Make sure when we loop again, we wait until the VBlank interrupt is called before moving on

        LDA dino_state  ; Get the dino state
        AND #DINO_DEAD  ; Get the dino dead value
        CMP #DINO_DEAD  ; Check the dino dead value

        BNE @mainloop    ; Loop again if the dino is shown to be alive

    LDA #0
    STA ppu_scroll_x    ; Reset the PPU scroll
    STA oam_idx
    JSR draw_dino       ; Draw the dino

    ; Play a game over sound lel
    LDA #1
    LDX #0
    JSR play_sfx ; NO WAY

    JSR display_gameover_screen

    @game_over_loop:
        JSR gamepad_poll        ; Fetch the user input
        LDA gamepad             ; Put the user input into A
        AND #PAD_START          ; Listen only for the A button
        BEQ @game_over_loop      ; Keep looping through the title if none of the buttons have been pressed (and resulted in 0)

        JSR handle_reset    
    RTS
.endproc

.proc display_gameover_screen
    JSR ppu_off            ; Disable the PPU

    m_vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 6) ; Set the address to the start nametable plus the position where we want to draw our text
    m_assign_16i operation_address, game_over_text         ; Write our title to text address
    JSR write_text                                         ; Writes the text in operation_address to the nametable

    m_vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 6) ; Set the address to the start nametable plus the position where we want to draw our text
    m_assign_16i operation_address, restart_text            ; Write our title to text address
    JSR write_text                                          ; Writes the text in operation_address to the nametable

    JSR ppu_update ; Update the PPU
    RTS
.endproc

.proc display_title_screen
    JSR ppu_off            ; Disable the PPU
    JSR clear_nametable0   ; Clear the background
    JSR clear_nametable1   ; Also clear nametable 1

    m_vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 6) ; Set the address to the start nametable plus the position where we want to draw our text
    m_assign_16i operation_address, title_text             ; Write our title to text address
    JSR write_text                                         ; Writes the text in operation_address to the nametable

    m_vram_set_address (NAME_TABLE_0_ADDRESS + 17 * 32 + 6) ; Set the address to the start nametable plus the position where we want to draw our text
    m_assign_16i operation_address, press_play_text         ; Write our ppress play text to text address
    JSR write_text                                          ; Writes the text in operation_address to the nametable

    JSR draw_dino   ; Draw the dinosaur on the start screen

    JSR ppu_update ; Update the PPU
    RTS
.endproc

; Creates a procedural background screen for the game in both nametables
.proc display_game_screen
    JSR ppu_off
    JSR clear_nametable0

    ; Spread some clouds around lol
    m_vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 5) 
    JSR create_cloud

    m_vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 20)
    JSR create_cloud

    m_vram_set_address (NAME_TABLE_0_ADDRESS + 14 * 32 + 13)
    JSR create_cloud

    m_vram_set_address (NAME_TABLE_0_ADDRESS + 16 * 32 + 2)
    JSR create_cloud

    m_vram_set_address (NAME_TABLE_0_ADDRESS + 23 * 32)

    LDY #0
    @loop_ground:
        TYA
        PHA

        LDA #(FLOOR_TILES_END - FLOOR_TILES_START)
        STA operation_address
        JSR prng 
        JSR divide
        TYA 
        CLC
        ADC #FLOOR_TILES_START

        STA PPU_VRAM_IO

        PLA
        TAY

        INY 
        CPY #32
        BNE @loop_ground

    JSR ppu_update ; Update the PPU
    RTS
.endproc

; Creates a cloud at a random position
.proc create_cloud
    ; Left cloud part generation
    LDA #(CLOUD_LEFT_END - CLOUD_LEFT_START + 1) ; Max random cloud parts
    STA operation_address                    ; Store in operation address
    JSR prng                                 ; Generate random number
    JSR divide                               ; Fetch modulo for cloud part

    TYA                                      ; Move modulo into A
    ADC #CLOUD_LEFT_START                    ; Get cloud start tile

    STA PPU_VRAM_IO ; Store left cloud part on nametable

    ; Right cloud part generation
    LDA #(CLOUD_RIGHT_END - CLOUD_RIGHT_START + 1) ; Max random cloud parts
    STA operation_address                      ; Store in operation address
    JSR prng                                   ; Generate random number
    JSR divide                                 ; Fetch modulo for cloud part

    TYA                                      ; Move modulo into A
    ADC #CLOUD_RIGHT_START                   ; Get cloud start tile

    STA PPU_VRAM_IO ; Store right cloud part on nametable
    RTS
.endproc