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
    INC nmi_ready
@loop:
    LDA nmi_ready
    BNE @loop
    RTS
.endproc

.proc ppu_update
    LDA ppu_ctl0
    ORA #VBLANK_NMI
    STA ppu_ctl0
    STA PPU_CONTROL
    LDA ppu_ctl1
    ORA #OBJ_ON|BG_ON
    STA ppu_ctl1
    JSR wait_frame
    RTS
.endproc

.proc ppu_off
    JSR wait_frame
    LDA ppu_ctl0
    AND #%01111111
    STA ppu_ctl0
    STA PPU_CONTROL
    LDA ppu_ctl1
    AND #%11100001
    STA ppu_ctl1
    STA PPU_MASK
    RTS
.endproc

.proc clear_nametable
        LDA PPU_STATUS
        LDA #$20
        STA PPU_VRAM_ADDRESS2
        LDA #$00
        STA PPU_VRAM_ADDRESS2

        LDA #0
        LDY #30
    rowloop:
        LDX #32
        columnloop:
            STA PPU_VRAM_IO
            DEX
            BNE columnloop
            DEY
            BNE rowloop
            LDX #64
    loop:
        STA PPU_VRAM_IO
        DEX
        BNE loop
        RTS
.endproc

.proc gamepad_poll
        LDA #1
        STA JOYPAD1
        LDA #0
        STA JOYPAD1
        LDX #8
    loop:
        PHA
        LDA JOYPAD1
        AND #%00000011
        CMP #%00000001
        PLA
        ROR
        DEX
        BNE loop
        STA gamepad
        RTS
.endproc

.proc write_text
    LDY #0
    loop:
        LDA (text_address),y
        BEQ exit
        STA PPU_VRAM_IO
        INY
        JMP loop
    exit:
        RTS
.endproc