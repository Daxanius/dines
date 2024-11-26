.segment "ZEROPAGE" ; Variables

CACTUS_STARTPOS_X = 220

cactus_type: .res 1

is_big: .res 1

; Cactus texture parts
CACTUS_TOP_START = 12
CACTUS_TOP_END   = 14

CACTUS_BOT_START = 10
CACTUS_BOT_END   = 12

CACTUS_SMALL_START  = 14
CACTUS_SMALL_END    = 16

.segment "CODE"

.proc generate_cactus
    LDA #2
    STA operation_address

    JSR prng
    JSR divide

    STY is_big

    LDA #1
    CMP is_big
    BEQ big_cactus
    JSR make_small_cactus
    RTS

    big_cactus:
    JSR make_big_cactus
    RTS
    
.endproc

.proc make_big_cactus

    LDA #CACTUS_STARTPOS_X
    STA oam_px

    LDA #FLOOR_HEIGHT
    STA oam_py

    LDA #(CACTUS_BOT_END - CACTUS_BOT_START)
    STA operation_address

    JSR prng
    JSR divide

    TYA
    CLC
    ADC #CACTUS_BOT_START

    JSR draw_sprite

    LDA #(FLOOR_HEIGHT - 8)
    STA oam_py

    LDA #(CACTUS_TOP_END - CACTUS_TOP_START)
    STA operation_address

    JSR prng
    JSR divide

    TYA
    CLC
    ADC #CACTUS_TOP_START

    JSR draw_sprite

    RTS
.endproc

.proc make_small_cactus
    LDA #CACTUS_STARTPOS_X
    STA oam_px

    LDA #FLOOR_HEIGHT
    STA oam_py

    LDA #(CACTUS_SMALL_END - CACTUS_SMALL_START)
    STA operation_address

    JSR prng
    JSR divide

    TYA
    CLC
    ADC #CACTUS_SMALL_START

    JSR draw_sprite

    RTS
.endproc