	section code_compiler

	extern _jsp_dtt

	public _jsp_dtt_mark_dirty
	public _jsp_dtt_mark_clean
	public _jsp_dtt_is_dirty

;; The following 3 functions are implemented as SMC code that fixes one
;; byte in the jsp_dtt_mark_dirty_clean_test function...  which is itself another
;; SMC function that fixes another 1 byte in itself!  Code that modifies
;; code that modifies code.
;;
;; The function jsp_dtt_mark_dirty_clean_test can do SET, RESet and test a
;; BIT in an address.  The SET/RES/BIT is selected by the entry points
;; (..._mark_dirty, ..._mark_clean, ..._is_dirty) using SMC, and the #bit to
;; set, reset or test is selected at the end of the big function, again
;; using SMC

;; void jsp_dtt_mark_dirty( uint8_t row, uint8_t col ) __smallc __z88dk_callee;

_jsp_dtt_mark_dirty:
	ld a,0xc6			;; for SET, second byte is 0xc6 + 8*b
	ld (smc_bit_set_res_bit+1),a	;; modify code
	jp jsp_dtt_mark_dirty_clean_test

;; void jsp_dtt_mark_clean( uint8_t row, uint8_t col ) __smallc __z88dk_callee;

_jsp_dtt_mark_clean:
	ld a,0x86			;; for RES, second byte is 0x86 + 8*b
	ld (smc_bit_set_res_bit+1),a	;; modify code
	jp jsp_dtt_mark_dirty_clean_test

;; uint8_t jsp_dtt_is_dirty( uint8_t row, uint8_t col ) __smallc __z88dk_callee;

_jsp_dtt_is_dirty:
	ld a,0x46			;; for BIT, second byte is 0x46 + 8*b
	ld (smc_bit_set_res_bit+1),a	;; modify code
;	jp jsp_dtt_mark_dirty_clean_test

jsp_dtt_mark_dirty_clean_test:

	pop af			;; pop retaddr

	pop de			;; DE = col
	pop hl			;; HL = row
				;; cleaned stack for caller

	push af			;; push back retaddr

	ld h,0			;; ensure no garbage in H
	ld d,h			;; ensure no garbage in D

	add hl,hl		;; HL = row * 32
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,hl

	add hl,de		;; HL += col - cell index (0-767)

	ld a,0x07		;; A = col % 8 -> # bit to set
	and e			;; (save for later)

	srl h			;; divide HL by 8 to get the byte index
	rr l
	srl h
	rr l
	srl h
	rr l

	ld de,_jsp_dtt		;; index into DTT table
	add hl,de		;; HL = byte to modify

	sla a			;; SMC: second byte of set 0,(hl) instruction below
	sla a			;; multiply bit number by 8
	sla a

smc_bit_set_res_bit:
	add a,0			;; SMC: value 0xC6 for RES, 0x86 for SET, 0x46 for BIT

	ld (smc_bit_number+1),a	;; modify code below
	xor a			;; reset flags, Z=1

smc_bit_number:
	set 0,(hl)		;; SMC: the operation (SET/RES/BIT) and bit
				;; number is modified by previous code.  If
				;; it is BIT, the Z flag will show the bit
				;; checked.  If it is SET or RES, the Z flag
				;; is not affected and we always return 0
	jp z,return_0

	ld l,1			;; z88dk expects 8-bit return value in L
	ret

return_0:
	ld l,0			;; z88dk expects 8-bit return value in L
	ret
