;; jsp_draw_imask — CPC implicit-mask (_IMASK) draw kernels (assembly).
;;
;; The _IMASK sprite modes (CPC_MODE0_IMASK / CPC_MODE1_IMASK) store graph bytes
;; only (8 B/cell, like LOAD1); pen 0 is transparent and the per-pixel mask is
;; derived at composite time from the graph byte via jsp_imask_tbl[256] (built in
;; lib/jsp_init.c from JSP_IMASK()).  The composite per byte is:
;;
;;     screen = ( background & jsp_imask_tbl[ graph ] ) | graph
;;
;; The graph is shifted exactly as LOAD1 shifts it (table-driven via jsp_rottbl:
;; out = IN(this) | CARRY(left)); the only addition is the per-byte LUT lookup
;; for the mask.  Because the LUT maps pen-0 (all-zero) pixels to "keep
;; background", a sprite's vacated/border bits (which are 0) are transparent for
;; free — so the border kernels need no special 0xFF mask seeding (unlike MASK2).
;;
;; Four kernels, same signatures as the MASK2 family so the covered-cell
;; compositor only swaps the call target:
;;   _jsp_draw_imask   (dst, graph, graph_left)  middle column: IN(this)|CARRY(left)
;;   _jsp_draw_imasknr (dst, graph)              no rotation (xrot==0 aligned)
;;   _jsp_draw_imasklb (dst, graph)              left border:  IN(this) only
;;   _jsp_draw_imaskrb (dst, graph)              right border: CARRY(this) only
;;
;; Written in a simple, uniform per-line style (correctness first); the rottbl
;; page is held in B across the line loop and H is reloaded each line, swapping
;; to the LUT page (immediate _jsp_imask_tbl/256) for the mask lookup.

	IFDEF JSP_TARGET_CPC
	IF CPC_MODE0_IMASK || CPC_MODE1_IMASK

	section code_compiler

	INCLUDE "jsp_cpc_geom.inc"	; JSP_GEOM_COLBYTES
	INCLUDE "jsp_cc_store.inc"	; CC_RD/CC_WR — absolute (Model A/M2) or (iy+n)

	public _jsp_draw_imask
	public _jsp_draw_imasknr
	public _jsp_draw_imasklb
	public _jsp_draw_imaskrb
	public _JSP_DRAW_IMASKNR

	extern _jsp_rottbl
	extern _jsp_current_rottbl_msb
	extern _jsp_imask_tbl
	extern cc_scratch

