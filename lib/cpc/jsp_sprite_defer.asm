;; CPC deferred sprite ops + mark_rect.
;;
;; PHASE 2 STUB: the CPC sprite footprint/coordinate logic is built in Phase 3.
;; For now these only need to LINK (the shared jsp_sprite_c.c wrappers reference
;; move/draw/park; jsp_tiles.c's jsp_invalidate_rect references mark_rect). The
;; Phase-2 background-tile test does not call them. Each stub correctly cleans
;; its arguments off the stack per the calling convention, then returns, so an
;; accidental call cannot corrupt the stack — it simply does nothing.
;; Phase 3 replaces these with the real CPC (row*80 grid) implementations.

	IFDEF JSP_TARGET_CPC

	section code_compiler

	public _jsp_dtt_mark_rect
	public _jsp_move_sprite
	public _jsp_draw_sprite
	public _jsp_sprite_park

;; void jsp_move_sprite( sp, xpos, ypos ) __smallc __z88dk_callee;  (3 arg words)
_jsp_move_sprite:
_jsp_draw_sprite:
	pop hl			; return address
	pop de			; ypos
	pop de			; xpos
	pop de			; sp
	jp (hl)

;; void jsp_dtt_mark_rect( r0, c0, r1, c1 ) __smallc __z88dk_callee;  (4 arg words)
_jsp_dtt_mark_rect:
	pop hl			; return address
	pop de			; c1
	pop de			; r1
	pop de			; c0
	pop de			; r0
	jp (hl)

;; void jsp_sprite_park( sp ) __z88dk_fastcall;  (arg in HL, nothing on stack)
_jsp_sprite_park:
	ret

	ENDIF			; JSP_TARGET_CPC
