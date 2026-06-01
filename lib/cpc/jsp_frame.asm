;; CPC jsp_redraw_begin — per-frame sprite precompute.
;;
;; PHASE 2 STUB: the CPC sprite compositor is not built until Phase 3, so for
;; now this just declares "no active frame sprites" (frame_count = 0) and resets
;; the covered-cell row-sweep marker. With frame_count == 0 the CPC jsp_redraw
;; takes the background path for every dirty cell — exactly the Phase-2
;; background-tile-only milestone. Phase 3 replaces this with the real
;; registry-walk precompute (CPC coordinate split, footprint rects, etc.).

	IFDEF JSP_TARGET_CPC

	section code_compiler

	extern _jsp_frame_count
	extern _jsp_cc_row_active_row

	public _jsp_redraw_begin

;; void jsp_redraw_begin( void );
_jsp_redraw_begin:
	xor a
	ld (_jsp_frame_count),a		; Phase 2: no composited sprites
	ld a,0xFF
	ld (_jsp_cc_row_active_row),a	; invalidate the row-sweep set
	ret

	ENDIF			; JSP_TARGET_CPC
