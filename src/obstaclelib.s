.segment "ZEROPAGE" ; Variables

SPOT_DISTANCE           = 8     ; distance between every possible cactus spot (multiple of 2 for easier use)
MIN_SPOTS_BETWEEN_OBSTACLES = 5     ; minimum spots between cacti spawns (multiply by spot distance for minimum distance between cacti)
MAX_SPOTS_BETWEEN_OBSTACLES = 10    ; ^^but maximum
BIRD_RARITY = 5                     ; chance of spawning a flying dino instead of cactus => 1/BIRD_RARITY

; Obstacle start positions
OBSTACLE_STARTPOS_X    = 254

WING_DINO_STARTPOS_Y1     = FLOOR_HEIGHT - 2
WING_DINO_STARTPOS_Y2     = FLOOR_HEIGHT - 12
WING_DINO_STARTPOS_Y3     = FLOOR_HEIGHT - 28

; Bird texture parts
; Sprite 1, wing up
BIRD_TILE_START = 16

BIRD_WING_UP_TOP_FRONT    = 16
BIRD_WING_UP_TOP_BACK     = 17
BIRD_WING_UP_BOTTOM_FRONT = 18
BIRD_WING_UP_BOTTOM_BACK  = 19

; Sprite 2, wing down
BIRD_WING_DOWN_TOP_FRONT    = 20
BIRD_WING_DOWN_TOP_BACK     = 21
BIRD_WING_DOWN_BOTTOM_FRONT = 22
BIRD_WING_DOWN_BOTTOM_BACK  = 23

; Cactus texture parts
CACTUS_TOP_START = 12
CACTUS_TOP_END   = 14

CACTUS_BOT_START = 10
CACTUS_BOT_END   = 12

CACTUS_SMALL_START  = 14
CACTUS_SMALL_END    = 16

BIRD_FLAP_TICKS = 10


distance: .res 2 ;will be used for highscore and cactus spawning
bird_state: .res 1 ; current bird state
spotsUntilObstacle: .res 1 
last_oam_idx: .res 1 ; Used to optimize the cactus delete function

.segment "CODE"

.proc obstacle_start 
    LDA #0  ; Put 0 in a
    STA last_oam_idx ; Reset the last oam index with 0
    RTS
.endproc

.proc obstacle_update
    JSR segment_update                          ; Update all existing cactus segments

    LDA #SPOT_DISTANCE                          ;
    STA operation_address                       ; We will divide A by operation address

    LDA distance+1                              ; Load the low byte of distance
    JSR divide                                  ; Divide A by operation address

    CPY #0                                      ; If distance(low byte) divided by SPOT_DISTANCE does not have a remainder of 0 
    BNE skip_generate_cactus                    ; Skip the generation of a cactus

    DEC spotsUntilObstacle                       ; Decrement spotsUntilCactus
    BPL skip_generate_cactus                    ; if result is positive,skip generation
    ; else (0 or < 0) generate cactus

    ;generate position of next cactus
    LDA #(MAX_SPOTS_BETWEEN_OBSTACLES - MIN_SPOTS_BETWEEN_OBSTACLES) ; Load the difference between max and min
    STA operation_address                                    ; Store in operation address for division
    JSR prng                                                 ; generate random number in A
    TAX                                                      ; store random number for deciding between dino and cactus
    JSR divide                                               ; store random % (Max - Min) i n Y
    TYA                                                      ; transfer randomized offset to A
    CLC                                                      ; clear carry
    ADC #MIN_SPOTS_BETWEEN_OBSTACLES                         ; add min so range goes from [0-offset] to [min-max]
    STA spotsUntilObstacle                                   ; store for later use


    LDA #BIRD_RARITY                                         ; load bird rarity
    STA operation_address                                    ; store to be used as divisor 
    TXA                                                      ; retreive random number generated earlier
    JSR divide                                               ; divide, remainder in Y
    CPY #0                                                   ; if remainder == 0
    BEQ do_generate_bird                                     ; generate flying dino

    JSR generate_cactus                                      ; else generate cactus
    RTS                                                      ; return so it doesnt also generate flying dino

    do_generate_bird:
    JSR generate_bird                                        ; go to generate flying dino function
    RTS                                                      ; return 


    skip_generate_cactus:
        RTS                                                  ; Just don't do anything if we don't need to generate a new cactus
.endproc

; Updates all existing cactus segments
.proc segment_update
    LDA #BIRD_FLAP_TICKS    ; Fetch the amount of ticks per bird flap
    STA operation_address   ; Store it to perform a calculation with
    LDA game_ticks          ; Fetch the game ticks

    JSR divide              ; Divide them to get the remainder for toggling

    TYA                     ; Store Y (remainder) in A
    PHA                     ; Store the remainder on the stack because A will be used

    loop:
        LDX oam_idx     ; Load x at the start of the (last) OAM index

        ; Check if we didn't hit an empty sprite
        LDA oam+1, x     ; Fetch the sprite tile index
        CMP #0           ; Check if the sprite is "empty" / has tile 0
        BEQ done_looping ; Stop looping if we hit an empty sprite

        JSR check_and_delete_segment ; Check and potentially delete a segment

        LDA oam+1, x     ; Fetch the sprite tile index
        CMP #0           ; Check if the sprite is "empty" / has tile 0
        BEQ done_looping ; Stop looping if we hit an empty sprite

        PLA              ; Get the flap remainder from the stack
        CMP #0           ; Check if the remainder is 0
        BNE skip_bird    ; If it is not 0, we skip updating the bird

        TAY             ; Move the remainder into Y because A will be used
        JSR update_bird_animation ; Update the bird animation (clobbering A)
        TYA             ; Move Y back into A

    skip_bird:    
            PHA        ; Store the remainder on the stack again for later use

            LDA oam+3, x            ; Get the X position of the tile
            CMP #(DINO_POS_X + 18)  ; Compare against the dino x position
            BPL continue            ; If the X position is too large to check for collision we skip the expensive collision

            JSR check_dino_collision     ; Check if the dino collided with this part

            CMP #0                       ; If A is 0, aka no collision was detected
            BEQ continue                 ; Move on with no collisions

            LDA dino_state               ; Fetch the dino state
            ORA #DINO_DEAD               ; Set dead to true
            STA dino_state               ; Update the dino state   
        
            JMP done_looping             ; Otherwise return from this subroutine

    continue:
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
        PLA             ; Clean the remainder from the stack, it is no longer needed

        LDA oam_idx
        STA last_oam_idx
        RTS
