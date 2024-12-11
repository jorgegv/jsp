	section code_compiler

	extern _zx_cxy2saddr_callee

	public _jsp_draw_screen_tile
;	public _jsp_draw_screen_tile_attr

_jsp_draw_screen_tile:

	pop af		; save ret addr

	pop hl		; src data
	pop bc		; BC = col
	pop de		; DE = row

	push af		; restore ret addr

	push hl		; save src data address

	push bc		; param: col
	push de		; param: row
	call _zx_cxy2saddr_callee	; HL = top screen address of (row,col)

	ex de,hl	; DE = screen addr
	pop hl		; HL = src data

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

_jsp_draw_screen_tile_attr:
