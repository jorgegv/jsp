
; DRAW MASK SPRITE 2 BYTE DEFINITION ROTATED, ON LEFT BORDER
; 01.2006 aralbrec, Sprite Pack v3.0
; sinclair spectrum version
; 12.2024 adapted by zxjogv (zx@jogv.es) for JSP

	IFDEF JSP_TARGET_CPC		; CPC shift kernel (shared by all CPC shifting modes) - port of lib/zx/jsp_draw_mask2lb.asm. Table-driven via jsp_rottbl, so the pixel encoding lives in the table, not here: identical for M2 (1bpp linear) and M1 (nibble-plane). plan section 5
	section code_compiler

	public _JSP_DRAW_MASK2LB
	public _JSP_DRAW_MASK2LB_ALT
	public _jsp_draw_mask2lb

	extern _JSP_DRAW_MASK2NR
	extern _jsp_rottbl
	extern _jsp_current_rottbl_msb
	extern cc_scratch		; dst is always the JSP compositing buffer,
					; so dst bytes are addressed absolutely:
					; the two-byte reads fold into ld bc,(nn)

;; void jsp_draw_mask2lb( uint8_t *dst, uint8_t *graph ) __smallc __z88dk_callee;
;; trashes BC' !!
_jsp_draw_mask2lb:
	pop de		; save ret addr

	ld a,(_jsp_current_rottbl_msb)		; a = hor rot table

	pop hl		; hl = graphic def ptr
	pop bc		; bc = graphic disp

	push de		;; restore ret addr

;  a = hor rot table
; bc = graphic disp
; hl = graphic def ptr
; de = left graphic def ptr

_JSP_DRAW_MASK2LB:

	cp _jsp_rottbl/256 - 2
	jp z, _JSP_DRAW_MASK2NR

	ld d,a

_JSP_DRAW_MASK2LB_ALT:

	;  d = shift table
	; hl = sprite def (mask,graph) pairs
	; dst = cc_scratch (fixed buffer, addressed absolutely below)

	ld e,$ff
	ld a,(de)
	cpl
	exx
	ld b,a
	exx

_JSPMask2LBRotate:

	; 0

	ld bc,(cc_scratch+0)		; C = dst[0], B = dst[1]
	ld e,(hl)
	inc hl
	ld a,(de)
	exx
	or b
	exx
	and c
	ld c,a
	ld e,(hl)
	inc hl
	ld a,(de)
	or c
	ld (cc_scratch+0),a
	ld e,(hl)
	inc hl
	ld a,(de)
	exx
	or b
	exx
	and b
	ld b,a
	ld e,(hl)
	inc hl
	ld a,(de)
	or b
	ld (cc_scratch+1),a

	; 1

	ld bc,(cc_scratch+2)		; C = dst[2], B = dst[3]
	ld e,(hl)
	inc hl
	ld a,(de)
	exx
	or b
	exx
	and c
	ld c,a
	ld e,(hl)
	inc hl
	ld a,(de)
	or c
	ld (cc_scratch+2),a
	ld e,(hl)
	inc hl
	ld a,(de)
	exx
	or b
	exx
	and b
	ld b,a
	ld e,(hl)
	inc hl
	ld a,(de)
	or b
	ld (cc_scratch+3),a

	; 2

	ld bc,(cc_scratch+4)		; C = dst[4], B = dst[5]
	ld e,(hl)
	inc hl
	ld a,(de)
	exx
	or b
	exx
	and c
	ld c,a
	ld e,(hl)
	inc hl
	ld a,(de)
	or c
	ld (cc_scratch+4),a
	ld e,(hl)
	inc hl
	ld a,(de)
	exx
	or b
	exx
	and b
	ld b,a
	ld e,(hl)
	inc hl
	ld a,(de)
	or b
	ld (cc_scratch+5),a

	; 3

	ld bc,(cc_scratch+6)		; C = dst[6], B = dst[7]
	ld e,(hl)
	inc hl
	ld a,(de)
	exx
	or b
	exx
	and c
	ld c,a
	ld e,(hl)
	inc hl
	ld a,(de)
	or c
	ld (cc_scratch+6),a
	ld e,(hl)
	inc hl
	ld a,(de)
	exx
	or b
	exx
	and b
	ld b,a
	ld e,(hl)
	ld a,(de)
	or b
	ld (cc_scratch+7),a

	ret

	ENDIF			; JSP_TARGET_CPC
