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
	IFDEF JSP_CELL_MODEL_PIXEL
	defc JSP_GEOM_COLBYTES  = 8 >> JSP_PPB_SHIFT
	defc JSP_GEOM_CELLSHIFT = 3 - JSP_PPB_SHIFT     ; log2(COLBYTES): 0/1/2 for M2/M1/M0
	ELSE
	defc JSP_GEOM_COLBYTES  = 1
	defc JSP_GEOM_CELLSHIFT = 0                      ; Model A: cell index == byte offset
	ENDIF
	defc JSP_GEOM_COLS      = 80 / JSP_GEOM_COLBYTES
	defc JSP_GEOM_DTT_BYTES = ( JSP_GEOM_COLS * 25 + 7 ) / 8
