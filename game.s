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
    rti

.proc reset
        sei
        lda #0
        sta PPU_CONTROL
        sta PPU_MASK
        sta APU_DM_CONTROL
        lda #$40
        sta JOYPAD2
        cld
        ldx #$FF
        txs
        bit PPU_STATUS

    wait_vblank:
        bit PPU_STATUS
        bpl wait_vblank
        lda #0
        ldx #0

    clear_ram:
        sta $0000,x
        sta $0100,x
        sta $0200,x
        sta $0300,x
        sta $0400,x
        sta $0500,x
        sta $0600,x
        sta $0700,x
        inx
        bne clear_ram
        lda #255
        ldx #0

    clear_oam:
        sta oam,x
        inx
        inx
        inx
        inx
        bne clear_oam

    wait_vblank2:
        bit PPU_STATUS
        bpl wait_vblank2
        lda #%10001000
        sta PPU_CONTROL
        jmp main
.endproc

.proc nmi
    pha
    txa
    pha
    tya
    pha
    bit PPU_STATUS
    lda #>oam
    sta SPRITE_DMA

    vram_set_address $3F00
    ldx #0

    @loop:
        lda palette, x
        sta PPU_VRAM_IO
        inx
        cpx #32
        bcc @loop

        lda #0
        sta PPU_VRAM_ADDRESS1
        sta PPU_VRAM_ADDRESS1
        lda ppu_ctl0
        sta PPU_CONTROL
        lda ppu_ctl1
        sta PPU_MASK

        ldx #0
        stx nmi_ready
        pla
        tay
        pla
        tax
        pla
        rti
.endproc

.proc main
    ldx #0
    paletteloop:
        lda default_palette, x
        sta palette, x
        inx
        cpx #32
        bcc paletteloop
        jsr display_title_screen
        lda #VBLANK_NMI|BG_0000|OBJ_1000
        sta ppu_ctl0
        lda #BG_ON|OBJ_ON
        sta ppu_ctl1
        jsr ppu_update
    titleloop:
        jsr gamepad_poll
        lda gamepad
        and #PAD_A|PAD_B|PAD_START|PAD_SELECT
        beq titleloop
        jsr display_cool_screen
    mainloop:
        jmp mainloop
.endproc

.proc display_title_screen
        jsr ppu_off
        jsr clear_nametable

        vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 6)
        assign_16i text_address, title_text
        jsr write_text

        vram_set_address (NAME_TABLE_0_ADDRESS + 20 * 32 + 6)
        assign_16i text_address, press_play_text
        jsr write_text

        vram_set_address (ATTRIBUTE_TABLE_0_ADDRESS + 8) ; Sets the title text to the second palette table
        assign_16i paddr, title_attributes
        ldy #0
    loop:
        lda (paddr),y
        sta PPU_VRAM_IO
        iny
        cpy #8
        bne loop
        jsr ppu_update
        rts
.endproc

.proc display_cool_screen
        jsr ppu_off
        jsr clear_nametable

        vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 6)
        assign_16i text_address, title_text
        jsr write_text

        vram_set_address (NAME_TABLE_0_ADDRESS + 20 * 32 + 6)
        assign_16i text_address, cool_text
        jsr write_text

        vram_set_address (ATTRIBUTE_TABLE_0_ADDRESS) ; Sets the title text to the first palette table
        assign_16i paddr, title_attributes
        ldy #0
    loop:
        lda (paddr),y
        sta PPU_VRAM_IO
        iny
        cpy #8
        bne loop
        jsr ppu_update
        rts
.endproc