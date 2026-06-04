;; jsp_cpc_geom.inc — shared per-mode CPC geometry constants (assembly).
;;
;; The horizontal coordinate split is byte_col = x / ppb, xrot = x % ppb, with
;; ppb = 8/4/2 for Mode 2/1/0 (doc/CPC-TARGET-PLAN.md §3).  Both the per-frame
;; precompute (jsp_frame.asm) and the deferred dirty-marker (jsp_sprite_defer.asm)
;; must use the SAME split, or the cells a sprite is rendered into and the cells
;; marked dirty for it diverge — so the constants live here and are included by
;; every file that needs them.
;;
;;   JSP_PPB_SHIFT = log2(ppb)  -> c0 = xpos >> JSP_PPB_SHIFT
;;   JSP_XROT_MASK = ppb - 1    -> xrot = xpos & JSP_XROT_MASK  (FAST forces 0)
;;   JSP_MONO_DBL  = 1 if a 1bpp source column spans 2 Mode-1 screen cells
;;                   (CPC_MODE1_MONO), else 0 -> footprint width = (1+MONO)*cols

	IFDEF CPC_MODE2
	defc JSP_PPB_SHIFT = 3
	defc JSP_XROT_MASK = 7
	defc JSP_MONO_DBL  = 0
	ENDIF
	IFDEF CPC_MODE2_FAST
	defc JSP_PPB_SHIFT = 3
	defc JSP_XROT_MASK = 0
	defc JSP_MONO_DBL  = 0
	ENDIF
	IFDEF CPC_MODE1
	defc JSP_PPB_SHIFT = 2
	defc JSP_XROT_MASK = 3
	defc JSP_MONO_DBL  = 0
	ENDIF
	IFDEF CPC_MODE1_MONO
	defc JSP_PPB_SHIFT = 2
	defc JSP_XROT_MASK = 3
	defc JSP_MONO_DBL  = 1
	ENDIF
	IFDEF CPC_MODE1_FAST
	defc JSP_PPB_SHIFT = 2
	defc JSP_XROT_MASK = 0
	defc JSP_MONO_DBL  = 0
	ENDIF
	IFDEF CPC_MODE0
	defc JSP_PPB_SHIFT = 1
	defc JSP_XROT_MASK = 1
	defc JSP_MONO_DBL  = 0
	ENDIF
	IFDEF CPC_MODE0_FAST
	defc JSP_PPB_SHIFT = 1
	defc JSP_XROT_MASK = 0
	defc JSP_MONO_DBL  = 0
	ENDIF

;; --- Cell-model grid geometry (must mirror include/jsp_config.h) -----------
;; Model A (byte-cell, default):  COLS = 80, COLBYTES = 1 in every mode.
;; Model B (pixel-cell, -DJSP_CELL_MODEL_PIXEL): 8x8-pixel cells ->
;;   COLBYTES = 8 / ppb = 8 >> JSP_PPB_SHIFT   (1/2/4 for M2/M1/M0)
;;   COLS     = 80 / COLBYTES                  (80/40/20 for M2/M1/M0)
;; A cell's screen byte-offset = COLBYTES * cell_index (because COLS*COLBYTES=80
;; always), so the redraw scales the cell index left by log2(COLBYTES) =
;; 3 - JSP_PPB_SHIFT.  JSP_GEOM_DTT_BYTES = ceil(COLS*25 / 8) is the flat packed
;; DTT size (Mode 0's row-aligned variant is handled in jsp_sprite_defer/redraw).
;; Cell model default (mirror include/jsp_config.h): pixel-cell unless the build
;; explicitly asked for byte-cell.  The Makefile passes the matching -Ca-D...; this
;; only supplies the default for a bare assembler invocation.
	IFNDEF JSP_CELL_MODEL_BYTE
	IFNDEF JSP_CELL_MODEL_PIXEL
	defc JSP_CELL_MODEL_PIXEL = 1	; a defc symbol satisfies the IFDEF below
	ENDIF
	ENDIF

	IFDEF JSP_CELL_MODEL_PIXEL
	defc JSP_GEOM_COLBYTES  = 8 >> JSP_PPB_SHIFT
	defc JSP_GEOM_CELLSHIFT = 3 - JSP_PPB_SHIFT     ; log2(COLBYTES): 0/1/2 for M2/M1/M0
	ELSE
	defc JSP_GEOM_COLBYTES  = 1
	defc JSP_GEOM_CELLSHIFT = 0                      ; Model A: cell index == byte offset
	ENDIF
	defc JSP_GEOM_COLS      = 80 / JSP_GEOM_COLBYTES
;; DTT is ROW-ALIGNED: each cell row occupies a whole number of DTT bytes
;; (ceil(COLS/8)).  For COLS multiple of 8 (Model A 80, M1 40, M2 80) this equals
;; the flat packing; for Model-B Mode 0 (COLS=20) it pads each row to 3 bytes
;; (24 bits, 4 dead) so row*COLS stays byte-aligned and the constant-mask-per-row
;; optimisation in jsp_sprite_defer survives.  (plan §4)
	defc JSP_GEOM_DTT_ROWBYTES = ( JSP_GEOM_COLS + 7 ) / 8     ; 10 / 5 / 3 (M2-A/M1/M0)
	defc JSP_GEOM_DTT_BYTES    = 25 * JSP_GEOM_DTT_ROWBYTES    ; 250 / 125 / 75
;; ROWPAD = dead DTT bits per row = ROWBYTES*8 - COLS.  0 when COLS is a multiple
;; of 8 (Model A, M1, M2 — the DTT bit position equals the linear cell index, so
;; the redraw uses cellbase = g*8).  4 for Model-B Mode 0 (COLS=20): each row's
;; 3rd DTT byte has 4 dead bits, so the redraw tracks the linear cell base
;; incrementally (+8 within a row, +COLS-(ROWBYTES-1)*8 at the row wrap).
	defc JSP_GEOM_DTT_ROWPAD   = JSP_GEOM_DTT_ROWBYTES * 8 - JSP_GEOM_COLS
