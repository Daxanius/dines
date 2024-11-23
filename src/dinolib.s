.segment "ZEROPAGE" ; Variables

seed: .res 2 ; Defined a seed variable

game_ticks: .res 1 ; Game ticks to listen to, can be used to time some things, note that it overflows

dino_state: .res 1 ; The current state of the dino
dino_vy: .res 1    ; The y velocity of the dino
dino_py: .res 1	   ; The y position of the dino

game_speed: .res 1 ; The current speed of the game

oam_idx: .res 1; The current index of the OAM we're drawing to
oam_px: .res 1 ; Determines the x position the next sprite will be drawn to
oam_py: .res 1 ; Determines the Y position the next sprite will be drawn to

; Some dino state flags that we can compare against
DINO_CROUCH = 1
DINO_JUMP = 2
DINO_DEAD = 4
DINO_LEG_VARIANT = 8

; Dino texture parts
DINO_BACK = 1
DINO_HEAD = 2
DINO_ARMS = 6
DINO_LEGS1 = 5
DINO_LEGS2 = 7
DINO_HEAD_DEAD = 10

DINO_POS_X = 50
DINO_POS_Y = 180 ; This value will also be used as the lowest possible value for the dino

.segment "CODE"

.proc dino_start
	LDA #DINO_POS_Y	 ; The starting Y value for the DINO
	STA dino_py      ; Store the y value in py
	LDA #0	         ; Zero to reset the OAM index
	STA oam_idx      ; Reset the oam index, I'm pretty sure the PPU has something for this..
	STA dino_state   ; Reset the dino state
	RTS
.endproc

; An update function updating the game loop
.proc dino_update
	LDA #0	         ; Zero to reset the OAM index
	STA oam_idx      ; Reset the oam index, I'm pretty sure the PPU has something for this..

	LDA game_ticks  ; Get current game ticks
	CMP #50 	    ; Every 50 ticks or about every second
	BNE skip_change_legs ; Jump to not change legs

	LDA dino_state 		 ; Get the current dino state
	EOR #DINO_LEG_VARIANT ; Xor with the dino leg variant to toggle
	STA dino_state       ; Update state with new value

	LDA #0            ; Reset game_ticks after toggling
	STA game_ticks

skip_change_legs:
	JSR draw_dino

	m_inc_16_i game_ticks ; Increment the game ticks
	RTS
.endproc

; Puts the dino in the OAM
; Refer to https://www.nesdev.org/wiki/PPU_OAM
.proc draw_dino
	LDA #DINO_POS_X	; Get the dino x position
	STA oam_px		; Store it to OAM desired position

	LDA dino_py 	; Get the dino y position
	STA oam_py		; Store it to OAM desired position

	LDA #DINO_BACK	; Select the back of the dino head
	JSR draw_sprite ; Draw the back of the dino head

	LDA oam_px		; Get desired x position
	CLC				; Clear carry
	ADC #8			; Add 8 to it
	STA oam_px 		; Store desired x position

	LDA #DINO_HEAD	; Select the dino head to draw
	JSR draw_sprite ; Draw the dino head

	LDA oam_py		; Get desired y position
	CLC				; Clear carry
	ADC #8			; Add 8 to it
	STA oam_py 		; Store desired y position

	LDA #DINO_ARMS	; Select the dino arms to draw
	JSR draw_sprite ; Draw the dino arms

	LDA oam_px		; Get desired x position
	CLC				; Clear carry
	SBC #7			; Subtract 7 from it
	STA oam_px 		; Store desired x position

	LDA dino_state  ; Get the dino state for the legs
	AND #DINO_LEG_VARIANT ; Check against the leg variant
	CMP #0				 ; Check if the legs were set
	BNE leg_2			 ; Jump to leg 2 if they were were set

	LDA #DINO_LEGS1	; Select the dino legs to draw
	JMP draw		; Jump to the drawing logic

	leg_2:
		LDA #DINO_LEGS2	; Select the second dino legs

	draw:
		JSR draw_sprite ; Draw the dino legs
	RTS
.endproc

; Draws a sprite with index of A to the OAM
.proc draw_sprite
	LDX oam_idx
	STA oam+1, x ; Store the tile index in the oam

	LDA oam_py   ; Load the desired y position
	STA oam, x   ; Store the desired y position in the oam

	LDA oam_px	  ; Load the desired x position
	sta oam+3, x  ; Store the x position in the oam

	LDA #0		  ; Sprite OAM properties, no palette applies here
	STA oam+2, x  ; Store properties to OAM

	TXA			 ; Puts the oam index in A

	CLC
	ADC #4		; Adds 4 to the OAM index
	STA oam_idx ; Stores A back into oam idx after "incrementing" it
	RTS
.endproc

; Returns a random 8-bit number in A (0-255), clobbers Y (unknown).
; I don't fully understand how this works, but it works, and that's what matters
.proc prng
	LDA seed+1
	TAY ; store copy of high byte

	LSR ; shift to consume zeroes on left...
	LSR
	LSR
	STA seed+1 ; now recreate the remaining bits in reverse order... %111
	LSR
	EOR seed+1
	LSR
	EOR seed+1
	EOR seed+0 ; recombine with original low byte
	STA seed+1

	; compute seed+0 ($39 = %111001)
	TYA ; original high byte
	STA seed+0
	ASL
	EOR seed+0
	ASL
	EOR seed+0
	ASL
	ASL
	ASL
	EOR seed+0
	STA seed+0
	RTS
.endproc