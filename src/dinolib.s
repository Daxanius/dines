.segment "ZEROPAGE" ; Variables
; Some dino state flags that we can compare against
DINO_CROUCH = 1
DINO_JUMP = 2
DINO_DEAD = 4
DINO_LEG_VARIANT = 8
DINO_TOUCHED_CEILING = 16
DINO_ON_GROUND = 32
DINO_HOLD_JUMP = 64
DINO_JUMPED = 128

; Dino texture parts
DINO_BACK = 1
DINO_HEAD = 2
DINO_ARMS = 6
DINO_LEGS1 = 5
DINO_LEGS2 = 7
DINO_HEAD_DEAD = 9

; Dino crouched texture parts
DINO_CROUCH_TAIL = 37
DINO_CROUCH_BACK = 38
DINO_CROUCH_HEAD = 39
DINO_CROUCH_TAIL_VARIANT = 40
DINO_CROUCH_BACK_VARIANT = 41 ; For the walking animation

DINO_POS_X = 50
FLOOR_HEIGHT = 176 ; This value will also be used as the lowest possible value for the dino
JUMP_FORCE = 6
CEILING_HEIGHT = 12  ; The maximum height the dino can jump

dino_state: .res 1 ; The current state of the dino
dino_vy: .res 1    ; The y velocity of the dino
dino_py: .res 1	   ; The y position of the dino

dino_steps: .res 1 ; The amount of steps the dino has taken

.segment "CODE"

.proc dino_start
	LDA #FLOOR_HEIGHT ; The starting Y value for the DINO
	STA dino_py       ; Store the y value in py

	RTS
.endproc

; An update function updating the game loop
.proc dino_update
	LDA #0	         ; Zero to reset the OAM index
	STA oam_idx      ; Reset the oam index, I'm pretty sure the PPU has something for this..

	JSR dino_physics ; Handle dino physics

	LDA #20                 ; Load the dividor in A (so modulo returns 0 or 1)
	CLC 
	SBC game_speed			; Subtract game speed from the stepping cooldown
    STA operation_address   ; We will divide A by operation address

	LDA game_ticks  ; Get current game ticks

    JSR divide      ; Divide A by operation address

	TYA 			; Tranfer remainder to A
	CMP #0 	    	; If game ticks devided by 20 has a remainder of 0 
	BNE @skip_step   ; Jump to not change legs

	LDA dino_state 		 ; Get the current dino state
	EOR #DINO_LEG_VARIANT ; Xor with the dino leg variant to toggle
	STA dino_state       ; Update state with new value

	INC dino_steps ; Increment the steps the dino has taken

	LDA dino_steps  ; Load the dino steps
	CMP #$80        ; Check if it's half
	BMI @skip_step   ; Skip incrementing the speed otherwise

	LDA #0
	STA dino_steps

	LDA game_speed  ; Fetch the game speed
	CMP #MAX_SPEED   ; Compare it against the maximum game speed
	BEQ @skip_speed_inc ; Skip incrementing the game speed if we are at the max
	BPL @skip_speed_inc ; Or somehow exceeding the max

	INC game_speed  ; Increment the game speed

@skip_speed_inc:

	LDA #(32 * PALLETE_COUNT) ; The maximum allowed palette index
	STA operation_address ; Store it in operation address for division

	; Change the palette
	LDA palette_idx	; Load palette index
	CLC			    ; Clear carry
	ADC #32			; Add 32 to it
	JSR divide 	    ; Divide to get the modulo

	STY	palette_idx ; Store the new index

	LDX palette_idx ; Get the palette index into X
	LDY #0 ; Store 0 in Y
	@paletteloop:
        LDA palettes, x ; Loop through the next palette palette
        STA palette, y         ; Index with Y
        INX                    ; Increment x
		INY 				   ; Increment Y
        CPY #32                ; Check if we aren't at the end of the palette
        BCC @paletteloop        ; Keeping copying over palette bytes if we aren't done yet

	; Play coin sound
	LDA #2
    LDX #1 ; play on channel 1
    JSR play_sfx

@skip_step:
	LDA dino_state 	   					; Get the current dino state
	AND #(DINO_CROUCH | DINO_ON_GROUND) ; Get the crouch and on floor states
	CMP #(DINO_CROUCH | DINO_ON_GROUND) ; Compare the state
	BEQ @draw_crouched 					; If they're the same, the dino is crouching

	JSR draw_dino
	JMP @continue

