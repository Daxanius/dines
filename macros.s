.macro assign_16i dest, value
    lda #<value
    sta dest + 0
    lda #>value + 0
    sta dest+1
.endmacro

; Check out https://www.nesdev.org/wiki/PPU_programmer_reference#Address_($2006)_>>_write_x2
.macro vram_set_address newaddress
    lda PPU_STATUS        ; Clear w (write latch) of the PPU, which keeps track of which byte is being written
    lda #>newaddress      ; Get upper byte of the address first
    sta PPU_VRAM_ADDRESS2 ; Send to the PPU, the PPU stores it away to PPUADDR resulting in a toggle of the w register (latch)
    lda #<newaddress      ; Get lower byte of address
    sta PPU_VRAM_ADDRESS2 ; Send lower byte to PPU, it stores it away to PPUADDR
.endmacro

.macro vram_clear_address
    lda #0                ; Store 0 in a, we don't need to reset w because it does not matter in which order 0 is written to the PPU
    sta PPU_VRAM_ADDRESS2 ; Store in part 1 of PPUADDR
    sta PPU_VRAM_ADDRESS2 ; Store in part 2 of PPUADDR
.endmacro