
; DRAW LOAD SPRITE 1 BYTE DEFINITION ROTATED
; 01.2006 aralbrec, Sprite Pack v3.0
; sinclair spectrum version
; 12.2024 adapted by zxjogv (zx@jogv.es) for JSP

	section code_compiler

	public _SP1_DRAW_LOAD1
	public _sp1_draw_load1

	extern _SP1_DRAW_LOAD1NR
	extern _jsp_current_rottbl_msb
	extern _jsp_rottbl

; void sp1_draw_load1( uint8_t *dst, uint8_t *graph, uint8_t *graph_left ) __smallc __z88dk_callee;
; Trashes DE'!
_sp1_draw_load1:
	exx
	pop de		; save ret addr
	exx

	ld a,(_jsp_current_rottbl_msb)		; a = hor rot table

	pop de		; de = left graphic def ptr
	pop hl		; hl = graphic def ptr
	pop bc		; bc = graphic disp

	exx
	push de		;; restore ret addr
	exx

;  a = hor rot table
; bc = graphic disp
; hl = graphic def ptr
; ix = left graphic def ptr

_SP1_DRAW_LOAD1:

	cp _jsp_rottbl/256 - 2
	jp z, _SP1_DRAW_LOAD1NR

	push iy	; save
	push ix	; save

	push de
	pop ix

	ex de,hl
	push bc
	pop iy

	ld h,a

	;  h = shift table
	; de = sprite def (graph only)
	; ix = left sprite def
	; iy = dst buf

_SP1Load1Rotate:

	; 0

	ld a,(de)
	inc de
	ld l,a
	ld a,(hl)
	inc h
	ld l,(ix+0)
	or (hl)
	ld (iy+0),a
	ld l,(ix+1)
	ld b,(hl)
	dec h
	ld a,(de)
	inc de
	ld l,a
	ld a,b
	or (hl)
	ld (iy+1),a

	; 1

	ld a,(de)
	inc de
	ld l,a
	ld a,(hl)
	inc h
	ld l,(ix+2)
	or (hl)
	ld (iy+2),a
	ld l,(ix+3)
	ld b,(hl)
	dec h
	ld a,(de)
	inc de
	ld l,a
	ld a,b
	or (hl)
	ld (iy+3),a

	; 2

	ld a,(de)
	inc de
	ld l,a
	ld a,(hl)
	inc h
	ld l,(ix+4)
	or (hl)
	ld (iy+4),a
	ld l,(ix+5)
	ld b,(hl)
	dec h
	ld a,(de)
	inc de
	ld l,a
	ld a,b
	or (hl)
	ld (iy+5),a

	; 3

	ld a,(de)
	inc de
	ld l,a
	ld a,(hl)
	inc h
	ld l,(ix+6)
	or (hl)
	ld (iy+6),a
	ld l,(ix+7)
	ld b,(hl)
	dec h
	ld a,(de)
	ld l,a
	ld a,b
	or (hl)
	ld (iy+7),a

	pop ix	; restore
	pop iy	; restore
	ret
