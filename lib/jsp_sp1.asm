	section code_compiler

	public _sp1_draw_mask2
	public _sp1_draw_mask2nr
	public _sp1_draw_mask2lb
	public _sp1_draw_mask2rb

	extern _SP1_DRAW_MASK2
	extern _SP1_DRAW_MASK2NR
	extern _SP1_DRAW_MASK2LB
	extern _SP1_DRAW_MASK2RB

;; void sp1_draw_mask2( uint8_t *dst, uint8_t *graph, uint8_t *graph_left, uint8_t *rottbl ) __smallc __z88dk_callee;

_sp1_draw_mask2:
	pop de		; save ret addr

	pop bc
	ld a,b		; a = hor rot table

	pop ix		; ix = left graphic def ptr
	pop hl		; hl = graphic def ptr
	pop bc		; bc = graphic disp

	push de		;; restore ret addr

	jp _SP1_DRAW_MASK2

;; void sp1_draw_mask2nr( uint8_t *dst, uint8_t *graph ) __smallc __z88dk_callee;

_sp1_draw_mask2nr:
	pop ix		; save ret addr

	ld a,0		; a = rot table
	ld de,0		; de = unused
	pop hl		; hl = graphic def ptr
	pop bc		; bc = graphic disp

	push ix		;; restore ret addr

	jp _SP1_DRAW_MASK2NR

;; void sp1_draw_mask2lb( uint8_t *dst, uint8_t *graph, uint8_t *rottbl ) __smallc __z88dk_callee;

_sp1_draw_mask2lb:
	pop ix		; save ret addr

	pop bc
	ld a,b		; a = hor rot table

	pop hl		; hl = graphic def ptr
	pop bc		; bc = graphic disp

	push ix		;; restore ret addr

	jp _SP1_DRAW_MASK2LB

;; void sp1_draw_mask2rb( uint8_t *dst, uint8_t *graph, uint8_t *graph_left, uint8_t *rottbl ) __smallc __z88dk_callee;

_sp1_draw_mask2rb:
	pop ix		; save ret addr

	pop bc
	ld a,b		; a = hor rot table

	pop hl		; hl = left graphic def ptr
	pop de		; de = graphic def ptr
	pop bc		; bc = graphic disp

	push ix		;; restore ret addr

	jp _SP1_DRAW_MASK2RB
