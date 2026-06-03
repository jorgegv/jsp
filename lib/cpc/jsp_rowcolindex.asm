;; jsp_rowcolindex / jsp_rowcolindex_dtt — CPC (Model-A, 80-col grid) cell index.
;; CPC-only platform layer (doc/CPC-TARGET-PLAN.md §1.3 / §2 / §9).
;; The grid is 80 columns wide, so the cell index is row*80 + col, and the
;; DTT/FTT byte index is (row*80 + col) / 8 = row*10 + col/8.

	IFDEF JSP_TARGET_CPC		; belt-and-suspenders (Makefile selects lib/cpc)

	INCLUDE "jsp_cpc_geom.inc"	; JSP_GEOM_COLS / JSP_PPB_SHIFT

	section code_compiler

	public jsp_rowcolindex
	public jsp_rowcolindex_dtt

;; jsp_rowcolindex: index of (r,c) into the BTT/cell tables
;; input:  D = row, E = col
;; return: HL = row*JSP_GEOM_COLS + col
;;           Model A: row*80 + col (0..1999)
;;           Model B: row*COLS + col, COLS = 10*ppb = 20/40/80 (M0/M1/M2)
;; trashes A,DE,HL
jsp_rowcolindex:
	ld a,e			; A = col (save)
	ld h,0
	ld l,d			; HL = row
  IFDEF JSP_CELL_MODEL_PIXEL
	;; Model B: row*COLS = (row*10) << JSP_PPB_SHIFT
	ld d,h
	ld e,l			; DE = row
	add hl,hl		; 2*row
	add hl,hl		; 4*row
	add hl,de		; 5*row
	add hl,hl		; 10*row
	REPT JSP_PPB_SHIFT
	add hl,hl		; << ppb_shift  -> row * (10*ppb) = row*COLS
	ENDR
  ELSE
	;; Model A: row*80
	ld d,h
	ld e,l			; DE = row  (copy; D was row, now 0)
	add hl,hl		; 2*row
	add hl,hl		; 4*row
	add hl,de		; 5*row
	add hl,hl		; 10*row
	add hl,hl		; 20*row
	add hl,hl		; 40*row
	add hl,hl		; 80*row
  ENDIF
	ld e,a
	ld d,0			; DE = col
	add hl,de		; + col
	ret

;; jsp_rowcolindex_dtt: index of (r,c) into the packed DTT/FTT table
;; input:  D = row, E = col
;; return: HL = (row*COLS + col) / 8
;;           Model A: row*10 + col/8 (0..249)
;; trashes A,DE,HL
;; NOTE: Model B's Mode-0 row-aligned DTT (Phase 4) overrides this; for the flat
;; packed DTT (Model A, and Model-B M1/M2) the cell index >> 3 is the byte index.
jsp_rowcolindex_dtt:
  IFDEF JSP_CELL_MODEL_PIXEL
	;; Model B (flat DTT): cell_index / 8
	call jsp_rowcolindex	; HL = row*COLS + col
	srl h
	rr l
	srl h
	rr l
	srl h
	rr l			; HL = cell_index / 8
	ret
  ELSE
	ld a,e
	srl a
	srl a
	srl a			; A = col / 8  (0..9)
	ld h,0
	ld l,d			; HL = row
	add hl,hl		; 2*row
	ld d,h
	ld e,l			; DE = 2*row
	add hl,hl		; 4*row
	add hl,hl		; 8*row
	add hl,de		; 10*row
	ld e,a
	ld d,0
	add hl,de		; + col/8
	ret
  ENDIF

	ENDIF			; JSP_TARGET_CPC
