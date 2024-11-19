.macro m_assign_16i dest, value
    LDA #<value
    STA dest + 0
    LDA #>value + 0
    STA dest+1
.endmacro

; Check out https://www.nesdev.org/wiki/PPU_programmer_reference#Address_($2006)_>>_write_x2
.macro m_vram_set_address newaddress
    LDA PPU_STATUS        ; Clear w (write latch) of the PPU, which keeps track of which byte is being written
    LDA #>newaddress      ; Get upper byte of the address first
    STA PPU_VRAM_ADDRESS  ; Send to the PPU, the PPU stores it away to PPUADDR resulting in a toggle of the w register (latch)
    LDA #<newaddress      ; Get lower byte of address
    STA PPU_VRAM_ADDRESS ; Send lower byte to PPU, it stores it away to PPUADDR
.endmacro

.macro m_vram_clear_address
    LDA #0                ; Store 0 in a, we don't need to reset w because it does not matter in which order 0 is written to the PPU
    STA PPU_VRAM_ADDRESS  ; Store in part 1 of PPUADDR
    STA PPU_VRAM_ADDRESS  ; Store in part 2 of PPUADDR
.endmacro