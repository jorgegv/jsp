	section code_compiler

;; screen drawing functions

	extern asm_zx_cxy2saddr
	extern asm_zx_cxy2aaddr

	public _jsp_draw_screen_tile
	public _jsp_draw_screen_tile_attr

; void jsp_draw_screen_tile( uint8_t row, uint8_t col, uint8_t *pix ) __smallc __z88dk_callee;
_jsp_draw_screen_tile:

	pop af		; save ret addr

	pop de		; src data
	pop bc
	ld l,c		; L = col
	pop bc
	ld h,c		; H = row

	push af		; restore ret addr

jsp_draw_screen_tile_regs:	;; alternate entry point

	call asm_zx_cxy2saddr	; expects H = row, L = col, returns addr in HL

	ex de,hl	; DE = screen addr, HL = src data

	ldi		; transfer 1 byte
	dec de

	inc d		; next line
	ldi		; ... 7 times more
	dec de

	inc d
	ldi
	dec de

	inc d
	ldi
	dec de

	inc d
	ldi
	dec de

	inc d
	ldi
	dec de

	inc d
	ldi
	dec de

	inc d
	ldi

	ret

; void jsp_draw_screen_tile_attr( uint8_t row, uint8_t col, uint8_t *pix, uint8_t attr ) __smallc __z88dk_callee;
_jsp_draw_screen_tile_attr:

	pop af		; save ret addr

	exx
	pop bc		; C' = attr
	exx
	pop de		; src data
	pop hl		; L = col
	pop bc		; C = row

	push af		; restore ret addr

	ld h,c		; H = row, L = col
	push hl		; save row,col for later
	call asm_zx_cxy2aaddr	; expects H = row, L = col, returns addr in HL
	exx
	ld a,c		; A = attr (from C')
	exx
	ld (hl),a	; store attr

	pop hl		; restore HL = row,col
			; DE = src data

	jp jsp_draw_screen_tile_regs
