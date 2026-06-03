
; DRAW LOAD SPRITE 1 BYTE DEFINITION ROTATED, ON LEFT BORDER
; 01.2006 aralbrec, Sprite Pack v3.0
; sinclair spectrum version
; 12.2024 adapted by zxjogv (zx@jogv.es) for JSP

	IFDEF JSP_TARGET_CPC		; CPC shift kernel (shared by all CPC shifting modes) - port of lib/zx/jsp_draw_load1lb.asm. Table-driven via jsp_rottbl, so the pixel encoding lives in the table, not here: identical for M2 (1bpp linear) and M1 (nibble-plane). plan section 5
	IF CPC_MODE0_FAST || CPC_MODE1_FAST || CPC_MODE2_FAST
	; FAST (byte-aligned) build: this rotating kernel is unused — the
	; covered-cell compositor calls the no-rotate kernel directly, so no
	; shift kernel (or its redirect prologue) is linked into a FAST binary.
	ELSE

	section code_compiler

	INCLUDE "jsp_cpc_geom.inc"	; JSP_GEOM_COLBYTES
	INCLUDE "jsp_cc_store.inc"	; CC_WR — absolute (Model A/M2) or (iy+n) (Model B)

	public _JSP_DRAW_LOAD1LB
	public _JSP_DRAW_LOAD1LB_ALT
	public _jsp_draw_load1lb

	extern _JSP_DRAW_LOAD1NR
	extern _jsp_current_rottbl_msb
	extern _jsp_rottbl
	extern cc_scratch		; Model A / M2: fixed buffer, absolute (13T).
					; Model B M1/M0: per-column slot in BC -> IY (19T).

; void jsp_draw_load1lb( uint8_t *dst, uint8_t *graph ) __smallc __z88dk_callee;
_jsp_draw_load1lb:
	pop de		; save ret addr

	ld a,(_jsp_current_rottbl_msb)		; a = hor rot table

	pop hl		; hl = graphic def ptr
	pop bc		; bc = graphic disp

	push de		;; restore ret addr

;  a = hor rot table
; bc = graphic disp
; hl = graphic def ptr

_JSP_DRAW_LOAD1LB:

	cp _jsp_rottbl/256 - 2
	jp z, _JSP_DRAW_LOAD1NR

	ld d,a

_JSP_DRAW_LOAD1LB_ALT:

	;  d = shift table
	; hl = sprite def (graph only)
	; dst = cc_scratch (Model A/M2) or BC->IY per-column slot (Model B)
	IF JSP_GEOM_COLBYTES > 1
	push bc				; BC = dst (popped above / from rb) -> IY
	pop iy
	ENDIF

_JSPLoad1LBRotate:

	; 0

	ld e,(hl)
	inc hl
	ld a,(de)
	CC_WR 0

	; 1

	ld e,(hl)
	inc hl
	ld a,(de)
	CC_WR 1

	; 2

	ld e,(hl)
	inc hl
	ld a,(de)
	CC_WR 2

	; 3

	ld e,(hl)
	inc hl
	ld a,(de)
	CC_WR 3

	; 4

	ld e,(hl)
	inc hl
	ld a,(de)
	CC_WR 4

	; 5

	ld e,(hl)
	inc hl
	ld a,(de)
	CC_WR 5

	; 6

	ld e,(hl)
	inc hl
	ld a,(de)
	CC_WR 6

	; 7

	ld e,(hl)
	ld a,(de)
	CC_WR 7

	ret

	ENDIF			; CPC_MODE*_FAST (rotating kernel skipped)
	ENDIF			; JSP_TARGET_CPC
