
; DRAW MASK SPRITE 2 BYTE DEFINITION ROTATED, ON RIGHT BORDER
; 01.2006 aralbrec, Sprite Pack v3.0
; sinclair spectrum version
; 12.2024 adapted by zxjogv (zx@jogv.es) for JSP

	IFDEF JSP_TARGET_CPC		; CPC shift kernel (shared by all CPC shifting modes) - port of lib/zx/jsp_draw_mask2rb.asm. Table-driven via jsp_rottbl, so the pixel encoding lives in the table, not here: identical for M2 (1bpp linear) and M1 (nibble-plane). plan section 5
	IF CPC_MODE0_FAST || CPC_MODE1_FAST || CPC_MODE2_FAST || CPC_MODE0_IMASK || CPC_MODE1_IMASK
	; FAST (byte-aligned) build: this rotating kernel is unused — the
	; covered-cell compositor calls the no-rotate kernel directly, so no
	; shift kernel (or its redirect prologue) is linked into a FAST binary.
	ELSE

	section code_compiler

	public _JSP_DRAW_MASK2RB
	public _jsp_draw_mask2rb

	extern _JSP_DRAW_MASK2LB_ALT
	extern _jsp_rottbl
	extern _jsp_current_rottbl_msb

;; void jsp_draw_mask2rb( uint8_t *dst, uint8_t *graph ) __smallc __z88dk_callee;

_jsp_draw_mask2rb:
	pop de		; save ret addr

	ld a,(_jsp_current_rottbl_msb)		; a = hor rot table

	pop hl		; hl = left graphic def ptr
	pop bc		; bc = graphic disp

	push de		;; restore ret addr

;  a = hor rot table
; bc = graphic disp
; de = graphic def ptr
; hl = left graphic def ptr

_JSP_DRAW_MASK2RB:

	cp _jsp_rottbl/256 - 2
	ret z

	ld d,a
	inc d

	;  d = shift table
	; hl = left sprite def (mask,graph) pairs
	; bc = graphic disp

_JSPMask2RBRotate:

	jp _JSP_DRAW_MASK2LB_ALT

	ENDIF			; CPC_MODE*_FAST (rotating kernel skipped)
	ENDIF			; JSP_TARGET_CPC
