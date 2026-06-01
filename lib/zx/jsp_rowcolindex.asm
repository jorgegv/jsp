;; jsp_rowcolindex / jsp_rowcolindex_dtt — ZX cell-index helpers
;; split out of the former lib/jsp_util.asm (Phase 1.1).
;;
;; ZX-only platform layer (seam, doc/CPC-TARGET-PLAN.md §1.3 / §2): the grid is
;; 32 columns wide, so the cell index is row*32 + col.  The CPC build provides
;; its own lib/cpc/jsp_rowcolindex.asm (row*80, Model A) — selected by the
;; Makefile per JSP_TARGET.

	section code_compiler

	public jsp_rowcolindex
	public jsp_rowcolindex_dtt

;; jsp_rowcolindex: calculates index of (r,c) pair into the DTT/BTT tables
;; input: D = row, E = col
;; return: HL = row * 32 + col (0-767)
;; trashes HL,DE
jsp_rowcolindex:
	ld h,0
	ld l,d		; HL = row

	ld d,h		; D = 0, needed later

	add hl,hl	; HL = row * 32
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl

	add hl,de	; HL += col
	ret

;; jsp_rowcolindex_dtt: calculates index of (r,c) pair into DTT table (8-bit packed)
;; input: D = row, E = col
;; return: HL = ( row * 32 + col (0-767) ) / 8 (0-95)
;; trashes A,E
;; NOTE: H is forced to 0 here.  Callers (jsp_dtt/jsp_ftt) add this to a
;; table base, so HL must be a clean 0..95 value.  When these functions are
;; called from C, SDCC does not zero-extend the 8-bit row/col arguments, so
;; H must not be assumed 0 on entry.
jsp_rowcolindex_dtt:
	srl e
	srl e
	srl e		; E = col / 8
	ld a,d
	rlca		; A = row * 4
	rlca
	or e		; add both
	ld l,a		; return offset in L
	ld h,0		; HL = offset (do not rely on caller's H)
	ret
