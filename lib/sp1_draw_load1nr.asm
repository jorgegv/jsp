
; DRAW LOAD SPRITE 1 BYTE DEFINITION NO ROTATION
; 01.2006 aralbrec, Sprite Pack v3.0
; sinclair spectrum version
; 12.2024 adapted by zxjogv (zx@jogv.es) for JSP

	section code_compiler

	public _SP1_DRAW_LOAD1NR
	public _sp1_draw_load1nr

; void sp1_draw_load1nr( uint8_t *dst, uint8_t *graph ) __smallc __z88dk_callee;
_sp1_draw_load1nr: 
	pop de		; save ret addr

	pop hl		; hl = graphic def ptr
	pop bc		; bc = graphic disp

	push de		;; restore ret addr

;  a = hor rot table
; bc = graphic disp
; hl = graphic def ptr

_SP1_DRAW_LOAD1NR:

	; hl = sprite def (graph only)

	ld de,bc	; synthetic
	ldi
	ldi
	ldi
	ldi
	ldi
	ldi
	ldi
;	ld a,(hl)
;	ld (de),a
	ldi	; why the previous 2 lines?

	ret
