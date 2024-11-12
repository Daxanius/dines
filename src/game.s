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
.incbin "game.chr" ; Import the background and sprite character sets

.segment "VECTORS"
.word nmi
.word reset
.word irq

.segment "ZEROPAGE" ; Variables
paddr: .res 2

.segment "OAM"
oam: .res 256 ; Sprite OAM data

.include "neslib.s"

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
    .byte "C O O L",0

press_play_text:
    .byte "PRESS A TO BECOME COOL",0

cool_text:
    .byte "YOU ARE NOW COOL",0

title_attributes:
    .byte %00000101,%00000101,%00000101,%00000101
    .byte %00000101,%00000101,%00000101,%00000101
    
irq:
    RTI

.proc reset
        SEI
        LDA #0
        STA PPU_CONTROL
        STA PPU_MASK
        STA APU_DM_CONTROL
        LDA #$40
        STA JOYPAD2
        CLD
        LDX #$FF
        TXS
        BIT PPU_STATUS

    wait_vblank:
        BIT PPU_STATUS
        BPL wait_vblank
        LDA #0
        LDX #0

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
        LDA #255
        LDX #0

    clear_oam:
        STA oam,x
        INX
        INX
        INX
        INX
        BNE clear_oam

    wait_vblank2:
        BIT PPU_STATUS
        BPL wait_vblank2
        LDA #%10001000
        STA PPU_CONTROL
        JMP main
.endproc

.proc nmi
    PHA
    TXA
    PHA
    TYA
    PHA
    BIT PPU_STATUS
    LDA #>oam
    STA SPRITE_DMA

    m_vram_set_address $3F00
    LDX #0

    @loop:
        LDA palette, x
        STA PPU_VRAM_IO
        INX
        CPX #32
        BCC @loop

        LDA #0
        STA PPU_VRAM_ADDRESS1
        STA PPU_VRAM_ADDRESS1
        LDA ppu_ctl0
        STA PPU_CONTROL
        LDA ppu_ctl1
        STA PPU_MASK

        LDX #0
        STX nmi_ready
        PLA
        TAY
        PLA
        TAX
        PLA
        RTI
.endproc

.proc main
    LDX #0
    paletteloop:
        LDA default_palette, x
        STA palette, x
        INX
        CPX #32
        BCC paletteloop
        JSR display_title_screen
        LDA #VBLANK_NMI|BG_0000|OBJ_1000
        STA ppu_ctl0
        LDA #BG_ON|OBJ_ON
        STA ppu_ctl1
        JSR ppu_update
    titleloop:
        JSR gamepad_poll
        LDA gamepad
        AND #PAD_A|PAD_B|PAD_START|PAD_SELECT
        BEQ titleloop
        JSR display_cool_screen
    mainloop:
        JMP mainloop
.endproc

.proc display_title_screen
        JSR ppu_off
        JSR clear_nametable

        m_vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 6)
        m_assign_16i text_address, title_text
        JSR write_text

        m_vram_set_address (NAME_TABLE_0_ADDRESS + 20 * 32 + 6)
        m_assign_16i text_address, press_play_text
        JSR write_text

        m_vram_set_address (ATTRIBUTE_TABLE_0_ADDRESS + 8) ; Sets the title text to the second palette table
        m_assign_16i paddr, title_attributes
        LDY #0
    loop:
        LDA (paddr),y
        STA PPU_VRAM_IO
        INY
        CPY #8
        BNE loop
        JSR ppu_update
        RTS
.endproc

.proc display_cool_screen
        JSR ppu_off
        JSR clear_nametable

        m_vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 6)
        m_assign_16i text_address, title_text
        JSR write_text

        m_vram_set_address (NAME_TABLE_0_ADDRESS + 20 * 32 + 6)
        m_assign_16i text_address, cool_text
        JSR write_text

        m_vram_set_address (ATTRIBUTE_TABLE_0_ADDRESS) ; Sets the title text to the first palette table
        m_assign_16i paddr, title_attributes
        LDY #0
    loop:
        LDA (paddr),y
        STA PPU_VRAM_IO
        INY
        CPY #8
        BNE loop
        JSR ppu_update
        RTS
.endproc