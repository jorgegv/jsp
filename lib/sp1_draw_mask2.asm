
; DRAW MASK SPRITE 2 BYTE DEFINITION ROTATED
; 01.2006 aralbrec, Sprite Pack v3.0
; sinclair spectrum version
; 12.2024 adapted by zxjogv (zx@jogv.es) for JSP

	section code_compiler

	public _SP1_DRAW_MASK2
	public _sp1_draw_mask2

	extern _SP1_DRAW_MASK2NR
	extern _jsp_rottbl
	extern _jsp_current_rottbl_msb

;; void sp1_draw_mask2( uint8_t *dst, uint8_t *graph, uint8_t *graph_left ) __smallc __z88dk_callee;
;; Trashes DE' !!!
_sp1_draw_mask2:
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
; de = left graphic def ptr

_SP1_DRAW_MASK2:

	cp _jsp_rottbl/256 - 2
	jp z, _SP1_DRAW_MASK2NR

	push iy	; save
	push ix	; save

	push de
	pop ix

	ex de,hl
	push bc
	pop iy
	ld h,a

	;  h = shift table
	; de = sprite def (mask,graph) pairs
	; ix = left sprite def
	; iy = dst buf

_SP1Mask2Rotate:

	; 0

	ld a,(de)
	inc de
	ld l,a
	ld a,(hl)               ; a = spr mask rotated right
	inc h
	ld l,(ix+0)
	or (hl)                 ; or in mask rotated from left
	ld b,a                  ; b = total mask
	ld l,(ix+1)
	ld c,(hl)               ; c = spr graph rotated from left
	dec h
	ld a,(de)
	inc de
	ld l,a
	ld a,(iy+0) ; get background graphic
	and b                   ; mask it
	or c                    ; or graph rotated from left
	or (hl)                 ; or spr graph rotated right
	ld (iy+0),a ; store to current background

	; 1

	ld a,(de)
	inc de
	ld l,a
	ld a,(hl)
	inc h
	ld l,(ix+2)
	or (hl)
	ld b,a
	ld l,(ix+3)
	ld c,(hl)
	dec h
	ld a,(de)
	inc de
	ld l,a
	ld a,(iy+1)
	and b
	or c
	or (hl)
	ld (iy+1),a

	; 2

	ld a,(de)
	inc de
	ld l,a
	ld a,(hl)
	inc h
	ld l,(ix+4)
	or (hl)
	ld b,a
	ld l,(ix+5)
	ld c,(hl)
	dec h
	ld a,(de)
	inc de
	ld l,a
	ld a,(iy+2)
	and b
	or c
	or (hl)
	ld (iy+2),a

	; 3

	ld a,(de)
	inc de
	ld l,a
	ld a,(hl)
	inc h
	ld l,(ix+6)
	or (hl)
	ld b,a
	ld l,(ix+7)
	ld c,(hl)
	dec h
	ld a,(de)
	inc de
	ld l,a
	ld a,(iy+3)
	and b
	or c
	or (hl)
	ld (iy+3),a

	; 4

	ld a,(de)
	inc de
	ld l,a
	ld a,(hl)
	inc h
	ld l,(ix+8)
	or (hl)
	ld b,a
	ld l,(ix+9)
	ld c,(hl)
	dec h
	ld a,(de)
	inc de
	ld l,a
	ld a,(iy+4)
	and b
	or c
	or (hl)
	ld (iy+4),a

	; 5

	ld a,(de)
	inc de
	ld l,a
	ld a,(hl)
	inc h
	ld l,(ix+10)
	or (hl)
	ld b,a
	ld l,(ix+11)
	ld c,(hl)
	dec h
	ld a,(de)
	inc de
	ld l,a
	ld a,(iy+5)
	and b
	or c
	or (hl)
	ld (iy+5),a

	; 6

	ld a,(de)
	inc de
	ld l,a
	ld a,(hl)
	inc h
	ld l,(ix+12)
	or (hl)
	ld b,a
	ld l,(ix+13)
	ld c,(hl)
	dec h
	ld a,(de)
	inc de
	ld l,a
	ld a,(iy+6)
	and b
	or c
	or (hl)
	ld (iy+6),a

	; 7

	ld a,(de)
	inc de
	ld l,a
	ld a,(hl)
	inc h
	ld l,(ix+14)
	or (hl)
	ld b,a
	ld l,(ix+15)
	ld c,(hl)
	dec h
	ld a,(de)
	ld l,a
	ld a,(iy+7)
	and b
	or c
	or (hl)
	ld (iy+7),a

	pop ix	; restore
	pop iy	; restore
	ret
