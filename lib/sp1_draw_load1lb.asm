
; DRAW LOAD SPRITE 1 BYTE DEFINITION ROTATED, ON LEFT BORDER
; 01.2006 aralbrec, Sprite Pack v3.0
; sinclair spectrum version
; 12.2024 adapted by zxjogv (zx@jogv.es) for JSP

	section code_compiler

	public _SP1_DRAW_LOAD1LB
	public _SP1_DRAW_LOAD1LB_ALT
	public _sp1_draw_load1lb

	extern _SP1_DRAW_LOAD1NR
	extern _jsp_current_rottbl_msb
	extern _jsp_rottbl

; void sp1_draw_load1lb( uint8_t *dst, uint8_t *graph ) __smallc __z88dk_callee;
_sp1_draw_load1lb:
	pop de		; save ret addr

	ld a,(_jsp_current_rottbl_msb)		; a = hor rot table

	pop hl		; hl = graphic def ptr
	pop bc		; bc = graphic disp

	push de		;; restore ret addr

;  a = hor rot table
; bc = graphic disp
; hl = graphic def ptr

_SP1_DRAW_LOAD1LB:

	cp _jsp_rottbl/256 - 2
	jp z, _SP1_DRAW_LOAD1NR

	ld d,a

_SP1_DRAW_LOAD1LB_ALT:

	push ix	; save!

	push bc
	pop ix
	

	;  d = shift table
	; hl = sprite def (graph only)
	; ix = dst buf

_SP1Load1LBRotate:

	; 0

	ld e,(hl)
	inc hl
	ld a,(de)
	ld (ix+0),a

	; 1

	ld e,(hl)
	inc hl
	ld a,(de)
	ld (ix+1),a

	; 2

	ld e,(hl)
	inc hl
	ld a,(de)
	ld (ix+2),a

	; 3

	ld e,(hl)
	inc hl
	ld a,(de)
	ld (ix+3),a

	; 4

	ld e,(hl)
	inc hl
	ld a,(de)
	ld (ix+4),a

	; 5

	ld e,(hl)
	inc hl
	ld a,(de)
	ld (ix+5),a

	; 6

	ld e,(hl)
	inc hl
	ld a,(de)
	ld (ix+6),a

	; 7

	ld e,(hl)
	ld a,(de)
	ld (ix+7),a

	pop ix	; restore!
	ret
