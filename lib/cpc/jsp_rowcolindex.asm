;; jsp_rowcolindex / jsp_rowcolindex_dtt — CPC (Model-A, 80-col grid) cell index.
;; CPC-only platform layer (doc/CPC-TARGET-PLAN.md §1.3 / §2 / §9).
;; The grid is 80 columns wide, so the cell index is row*80 + col, and the
;; DTT/FTT byte index is (row*80 + col) / 8 = row*10 + col/8.

	IFDEF JSP_TARGET_CPC		; belt-and-suspenders (Makefile selects lib/cpc)

	section code_compiler

	public jsp_rowcolindex
	public jsp_rowcolindex_dtt

;; jsp_rowcolindex: index of (r,c) into the BTT/cell tables
;; input:  D = row, E = col
;; return: HL = row*80 + col  (0..1999)
;; trashes A,DE,HL
jsp_rowcolindex:
	ld a,e			; A = col (save)
	ld h,0
	ld l,d			; HL = row
	ld d,h
	ld e,l			; DE = row  (copy; D was row, now 0)
	add hl,hl		; 2*row
	add hl,hl		; 4*row
	add hl,de		; 5*row
	add hl,hl		; 10*row
	add hl,hl		; 20*row
	add hl,hl		; 40*row
	add hl,hl		; 80*row
	ld e,a
	ld d,0			; DE = col
	add hl,de		; + col
	ret

;; jsp_rowcolindex_dtt: index of (r,c) into the packed DTT/FTT table
;; input:  D = row, E = col
;; return: HL = (row*80 + col) / 8 = row*10 + col/8   (0..249)
;; trashes A,DE,HL
jsp_rowcolindex_dtt:
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

	ENDIF			; JSP_TARGET_CPC
