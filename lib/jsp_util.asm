;; some utility functions

	section code_compiler

	public _jsp_memzero
	public _jsp_memcpy

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
