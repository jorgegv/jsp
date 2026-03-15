	section code_compiler

	extern jsp_rowcolindex
	extern _jsp_dtt_mark_dirty
	extern _jsp_ftt_mark_bg
	extern _jsp_ftt_mark_fg
	extern _jsp_draw_screen_tile
	extern _jsp_btt
	extern _jsp_drt
	extern _jsp_default_bg_tile

	public _jsp_draw_background_tile
	public _jsp_delete_background_tile
	public _jsp_draw_foreground_tile

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

	;    jsp_ftt_mark_bg( row, col );   -- clear any foreground flag
	;    jsp_dtt_mark_dirty( row, col );

	pop de		; restore D = row, E = col

	push de		; save for dtt call
	ld b,0
	ld c,d		; BC = row
	push bc		; param: row
	ld c,e
	push bc		; param: col
	call _jsp_ftt_mark_bg

	pop de		; D = row, E = col
	ld b,0
	ld c,d
	push bc		; param: row
	ld c,e
	push bc		; param: col
	call _jsp_dtt_mark_dirty

	ret

;; void jsp_draw_foreground_tile( uint8_t row, uint8_t col, uint8_t *pix ) __smallc __z88dk_callee;
;; Sets BTT and DRT, marks cell as foreground (FTT), and draws directly to
;; screen without touching DTT.  Foreground tiles are never overwritten by
;; the sprite drawing machinery.

_jsp_draw_foreground_tile:
	pop af		;; save ret addr

	pop bc		;; BC = pix ptr
	pop de		;; E = col
	pop hl		;; L = row

	push af		;; restore ret addr

	;; 1. Update BTT and DRT (same as background tile, without marking DTT)
	ld d,l		;; D = row, E = col
	push de		;; save row,col for FTT/screen calls
	push bc		;; save pix ptr for screen call

	call jsp_rowcolindex	;; HL = row*32+col
	add hl,hl		;; byte offset

	push hl			;; save offset

	ld de,_jsp_btt
	add hl,de
	ld (hl),c		;; BTT[idx] = pix_lo
	inc hl
	ld (hl),b		;; BTT[idx+1] = pix_hi

	pop hl			;; restore offset
	ld de,_jsp_drt
	add hl,de
	ld (hl),c		;; DRT[idx] = pix_lo
	inc hl
	ld (hl),b		;; DRT[idx+1] = pix_hi

	;; 2. Mark FTT bit (set foreground)
	pop bc			;; BC = pix ptr
	pop de			;; D = row, E = col

	push de			;; save row,col for screen call
	push bc			;; save pix ptr for screen call

	ld b,0
	ld c,d
	push bc			;; param: row
	ld c,e
	push bc			;; param: col
	call _jsp_ftt_mark_fg	;; callee - pops params

	;; 3. Draw tile directly to screen (bypasses DTT / redraw loop)
	pop bc			;; BC = pix ptr
	pop de			;; D = row, E = col

	ld h,0
	ld l,d
	push hl			;; param: row
	ld l,e
	push hl			;; param: col
	push bc			;; param: pix ptr
	call _jsp_draw_screen_tile	;; callee - pops params

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
