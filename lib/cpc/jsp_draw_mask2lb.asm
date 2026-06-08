
; DRAW MASK SPRITE 2 BYTE DEFINITION ROTATED, ON LEFT BORDER
; 01.2006 aralbrec, Sprite Pack v3.0
; sinclair spectrum version
; 12.2024 adapted by zxjogv (zx@jogv.es) for JSP

	IFDEF JSP_TARGET_CPC		; CPC shift kernel (shared by all CPC shifting modes) - port of lib/zx/jsp_draw_mask2lb.asm. Table-driven via jsp_rottbl, so the pixel encoding lives in the table, not here: identical for M2 (1bpp linear) and M1 (nibble-plane). plan section 5
	IF CPC_MODE0_FAST || CPC_MODE1_FAST || CPC_MODE2_FAST || CPC_MODE0_IMASK || CPC_MODE1_IMASK
	; FAST (byte-aligned) build: this rotating kernel is unused — the
	; covered-cell compositor calls the no-rotate kernel directly, so no
	; shift kernel (or its redirect prologue) is linked into a FAST binary.
	ELSE

	section code_compiler

	INCLUDE "jsp_cpc_geom.inc"	; JSP_GEOM_COLBYTES
	INCLUDE "jsp_cc_store.inc"	; CC_RD16/CC_WR — absolute (Model A/M2) or (iy+n) (Model B)

	public _JSP_DRAW_MASK2LB
	public _JSP_DRAW_MASK2LB_ALT
	public _jsp_draw_mask2lb

	extern _JSP_DRAW_MASK2NR
	extern _jsp_rottbl
	extern _jsp_current_rottbl_msb
	extern cc_scratch		; Model A / M2: fixed buffer, absolute (the
					; two-byte reads fold into ld bc,(nn)).
					; Model B M1/M0: per-column slot in BC -> IY.

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
	; dst = cc_scratch (Model A/M2) or BC->IY per-column slot (Model B)
	IF JSP_GEOM_COLBYTES > 1
	push bc				; BC = dst (popped above / from rb) -> IY
	pop iy
	ENDIF

	ld e,$ff
	ld a,(de)
	cpl
	exx
	ld b,a
	exx

_JSPMask2LBRotate:

	; 0

	CC_RD16 0		; C = dst[0], B = dst[1]
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
	CC_WR 0
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
	CC_WR 1

	; 1

	CC_RD16 2		; C = dst[2], B = dst[3]
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
	CC_WR 2
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
	CC_WR 3

	; 2

	CC_RD16 4		; C = dst[4], B = dst[5]
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
	CC_WR 4
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
	CC_WR 5

	; 3

	CC_RD16 6		; C = dst[6], B = dst[7]
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
	CC_WR 6
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
	CC_WR 7

	ret

	ENDIF			; CPC_MODE*_FAST (rotating kernel skipped)
	ENDIF			; JSP_TARGET_CPC
