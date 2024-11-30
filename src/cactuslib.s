.segment "ZEROPAGE" ; Variables

MIN_SPAWN_DELAY = 50
MAX_SPAWN_DELAY = 100


CACTUS_STARTPOS_X = 254

; Cactus texture parts
CACTUS_TOP_START = 12
CACTUS_TOP_END   = 14

CACTUS_BOT_START = 10
CACTUS_BOT_END   = 12

CACTUS_SMALL_START  = 14
CACTUS_SMALL_END    = 16

time_to_wait: .res 1

.segment "CODE"

.proc cactus_update
    JSR segment_update                          ; Update all existing cactus segments

    LDA time_to_wait                            ; Load the dividor in A (so modulo returns 0 or 1)
    STA operation_address                       ; We will divide A by operation address

    LDA game_ticks                              ; Get current game ticks
    JSR divide                                  ; Divide A by operation address

    CPY #0 	    	                            ; If game ticks devided by 55 does not have a remainder of 0 
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
        RTS                                     ; Just don't do anything if we don't need to generate a new cactus
.endproc

; Updates all existing cactus segments
.proc segment_update
    loop:
        LDX oam_idx     ; Load x at the start of the (last) OAM index

        ; Check if we didn't hit an empty sprite
        LDA oam+1, x     ; Fetch the sprite tile index
        CMP #0           ; Check if the sprite is "empty" / has tile 0
        BEQ done_looping ; Stop looping if we hit an empty sprite

        JSR check_and_delete_segment ; Check and potentially delete a cactus segment
        LDX oam_idx                  ; Get the current oam index again

        ; Update the cactus position
        LDA oam+3, x   ; Get the x position of the cactus
        CLC
        SBC game_speed ; Subtract the game speed from the X position
        STA oam+3, x   ; Store a back into the OAM with the new position

        ; Increment the loop
        TXA         ; Move x into a
        CLC
        ADC #4      ; Increment A by 4
        STA oam_idx ; Store the offset 
        
        BVC loop    ; Continue looping if we did not overflow
        
    done_looping:
        RTS
.endproc

; Deletes the segment at register x
.proc check_and_delete_segment
    start:
        LDA oam+3, x  ; Get the x position of the cactus
        CMP #0        ; Compare it against 0
        BNE skip       ; Skip to the end if the cactus part has not hit 0 yet

        ; Reset all oam parts
        LDA #0          
        STA oam, x 
        STA oam+1, x
        STA oam+2, x
        STA oam+3, x

    shift_loop:
        ; Move the next sprite data back to the current slot
        LDA oam+4, x        ; Load the next sprite's data
        STA oam, x      ; Store it in the previous slot
        LDA oam+5, x
        STA oam+1, x
        LDA oam+6, x
        STA oam+2, x
        LDA oam+7, x
        STA oam+3, x

        ; Move to the next sprite slot
        INX
        INX
        INX
        INX
        CPX #(255-3)       ; Have we reached the end of the OAM?
        BEQ end_shift      ; If so, exit the loop
        JMP shift_loop     ; Else continue looping

    end_shift:
        ; Mark the last sprite slot as unused (optional cleanup)
        LDA #0
        STA oam, x
        STA oam+1, x
        STA oam+2, x
        STA oam+3, x

        ; Recursively keep checking for deletion
        LDX oam_idx
        JMP start
    skip:
        RTS
.endproc

.proc generate_cactus
    LDA #2                  ; Load the dividor in A (so modulo returns 0 or 1)
    STA operation_address   ; We will divide A by operation address

    JSR prng                ; Generate a random number and store it in A
    JSR divide              ; Divide A by operation address

    CPY #1                  ; If random number = 1 we generate a big cactus (else if = 0 we generate a small cactus)
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