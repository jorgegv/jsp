
; DRAW LOAD SPRITE 1 BYTE DEFINITION ROTATED, ON LEFT BORDER
; 01.2006 aralbrec, Sprite Pack v3.0
; sinclair spectrum version
; 12.2024 adapted by zxjogv (zx@jogv.es) for JSP

	IFDEF JSP_TARGET_CPC		; CPC shift kernel (shared by all CPC shifting modes) - port of lib/zx/jsp_draw_load1lb.asm. Table-driven via jsp_rottbl, so the pixel encoding lives in the table, not here: identical for M2 (1bpp linear) and M1 (nibble-plane). plan section 5
	section code_compiler

	public _JSP_DRAW_LOAD1LB
	public _JSP_DRAW_LOAD1LB_ALT
	public _jsp_draw_load1lb

	extern _JSP_DRAW_LOAD1NR
	extern _jsp_current_rottbl_msb
	extern _jsp_rottbl
	extern cc_scratch		; dst is always the JSP compositing buffer,
					; so dst bytes are written absolutely (13T)
					; instead of via (ix+d) (19T)

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
	; dst = cc_scratch (fixed buffer, written absolutely below)

_JSPLoad1LBRotate:

	; 0

	ld e,(hl)
	inc hl
	ld a,(de)
	ld (cc_scratch+0),a

	; 1

	ld e,(hl)
	inc hl
	ld a,(de)
	ld (cc_scratch+1),a

	; 2

	ld e,(hl)
	inc hl
	ld a,(de)
	ld (cc_scratch+2),a

	; 3

	ld e,(hl)
	inc hl
	ld a,(de)
	ld (cc_scratch+3),a

	; 4

	ld e,(hl)
	inc hl
	ld a,(de)
	ld (cc_scratch+4),a

	; 5

	ld e,(hl)
	inc hl
	ld a,(de)
	ld (cc_scratch+5),a

	; 6

	ld e,(hl)
	inc hl
	ld a,(de)
	ld (cc_scratch+6),a

	; 7

	ld e,(hl)
	ld a,(de)
	ld (cc_scratch+7),a

	ret

	ENDIF			; JSP_TARGET_CPC