.endproc

; Checks segment collision with segment in X with any dino parts and updates accordingly, stores 0 in A if nothing happened
.proc check_dino_collision
    LDY oam ; Start of the oam
    loop:
        CPY #12  ; Check if we still have dino parts to loop through
        BPL end  ; No collision detected

        JSR check_collision ; Check for collision

        ; Increment y 4 times to go to the next OAM part
        INY
        INY
        INY
        INY

        CMP #0   ; If no collision happened
        BEQ loop ; Check against the next part

        LDA #1   ; Collision happened
        RTS

    end:
        LDA #0
        RTS
.endproc

; Deletes the segment at register x
.proc check_and_delete_segment
    start:
        LDA oam+3, x  ; Get the x position of the cactus
        CMP #0        ; Compare it against 0
        BNE skip      ; Skip to the end if the cactus part has not hit 0 yet

        ; Reset all oam parts
        LDA #0
        STA oam, x 
        STA oam+1, x
        STA oam+2, x
        STA oam+3, x

        CPX last_oam_idx  ; Check if we are at the last element
        BEQ skip          ; Skip if we are at the last element
        BPL skip          ; Skip if we are above the last element

    shift_loop:
        ; Move the next sprite data back to the current slot
        LDA oam+4, x    ; Load the next sprite's data
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
        CPX last_oam_idx   ; Have we reached the last element?
        BMI shift_loop     ; If not, continue looping

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

.proc generate_bird
    LDA #3
    STA operation_address
    JSR prng 
    JSR divide
    CPY #0
    BEQ height2
    CPY #1
    BEQ height3

height1:
    LDY #(WING_DINO_STARTPOS_Y1 - 8)
    JMP draw_flying_dino
height2:
    LDY #(WING_DINO_STARTPOS_Y2 - 8)
    JMP draw_flying_dino
height3:
    LDY #(WING_DINO_STARTPOS_Y3 - 8)


draw_flying_dino:
    ; Draw top back of wing bird while wing is down
    LDA #OBSTACLE_STARTPOS_X
    STA oam_px

    TYA
    STA oam_py

    LDA #BIRD_WING_DOWN_TOP_BACK

    JSR draw_sprite

    ; Draw top front of wing bird while wing is down
    LDA #(OBSTACLE_STARTPOS_X - 8)
    STA oam_px

    TYA
    STA oam_py
    
    LDA #BIRD_WING_DOWN_TOP_FRONT

    JSR draw_sprite

    ; Draw bottom front of wing bird while wing is down
    LDA #(OBSTACLE_STARTPOS_X - 8)
    STA oam_px

    TYA
    ADC #8
    TAY
    STA oam_py

    LDA #BIRD_WING_DOWN_BOTTOM_FRONT

    JSR draw_sprite

    ; Draw bottom back of wing bird while wing is down
    LDA #OBSTACLE_STARTPOS_X
    STA oam_px

    TYA
    STA oam_py

    LDA #BIRD_WING_DOWN_BOTTOM_BACK

    JSR draw_sprite

    RTS
.endproc

; Updates the bird part at register x 
.proc update_bird_animation
    LDA oam+1, x         ; Get the tile index of the bird part
    CLC                  ; Clear the carry flag for safe arithmetic
    SBC #(BIRD_TILE_START-1) ; Normalize to the bird tile range

    CMP #4               ; Check if it's within the "up" state range (0-3)
    BCC set_bird_down    ; If less than 4, switch to "down" state

    CMP #8               ; Check if it's within the "down" state
    BCC set_bird_up      ; If less than 8, switch to the up state

    RTS                  ; If it isn't a bird tile, just ignore it

    set_bird_up:
        CLC
        ADC #(BIRD_TILE_START-4) ; Add the start offset back
        JMP return

    set_bird_down:
        CLC
        ADC #(BIRD_TILE_START+4) ; Add the start offset back

    return:
        STA oam+1, x         ; Update the bird part with the new tile
        RTS                  ; Return from subroutine
.endproc

; Generates a random cactus and puts it in the OAM
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

; Generates a big cactus and puts it in the OAM
.proc make_big_cactus
    LDA #OBSTACLE_STARTPOS_X                    ; Load the starting x-pos into A 
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

; Generates a small cactus and puts it in the OAM
.proc make_small_cactus
    LDA #OBSTACLE_STARTPOS_X                        ; Load the starting x-pos into A 
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