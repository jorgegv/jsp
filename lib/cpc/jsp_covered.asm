;; CPC covered-cell compositor.
;;
;; PHASE 2 STUB: provides the data symbols the redraw/precompute reference and a
;; no-op jsp_redraw_covered_cell. In Phase 2 frame_count is always 0, so the
;; covered path is never taken; this only needs to LINK. Phase 3 implements the
;; real CPC Mode-2 compositor (seed scratch from BTT, composite covering sprites
;; via the CPC shift/composite kernels, single store) here.

	IFDEF JSP_TARGET_CPC

	section code_compiler

	public _jsp_redraw_covered_cell
	public _jsp_cc_row_active_row
	public cc_cell			; cell-index input from jsp_redraw
	public cc_scratch		; 8-byte compositing buffer (kernels, Phase 3)

;; void jsp_redraw_covered_cell( uint16_t rowcol ) __z88dk_fastcall;  (Phase 3)
_jsp_redraw_covered_cell:
	ret

	section data_compiler
cc_cell:		dw 0
cc_scratch:		ds 8
_jsp_cc_row_active_row:	db 0xFF

	ENDIF			; JSP_TARGET_CPC
