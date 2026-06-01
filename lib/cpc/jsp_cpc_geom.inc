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
