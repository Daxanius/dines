.segment "ZEROPAGE" ; Variables

MIN_SPAWN_DELAY = 50
MAX_SPAWN_DELAY = 100

time_to_wait: .res 1

CACTUS_STARTPOS_X = 220

; Cactus texture parts
CACTUS_TOP_START = 12
CACTUS_TOP_END   = 14

CACTUS_BOT_START = 10
CACTUS_BOT_END   = 12

CACTUS_SMALL_START  = 14
CACTUS_SMALL_END    = 16

.segment "CODE"

.proc cactus_update
	LDA time_to_wait                            ; Load the dividor in A (so modulo returns 0 or 1)
    STA operation_address                       ; We will divide A by operation address

	LDA game_ticks                              ; Get current game ticks

    JSR divide                                  ; Divide A by operation address

	TYA 			                            ; Tranfer remainder to A
	CMP #0 	    	                            ; If game ticks devided by 55 does not have a remainder of 0 
    BNE skip_generate_cactus                    ; Skip the generation of a cactus
    JSR generate_cactus                         ; Else it has been 55 game ticks, generate cactus

    LDA #(MAX_SPAWN_DELAY - MIN_SPAWN_DELAY)    ; Give the range of possible cactus bottom parts
    STA operation_address                       ; We will divide this range by operation_address

    JSR prng                                    ; Generate a random number
    JSR divide                                  ; Divide A by operation_address

    TYA                                         ; Move the remainder to A to add with carry 
    CLC                                         ; Make sure carry is clear
    ADC #MIN_SPAWN_DELAY                        ; Add minimum time to random number to make sure the delay is always atleast the minimum delay
    STA time_to_wait                            ; Put this time in variable time_to_wait for next cactus generation
    RTS

    skip_generate_cactus:
    RTS                                         ; Just don't do anything if we don't need to generate a new cactus
.endproc

.proc generate_cactus
    LDA #2                  ; Load the dividor in A (so modulo returns 0 or 1)
    STA operation_address   ; We will divide A by operation address

    JSR prng                ; Generate a random number and store it in A
    JSR divide              ; Divide A by operation address

    TYA                     ; Move remainder into A

    CMP #1                  ; If random number = 1 we generate a big cactus (else if = 0 we generate a small cactus)
    BEQ big_cactus          ; Branch to label "big_cactus" if A = 1
    JSR make_small_cactus   ; If it didn't branch A = 0 which means we should generate a small cactus
    RTS

    big_cactus:
    JSR make_big_cactus     ; A = 1 which means we should generate a big cactus which this subroutine does
    RTS
    
.endproc

.proc make_big_cactus

    LDA #CACTUS_STARTPOS_X                      ; Load the starting x-pos into A 
    STA oam_px                                  ; Tell "draw_sprite" at what x-pos it should start drawing the sprite

    LDA #FLOOR_HEIGHT                           ; Load the starting y-pos into A
    STA oam_py                                  ; Tell "draw_sprite" what height to start drawing the sprite

    LDA #(CACTUS_BOT_END - CACTUS_BOT_START)    ; Give the range of possible cactus bottom parts
    STA operation_address                       ; We will divide this range by operation_address

    JSR prng                                    ; Generate a random number
    JSR divide                                  ; Divide A by operation_address

    TYA                                         ; Move the remainder to A to add with carry 
    CLC                                         ; Make sure carry is clear
    ADC #CACTUS_BOT_START                       ; Add the start of the range of bottom halves to random number to get a random index of cactus bottom

    JSR draw_sprite                             ; Draw the bottom half of the big cactus

    LDA #(FLOOR_HEIGHT - 8)                     ; Draw top half of the big cactus 8 pixels above the bottom half
    STA oam_py                                  ; Tell "draw_sprite" what height to start drawing the sprite (x-pos stays the same)

    LDA #(CACTUS_TOP_END - CACTUS_TOP_START)    ; Give the range of possible cactus top parts
    STA operation_address                       ; We will divide this range by operation_address

    JSR prng                                    ; Generate a random number
    JSR divide                                  ; Divide A by operation_address

    TYA                                         ; Move the remainder to A to add with carry
    CLC                                         ; Make sure carry is clear
    ADC #CACTUS_TOP_START                       ; Add the start of the range of top halves to random number to get random index of cactus top halves

    JSR draw_sprite                             ; Draw top half of the big cactus

    RTS
.endproc

.proc make_small_cactus
    LDA #CACTUS_STARTPOS_X                          ; Load the starting x-pos into A 
    STA oam_px                                      ; Tell "draw_sprite" what x-pos to start drawing the sprite

    LDA #FLOOR_HEIGHT                               ; Load the starting y-pos into A
    STA oam_py                                      ; Tell "draw_sprite" what height to start drawing the sprite

    LDA #(CACTUS_SMALL_END - CACTUS_SMALL_START)    ; Give the range of possible small cacti
    STA operation_address                           ; We will divide this range by operation_address

    JSR prng                                        ; Generate a random number
    JSR divide                                      ; Divide A by operation_address

    TYA                                             ; Tranfer the remainder to add with carry
    CLC                                             ; Make sure carry is clear
    ADC #CACTUS_SMALL_START                         ; Add the start of the range of small cacti to random number to get random index of small cacti

    JSR draw_sprite                                 ; Draw small cactus

    RTS
.endproc