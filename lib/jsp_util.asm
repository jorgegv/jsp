;; some utility functions

	section code_compiler

	public _jsp_memzero
	public _jsp_memcpy
	public jsp_rowcolindex
	public jsp_rowcolindex_dtt

;; void jsp_memzero( void *dst, uint16_t numbytes ) __smallc __z88dk_callee;
;; trashes a,bc,de,hl
_jsp_memzero:
	pop af		;; save ret addr

	pop bc		;; BC = numbytes
	pop hl		;; HL = dst

	push af		;; restore ret addr

	ld de,hl
	inc de
	xor a		;; value = 0
	ld (hl),a	;; set first value
	dec bc
	ldir
	ret

;; void jsp_memcoy( void *dst, void *src, uint16_t numbytes ) __smallc __z88dk_callee;
;; trashes a,bc,de,hl
_jsp_memcpy:
	pop af		;; save ret addr

	pop bc		;; BC = numbytes
	pop hl		;; HL = src
	pop de		;; DE = dst

	push af		;; restore ret addr

	ldir
	ret

;; jsp_rowcolindex: calculates index of (r,c) pair into DRT,DTT,BTT tables
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
