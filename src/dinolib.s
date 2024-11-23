.segment "ZEROPAGE" ; Variables

seed: .res 2 ; Defined a seed variable

dino_state: .res 1 ; The current state of the dino
dino_vx: .res 1    ; The x velocity of the dino

game_speed: .res 1 ; The current speed of the game

; Some dino state flags that we can compare against
DINO_CROUCH = $01
DINO_JUMP = $02
DINO_DEAD = $04

.segment "CODE"

; An update function updating the game loop
.proc dino_update

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