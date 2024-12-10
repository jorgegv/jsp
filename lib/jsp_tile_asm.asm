	section code_compiler

	extern _zx_cxy2saddr_callee

	public _jsp_draw_screen_tile

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

	dec e
	inc d		; next line
	ldi		; ... 7 times more

	dec e
	inc d
	ldi

	dec e
	inc d
	ldi

	dec e
	inc d
	ldi

	dec e
	inc d
	ldi

	dec e
	inc d
	ldi

	dec e
	inc d
	ldi

	ret