@draw_crouched:
	JSR draw_dino_crouched

@continue:
	JSR dino_input   ; Handle user input

	CLC
	INC game_ticks ; Increment the game ticks
	RTS
.endproc

; Handles dino input
.proc dino_input
	LDA gamepad    ; Put the user input into Accumalator
	AND #PAD_D     ; Listen only for the down button
	BEQ @crouch_false ; If down isn't pressed, go to crouch false

	; Set the dino to crouching
	LDA dino_state
	ORA #DINO_CROUCH
	STA dino_state
	JMP @end_check

@crouch_false:
	LDA dino_state
	AND #%11111110
	STA dino_state

@end_check:
    LDA gamepad    ; Put the user input into Accumalator
    AND #PAD_A     ; Listen only for the A button
    BEQ @check_hold ; if A isnt pressed check if A was being held down

	;A is being pressed 
	LDA dino_state			; load state
	ORA #DINO_HOLD_JUMP		; set DINO_HOLD_JUMP bit
	STA dino_state			; store updated state
	BNE @jump				; (always) branch to jump
	;end of A being pressed logic

@stop_hold:
	LDA dino_state			; load state
	ORA #DINO_JUMPED		; set DINO_JUMPED bit
	STA dino_state			; store updated state
	BNE @return				; (always) branch to return

@check_hold:
	LDA dino_state			; load state
	AND #DINO_HOLD_JUMP		; compares with DINO_HOLD_JUMP
	BNE @stop_hold			; if holding: stop holding
							; else:
	LDA dino_state			; load state
	AND #%10111111			; clear DINO_HOLD_JUMP
	STA dino_state			; store updated state

@return:
	RTS

@jump:
    ; Check if the dino has not touched the ceiling yet
    LDA dino_state            ; Get the state
    AND #DINO_TOUCHED_CEILING ; Get only the touched ceiling bit
	BNE @return                ; Continue if we touched the ceiling

    ; Apply jump force
    LDA #JUMP_FORCE
    STA dino_vy

	LDA dino_state			; load state
	AND #DINO_ON_GROUND		; Checks if the dino is on the ground
	BEQ @skip_sound			; If we are not on the ground anymore, skip plaing a sound

	; Play jumping sound
	LDA #0
    LDX #0
    JSR play_sfx

@skip_sound:
	RTS
.endproc

; Handles dino physics
.proc dino_physics
	LDA dino_py	; Get the Y position

    ; Check for the ceiling, it is only used to disallow the user from jumping, not to bump against it
    CMP #CEILING_HEIGHT
    BMI @update_position ; If we did not touch the ceiling, update state

    LDA dino_state            ; Get the state
    ORA #DINO_TOUCHED_CEILING ; Set the touched ceiling flag
    STA dino_state            ; Update the state

@update_position:
	LDA dino_state 	 ; Get the current dino state
	AND #DINO_CROUCH ; Get the crouch state
	BEQ @skip_reset_gravity ; If the dino is not crouching, move on

	LDA #248
	STA dino_vy ; Reset the velocity if the user is crouching in the air

@skip_reset_gravity:
	LDA dino_py	        ; Get the position of the dino
	CLC 		        ; Clear the carry before applying velocity
	SBC dino_vy         ; Apply the y velocity
	CMP #FLOOR_HEIGHT-1 ; Check if the position is not underneath the y position
	BPL @reset_vel 	    ; Go to reset velocity if the position is underneath the base position
	BEQ @reset_vel      ; Also go to reset when it is equal to the floor height

	STA dino_py  ; Store the position
	
	DEC dino_vy ; Decrement the velocity (gravity)

   	LDA dino_state
    AND #%11011111  ; Clear the DINO_ON_GROUND bit
    STA dino_state  ; Store back the updated state

	RTS
@reset_vel:
	LDA #0		; Set A to 0
	STA dino_vy ; Reset the y velocity of the dino

	LDA #FLOOR_HEIGHT 	; Get the floor height
	STA dino_py			; Reset the position to the floor height

	LDA dino_state 		; Fetch the dino state to update
	ORA #DINO_ON_GROUND  ; The dino is on the ground
	AND #%01101111      ; Clear the DINO_TOUCHED_CEILING and DINO_JUMPED bit
    STA dino_state      ; Store back the updated state

	RTS
.endproc

; Puts the crouching dino in the oam
; Refer to https://www.nesdev.org/wiki/PPU_OAM
.proc draw_dino
	LDA #0 			      ; Store 0 for the properties of all dino sprites
	STA operation_address ; Put it in operation address, which draw_sprite will use

	LDA #DINO_POS_X	; Get the dino x position
	STA oam_px		; Store it to OAM desired position

	LDA dino_py 	; Get the dino y position
	CLC				; Clear carry
	SBC #7			; Subtract 7 from the desired y position to draw from the top left
	STA oam_py 		; Store desired y position

	LDA #DINO_BACK	; Select the back of the dino head
	JSR draw_sprite ; Draw the back of the dino head

	LDA oam_px		; Get desired x position
	CLC				; Clear carry
	ADC #8			; Add 8 to it
	STA oam_px 		; Store desired x position

	LDA dino_state  ; Get the dino state
	AND #DINO_DEAD  ; Get the dino dead value
	CMP #DINO_DEAD  ; Check the dino dead value
	BEQ @draw_dead_head ; Draw the dead head if the dino is dead
	
	LDA #DINO_HEAD	; Select the dino head to draw
	JMP @draw_head   ; Draw the head

	@draw_dead_head:
		LDA #DINO_HEAD_DEAD

	@draw_head:
		JSR draw_sprite ; Draw the dino head

	LDA dino_py 	; Get the dino y position
	STA oam_py		; Store it to OAM desired position

	LDA #DINO_ARMS	; Select the dino arms to draw
	JSR draw_sprite ; Draw the dino arms

	LDA oam_px		; Get desired x position
	CLC				; Clear carry
	SBC #7			; Subtract 7 from it
	STA oam_px 		; Store desired x position

	LDA dino_state  ; Get the dino state for the legs
	AND #DINO_LEG_VARIANT ; Check against the leg variant
	CMP #0				 ; Check if the legs were set
	BNE @leg2			 ; Jump to leg 2 if they were were set

	LDA #DINO_LEGS1	; Select the dino legs to draw
	JMP @draw_legs	; Jump to the drawing logic

	@leg2:
		LDA #DINO_LEGS2	; Select the second dino legs

	@draw_legs:
		JSR draw_sprite ; Draw the dino legs
	RTS
.endproc

; Puts the dino in the OAM
; Refer to https://www.nesdev.org/wiki/PPU_OAM
.proc draw_dino_crouched
	LDA #0 			      ; Store 0 for the properties of all dino sprites
	STA operation_address ; Put it in operation address, which draw_sprite will use

	LDA #DINO_POS_X	; Get the dino x position
	STA oam_px		; Store it to OAM desired position

	LDA dino_py 	; Get the dino y position
	STA oam_py 		; Store desired y position

	LDA dino_state  ; Get the dino state for the legs
	AND #DINO_LEG_VARIANT ; Check against the leg variant
	CMP #0				  ; Check if the legs were set
	BNE @back_leg2		  ; Jump to leg 2 if they were were set

	LDA #DINO_CROUCH_TAIL	; Select the dino legs to draw
	JMP @back_leg_draw		; Jump to the drawing logic

	@back_leg2:
		LDA #DINO_CROUCH_TAIL_VARIANT	; Select the second dino back

	@back_leg_draw:
		JSR draw_sprite 


	LDA oam_px		; Get desired x position
	CLC				; Clear carry
	ADC #8			; Add 8 to it
	STA oam_px 		; Store desired x position

	LDA dino_state  ; Get the dino state for the legs
	AND #DINO_LEG_VARIANT ; Check against the leg variant
	CMP #0				  ; Check if the legs were set
	BNE @front_leg2	      ; Jump to leg 2 if they were were set

	LDA #DINO_CROUCH_BACK	; Select the dino legs to draw
	JMP @front_leg_draw	    ; Jump to the drawing logic

	@front_leg2:
		LDA #DINO_CROUCH_BACK_VARIANT	; Select the second dino back

	@front_leg_draw:
		JSR draw_sprite ; Draw the dino leg variant

	LDA oam_px		; Get desired x position
	CLC				; Clear carry
	ADC #8			; Add 8 to it
	STA oam_px 		; Store desired x position

	LDA #DINO_CROUCH_HEAD	; Select the dino head to draw
	JSR draw_sprite 		; Draw the dino head

	LDA #0
	JSR draw_sprite

	RTS
.endproc