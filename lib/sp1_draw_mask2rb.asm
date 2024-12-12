
; DRAW MASK SPRITE 2 BYTE DEFINITION ROTATED, ON RIGHT BORDER
; 01.2006 aralbrec, Sprite Pack v3.0
; sinclair spectrum version
; 12.2024 adapted by zxjogv (zx@jogv.es) for JSP

	section code_compiler

	public _SP1_DRAW_MASK2RB
	public _sp1_draw_mask2rb

	extern _SP1_DRAW_MASK2LB_ALT
	extern _jsp_rottbl

;; void sp1_draw_mask2rb( uint8_t *dst, uint8_t *graph, uint8_t *rottbl ) __smallc __z88dk_callee;

_sp1_draw_mask2rb:
	pop de		; save ret addr

	pop bc
	ld a,b		; a = hor rot table

	pop hl		; hl = left graphic def ptr
	pop bc		; bc = graphic disp

	push de		;; restore ret addr

;  a = hor rot table
; bc = graphic disp
; de = graphic def ptr
; hl = left graphic def ptr

_SP1_DRAW_MASK2RB:

	cp _jsp_rottbl/256 - 2
	ret z

	ld d,a
	inc d

	;  d = shift table
	; hl = left sprite def (mask,graph) pairs
	; bc = graphic disp

_SP1Mask2RBRotate:

	jp _SP1_DRAW_MASK2LB_ALT
