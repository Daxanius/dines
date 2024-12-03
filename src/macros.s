; Assigns a hardcoded 16 bit value to a destination
.macro m_assign_16i dest, value
    LDA #<value     ; Puts the first part of the value into A
    STA dest + 0    ; Stores A at the start of the destination
    LDA #>value+0   ; Puts the second part of the value into A
    STA dest+1      ; Stores A at the second part of the destination
.endmacro

; Copies a 16 bit value over from one address to another
.macro m_copy_16i dest, address
    LDA address+0   ; First part of the address
    STA dest+0      ; First part of the destination
    LDA address+1   ; Second part of the address
    STA dest+1      ; Second part of the destination
.endmacro

; Increments a 16 bit value
.macro m_inc_16_i address
    INC address+1  ; Increment the first part of the value
    BNE @done      ; Branch if the first part did not overflow
    INC address    ; Increment the second part of the value

@done:  ; A little label to jump early in the macro
.endmacro

;add 8 bit value at address2 to 16 bit number at address
.macro m_adc_16_i address, address2
    LDA address+1   ; load low order byte
    ADC address2    ; add the 2 8 bit values
    STA address+1   ; store low order byte
    BVC @done       ; end if no overflow
    INC address     ; increment high order byte (if overflow)
@done: 
.endmacro

; Check out https://www.nesdev.org/wiki/PPU_programmer_reference#Address_($2006)_>>_write_x2
.macro m_vram_set_address newaddress
    LDA PPU_STATUS        ; Clear w (write latch) of the PPU, which keeps track of which byte is being written
    LDA #>newaddress      ; Get upper byte of the address first
    STA PPU_VRAM_ADDRESS  ; Send to the PPU, the PPU stores it away to PPUADDR resulting in a toggle of the w register (latch)
    LDA #<newaddress      ; Get lower byte of address
    STA PPU_VRAM_ADDRESS  ; Send lower byte to PPU, it stores it away to PPUADDR
.endmacro

.macro m_vram_clear_address
    LDA #0                ; Store 0 in a, we don't need to reset w because it does not matter in which order 0 is written to the PPU
    STA PPU_VRAM_ADDRESS  ; Store in part 1 of PPUADDR
    STA PPU_VRAM_ADDRESS  ; Store in part 2 of PPUADDR
.endmacro