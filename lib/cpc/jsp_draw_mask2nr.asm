
; DRAW MASK SPRITE 2 BYTE DEFINITION NO ROTATION
; 01.2006 aralbrec, Sprite Pack v3.0
; sinclair spectrum version
; 12.2024 adapted by zxjogv (zx@jogv.es) for JSP

	IFDEF JSP_TARGET_CPC		; CPC shift kernel (shared by all CPC shifting modes) - port of lib/zx/jsp_draw_mask2nr.asm. Table-driven via jsp_rottbl, so the pixel encoding lives in the table, not here: identical for M2 (1bpp linear) and M1 (nibble-plane). plan section 5
	section code_compiler

	public _JSP_DRAW_MASK2NR
	public _jsp_draw_mask2nr

;; void jsp_draw_mask2nr( uint8_t *dst, uint8_t *graph ) __smallc __z88dk_callee;

_jsp_draw_mask2nr:
	pop de		; save ret addr

	pop hl		; hl = graphic def ptr
	pop bc		; bc = graphic disp

	push de		;; restore ret addr

;  a = hor rot table
; bc = graphic disp
; hl = graphic def ptr

_JSP_DRAW_MASK2NR:

	; hl = sprite def = (mask,graph) pairs
	; bc = bg cell

	push ix	; save!

	push bc
	pop ix	; ix = dst buffer

	; 0
	ld e,(ix+0)
	ld a,(hl)
	and e
	inc hl
	or (hl)
	inc hl
	ld (ix+0),a

	ld e,(ix+1)
	ld a,(hl)
	and e
	inc hl
	or (hl)
	inc hl
	ld (ix+1),a

	ld e,(ix+2)
	ld a,(hl)
	and e
	inc hl
	or (hl)
	inc hl
	ld (ix+2),a

	ld e,(ix+3)
	ld a,(hl)
	and e
	inc hl
	or (hl)
	inc hl
	ld (ix+3),a

	ld e,(ix+4)
	ld a,(hl)
	and e
	inc hl
	or (hl)
	inc hl
	ld (ix+4),a

	ld e,(ix+5)
	ld a,(hl)
	and e
	inc hl
	or (hl)
	inc hl
	ld (ix+5),a

	ld e,(ix+6)
	ld a,(hl)
	and e
	inc hl
	or (hl)
	inc hl
	ld (ix+6),a

	ld e,(ix+7)
	ld a,(hl)
	and e
	inc hl
	or (hl)
	inc hl
	ld (ix+7),a

	pop ix	; restore!
	ret

	ENDIF			; JSP_TARGET_CPC
