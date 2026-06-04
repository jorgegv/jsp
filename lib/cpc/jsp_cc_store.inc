;; jsp_cc_store.inc — compositing-scratch access macros for the CPC rotating
;; kernels (jsp_draw_load1/lb, jsp_draw_mask2/lb).
;;
;; Model A (byte-cell) and Mode 2 (COLBYTES == 1): the per-cell scratch is always
;; the fixed 8-byte cc_scratch buffer, so the kernels address it ABSOLUTELY
;; (`ld (cc_scratch+n),a`, 13T) — fast, and byte-identical to the original.
;;
;; Model B M1/M0 (COLBYTES > 1): a cell spans COLBYTES byte-columns, so the
;; compositor composites each byte-column into a different 8-byte slot of a wide
;; scratch.  It passes that slot's base as the kernel's `dst` arg; the kernel
;; loads it into IY (free in all rotating kernels) and addresses the scratch via
;; `(iy+n)` (19T).  The extra 6T/byte is the Model-B price, paid only in M1/M0.
;;
;; Requires jsp_cpc_geom.inc (JSP_GEOM_COLBYTES) to be included first.
;;   CC_RD n : A <- scratch[n]
;;   CC_WR n : scratch[n] <- A

;; CC_RD16 n : C <- scratch[n], B <- scratch[n+1]  (mask2lb's folded pair read)
	IF JSP_GEOM_COLBYTES > 1
	MACRO CC_RD n
	ld a,(iy+n)
	ENDM
	MACRO CC_WR n
	ld (iy+n),a
	ENDM
	MACRO CC_RD16 n
	ld c,(iy+n)
	ld b,(iy+n+1)
	ENDM
	ELSE
	MACRO CC_RD n
	ld a,(cc_scratch+n)
	ENDM
	MACRO CC_WR n
	ld (cc_scratch+n),a
	ENDM
	MACRO CC_RD16 n
	ld bc,(cc_scratch+n)
	ENDM
	ENDIF
