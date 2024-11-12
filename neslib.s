;******************************************************************
; neslib.s: NES Function Library
;******************************************************************

; Define PPU Registers
PPU_CONTROL = $2000
PPU_MASK = $2001
PPU_STATUS = $2002
PPU_SPRRAM_ADDRESS = $2003
PPU_SPRRAM_IO = $2004
PPU_VRAM_ADDRESS1 = $2005
PPU_VRAM_ADDRESS2 = $2006
PPU_VRAM_IO = $2007
SPRITE_DMA = $4014

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

ppu_ctl0: .res 1
ppu_ctl1: .res 1

gamepad: .res 1

text_address: .res 2

.include "macros.s"

.segment "CODE"

.proc wait_frame ; Waits for the screen to be ready
    inc nmi_ready
@loop:
    lda nmi_ready
    bne @loop
    rts
.endproc

.proc ppu_update
    lda ppu_ctl0
    ora #VBLANK_NMI
    sta ppu_ctl0
    sta PPU_CONTROL
    lda ppu_ctl1
    ora #OBJ_ON|BG_ON
    sta ppu_ctl1
    jsr wait_frame
    rts
.endproc

.proc ppu_off
    jsr wait_frame
    lda ppu_ctl0
    and #%01111111
    sta ppu_ctl0
    sta PPU_CONTROL
    lda ppu_ctl1
    and #%11100001
    sta ppu_ctl1
    sta PPU_MASK
    rts
.endproc

.proc clear_nametable
        lda PPU_STATUS
        lda #$20
        sta PPU_VRAM_ADDRESS2
        lda #$00
        sta PPU_VRAM_ADDRESS2

        lda #0
        ldy #30
    rowloop:
        ldx #32
        columnloop:
            sta PPU_VRAM_IO
            dex
            bne columnloop
            dey
            bne rowloop
            ldx #64
    loop:
        sta PPU_VRAM_IO
        dex
        bne loop
        rts
.endproc

.proc gamepad_poll
        lda #1
        sta JOYPAD1
        lda #0
        sta JOYPAD1
        ldx #8
    loop:
        pha
        lda JOYPAD1
        and #%00000011
        cmp #%00000001
        pla
        ror
        dex
        bne loop
        sta gamepad
        rts
.endproc

.proc write_text
    ldy #0
    loop:
        lda (text_address),y
        beq exit
        sta PPU_VRAM_IO
        iny
        jmp loop
    exit:
        rts
.endproc