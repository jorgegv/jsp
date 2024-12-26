
; DRAW LOAD SPRITE 1 BYTE DEFINITION ROTATED, ON RIGHT BORDER
; 01.2006 aralbrec, Sprite Pack v3.0
; sinclair spectrum version

	section code_compiler

	public _SP1_DRAW_LOAD1RB
	public _sp1_draw_load1rb

	extern _SP1_DRAW_LOAD1LB
	extern _SP1_DRAW_LOAD1LB_ALT
	extern _jsp_rottbl
	extern _jsp_current_rottbl_msb

; void sp1_draw_load1rb( uint8_t *dst, uint8_t *graph ) __smallc __z88dk_callee;
_sp1_draw_load1rb:
	pop de		; save ret addr

	ld a,(_jsp_current_rottbl_msb)		; a = hor rot table

	pop hl		; hl = graphic def ptr
	pop bc		; bc = graphic disp

	push de		;; restore ret addr


;  a = hor rot table
; bc = graphic disp
; hl = graphic def ptr

_SP1_DRAW_LOAD1RB:

	cp _jsp_rottbl/256 - 2
	ret z

	ld d,a
	inc d

	;  d = shift table
	; hl = left sprite def (graph only)

_SP1Load1RBRotate:

	jp _SP1_DRAW_LOAD1LB_ALT