;; ---- per-line composite macros --------------------------------------------
;; MID line n: B = rottbl IN page, DE = this graph ptr, IX = left graph def,
;;             dst via CC (iy / absolute).  G = IN(this) | CARRY(left).
	MACRO IMASK_MID n
	ld h,b				; H = rottbl IN page
	ld a,(de)			; this graph byte
	inc de
	ld l,a
	ld a,(hl)			; IN(this)
	inc h				; H = CARRY page
	ld l,(ix+n)			; left graph byte (line n)
	or (hl)				; A = G = IN(this) | CARRY(left)
	ld c,a				; save G
	ld l,a
	ld h,_jsp_imask_tbl/256		; H = LUT page
	ld a,(hl)			; A = mask = jsp_imask_tbl[G]
	ld l,a				; stash mask in L (CC_RD/WR don't touch L)
	CC_RD n				; A = background
	and l				; bg & mask
	or c				; | graph
	CC_WR n				; store
	ENDM

;; BORDER line n: B = rottbl IN page, DE = source graph ptr, dst via CC.
;;   carry=0 -> G = IN(source)   (left border, this column)
;;   carry=1 -> G = CARRY(source) (right border, last column's spill)
	MACRO IMASK_BORDER n, carry
	ld h,b				; H = rottbl IN page
	IF carry
	inc h				; H = CARRY page
	ENDIF
	ld a,(de)			; source graph byte
	inc de
	ld l,a
	ld a,(hl)			; A = G (IN or CARRY half)
	ld c,a				; save G
	ld l,a
	ld h,_jsp_imask_tbl/256		; H = LUT page
	ld a,(hl)			; A = mask
	ld l,a
	CC_RD n
	and l
	or c
	CC_WR n
	ENDM

;; NR line n: H = LUT page (constant), DE = graph ptr, IX = dst.  G = graph.
	MACRO IMASK_NR n
	ld a,(de)			; G = graph (no shift)
	inc de
	ld c,a				; save G
	ld l,a
	ld a,(hl)			; mask = jsp_imask_tbl[G]   (H = LUT page)
	ld l,a
	ld a,(ix+n)			; background
	and l
	or c
	ld (ix+n),a			; store
	ENDM

;; ===========================================================================
;; void jsp_draw_imask( uint8_t *dst, uint8_t *graph, uint8_t *graph_left )
;;     __smallc __z88dk_callee;   Trashes DE'!
;; ===========================================================================
_jsp_draw_imask:
	exx
	pop de				; save ret addr
	exx
	ld a,(_jsp_current_rottbl_msb)	; A = rottbl page
	pop de				; DE = left graphic def ptr
	pop hl				; HL = graphic def ptr
	pop bc				; BC = dst
	exx
	push de				; restore ret addr
	exx

	cp _jsp_rottbl/256 - 2		; xrot==0 aligned -> no-rotate kernel
	jp z, _JSP_DRAW_IMASKNR

	push ix				; save caller's IX (frame sprite)
	push de
	pop ix				; IX = left graphic def
	ex de,hl			; DE = this graphic def ptr
	IF JSP_GEOM_COLBYTES > 1
	push bc
	pop iy				; IY = dst slot
	ENDIF
	ld b,a				; B = rottbl IN page

	IMASK_MID 0
	IMASK_MID 1
	IMASK_MID 2
	IMASK_MID 3
	IMASK_MID 4
	IMASK_MID 5
	IMASK_MID 6
	IMASK_MID 7

	pop ix				; restore caller's IX
	ret

;; ===========================================================================
;; void jsp_draw_imasknr( uint8_t *dst, uint8_t *graph ) __smallc __z88dk_callee;
;; Also the aligned target of the mid/lb kernels (entry _JSP_DRAW_IMASKNR:
;; HL = graph, BC = dst).
;; ===========================================================================
_jsp_draw_imasknr:
	pop de				; save ret addr
	pop hl				; HL = graphic def ptr
	pop bc				; BC = dst
	push de				; restore ret addr
_JSP_DRAW_IMASKNR:
	push ix				; save caller's IX
	push bc
	pop ix				; IX = dst
	ex de,hl			; DE = graphic def ptr
	ld h,_jsp_imask_tbl/256		; H = LUT page (constant for this kernel)

	IMASK_NR 0
	IMASK_NR 1
	IMASK_NR 2
	IMASK_NR 3
	IMASK_NR 4
	IMASK_NR 5
	IMASK_NR 6
	IMASK_NR 7

	pop ix				; restore caller's IX
	ret

;; ===========================================================================
;; void jsp_draw_imasklb( uint8_t *dst, uint8_t *graph ) __smallc __z88dk_callee;
;; Left border (leftmost column): G = IN(this) only (no left neighbour).
;; ===========================================================================
_jsp_draw_imasklb:
	pop de				; save ret addr
	ld a,(_jsp_current_rottbl_msb)
	pop hl				; HL = graphic def ptr
	pop bc				; BC = dst
	push de				; restore ret addr

	cp _jsp_rottbl/256 - 2		; aligned -> no-rotate kernel
	jp z, _JSP_DRAW_IMASKNR

	IF JSP_GEOM_COLBYTES > 1
	push bc
	pop iy				; IY = dst slot
	ENDIF
	ex de,hl			; DE = graphic def ptr
	ld b,a				; B = rottbl IN page

	IMASK_BORDER 0, 0
	IMASK_BORDER 1, 0
	IMASK_BORDER 2, 0
	IMASK_BORDER 3, 0
	IMASK_BORDER 4, 0
	IMASK_BORDER 5, 0
	IMASK_BORDER 6, 0
	IMASK_BORDER 7, 0
	ret

;; ===========================================================================
;; void jsp_draw_imaskrb( uint8_t *dst, uint8_t *graph ) __smallc __z88dk_callee;
;; Right border (overflow column): G = CARRY(this) only (last column's spill).
;; HL on entry = the last real column's graph def (dispatch passes pdc=cols-1).
;; ===========================================================================
_jsp_draw_imaskrb:
	pop de				; save ret addr
	ld a,(_jsp_current_rottbl_msb)
	pop hl				; HL = graphic def ptr (last column)
	pop bc				; BC = dst
	push de				; restore ret addr

	cp _jsp_rottbl/256 - 2		; aligned -> no spill: nothing to draw
	ret z

	IF JSP_GEOM_COLBYTES > 1
	push bc
	pop iy				; IY = dst slot
	ENDIF
	ex de,hl			; DE = graphic def ptr
	ld b,a				; B = rottbl IN page

	IMASK_BORDER 0, 1
	IMASK_BORDER 1, 1
	IMASK_BORDER 2, 1
	IMASK_BORDER 3, 1
	IMASK_BORDER 4, 1
	IMASK_BORDER 5, 1
	IMASK_BORDER 6, 1
	IMASK_BORDER 7, 1
	ret

	ENDIF			; CPC_MODE0_IMASK || CPC_MODE1_IMASK
	ENDIF			; JSP_TARGET_CPC
