	section code_compiler

	extern jsp_rowcolindex
	extern _jsp_dtt_mark_dirty
	extern _jsp_btt
	extern _jsp_drt
	extern _jsp_default_bg_tile

	public _jsp_draw_background_tile
	public _jsp_delete_background_tile

;; BTT and DRT drawing functions

;; void jsp_draw_background_tile( uint8_t row, uint8_t col, uint8_t *pix ) __smallc __z88dk_callee;

_jsp_draw_background_tile:
	pop af		; save ret addr

	pop bc		; pix data ptr
	pop de		; DE = col
	pop hl		; HL = row

	push af		; restore ret addr

jsp_draw_background_tile_alt:
	;    jsp_btt[ row * 32 + col ] = jsp_drt[ row * 32 + col ] = pix;
	ld d,l		; D = row, E = col
	push de		; save row,col for later
	call jsp_rowcolindex	; HL = BTT index

	add hl,hl	; multiply by 2 to get real byte offset

	push hl		; save offset for later

	ld de,_jsp_btt
	add hl,de	; index into BTT

	ld (hl),c	; store pix data ptr into jsp_btt[ row * 32 + col ]
	inc hl
	ld (hl),b

	pop hl		; restore offset

	ld de,_jsp_drt
	add hl,de	; index into DRT

	ld (hl),c	; store pix data ptr into jsp_drt[ row * 32 + col ]
	inc hl
	ld (hl),b

	;    jsp_dtt_mark_dirty( row, col );

	pop de		; restore D = row, E = col
	ld b,0
	ld c,d		; BC = row
	push bc		; param: row
	ld c,e
	push bc		; param: col
	call _jsp_dtt_mark_dirty

	ret

;; void jsp_delete_background_tile( uint8_t row, uint8_t col ) __smallc __z88dk_callee;
;; deleting a tile is just drawing the default background tile at that
;; position
_jsp_delete_background_tile:
	pop af		; save ret addr

	pop de		; DE = col
	pop hl		; HL = row

	push af		; restore ret addr

	ld bc,(_jsp_default_bg_tile)	; bc = jsp_default_bg_tile

	jp jsp_draw_background_tile_alt
