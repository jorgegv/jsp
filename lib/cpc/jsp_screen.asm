;; CPC screen drawing (doc/CPC-TARGET-PLAN.md §7).
;; CPC Mode-2 cell = 8 bytes (8 lines × 1 byte). A cell's line-0 screen address
;; is 0xC000 + row*80 + col (= 0xC000 + cell, since cell = row*80+col); the 8
;; pixel lines of the cell step by +0x800 (CPC scanline interleave). No attribute
;; RAM on CPC, so there is no attr write.

	IFDEF JSP_TARGET_CPC

	section code_compiler

	extern jsp_rowcolindex

	public _jsp_draw_screen_tile
	public _jsp_draw_screen_tile_attr
	public jsp_draw_screen_tile_regs
	public jsp_draw_screen_tile_saddr

; void jsp_draw_screen_tile( uint8_t row, uint8_t col, uint8_t *pix ) __smallc __z88dk_callee;
_jsp_draw_screen_tile:
	pop af			; save ret addr
	pop de			; src data
	pop bc
	ld l,c			; L = col
	pop bc
	ld h,c			; H = row
	push af			; restore ret addr

jsp_draw_screen_tile_regs:	;; H = row, L = col, DE = src
	push de			; save src
	ld d,h
	ld e,l			; D = row, E = col
	call jsp_rowcolindex	; HL = row*80 + col
	ld de,0xC000
	add hl,de		; HL = cell line-0 screen address
	pop de			; DE = src

jsp_draw_screen_tile_saddr:	;; HL = line-0 screen addr, DE = src (8 bytes)
	ex de,hl		; HL = src, DE = dst
	ld b,8
tile_line:
	ld a,(hl)		; src byte
	ld (de),a		; -> screen
	inc hl			; src++
	ld a,d
	add a,8			; dst += 0x800 (next pixel line of this cell)
	ld d,a
	djnz tile_line
	ret

; void jsp_draw_screen_tile_attr( uint8_t row, uint8_t col, uint8_t *pix, uint8_t attr ) __smallc __z88dk_callee;
; CPC has no attribute RAM (§6): the attr argument is ignored; just blit the tile.
_jsp_draw_screen_tile_attr:
	pop af			; save ret addr
	pop bc			; attr (ignored)
	pop de			; src data
	pop bc
	ld l,c			; L = col
	pop bc
	ld h,c			; H = row
	push af			; restore ret addr
	jp jsp_draw_screen_tile_regs

	ENDIF			; JSP_TARGET_CPC
