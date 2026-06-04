;; CPC screen drawing (doc/CPC-TARGET-PLAN.md §7).
;; CPC Mode-2 cell = 8 bytes (8 lines × 1 byte). A cell's line-0 screen address
;; is 0xC000 + row*80 + col (= 0xC000 + cell, since cell = row*80+col); the 8
;; pixel lines of the cell step by +0x800 (CPC scanline interleave). No attribute
;; RAM on CPC, so there is no attr write.

	IFDEF JSP_TARGET_CPC

	INCLUDE "jsp_cpc_geom.inc"	; JSP_GEOM_COLBYTES / JSP_GEOM_CELLSHIFT

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
	call jsp_rowcolindex	; HL = cell index (row*COLS + col)
  IFDEF JSP_CELL_MODEL_PIXEL
	REPT JSP_GEOM_CELLSHIFT
	add hl,hl		; cell index << log2(COLBYTES) = screen byte offset
	ENDR
  ENDIF
	ld de,0xC000
	add hl,de		; HL = cell line-0 screen address
	pop de			; DE = src

jsp_draw_screen_tile_saddr:	;; HL = line-0 screen addr, DE = src (JSP_CELL_BYTES, column-major)
	ex de,hl		; HL = src, DE = dst
  IF JSP_GEOM_COLBYTES = 1
	;; Model A / Mode 2: 1-byte-wide cell — the tight 8-line blit.
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
  ELSE
	;; Model B wide cell: src is column-major (col0's 8 bytes, then col1's, ...).
	;; Blit each byte-column as an 8-line run to (dst + col), reusing the tight
	;; inner loop; advance dst by 1 byte per column.
	ld c,JSP_GEOM_COLBYTES	; C = column counter
tile_col:
	push de			; save this column's line-0 dst
	ld b,8
tile_col_line:
	ld a,(hl)		; src byte (column-major: contiguous 8 per column)
	ld (de),a		; -> screen
	inc hl			; src++
	ld a,d
	add a,8			; dst += 0x800 (next pixel line)
	ld d,a
	djnz tile_col_line
	pop de			; restore column line-0 dst
	inc de			; next column -> dst + 1
	dec c
	jr nz,tile_col
	ret
  ENDIF

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
