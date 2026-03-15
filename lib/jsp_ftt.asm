	section code_compiler

	extern _jsp_ftt
	extern jsp_rowcolindex
	extern jsp_rowcolindex_dtt

	public _jsp_ftt_mark_fg
	public _jsp_ftt_mark_bg
	public _jsp_ftt_is_fg

;; FTT bit manipulation: mirrors jsp_dtt.asm for the Foreground Tiles Table.
;; Same SMC technique: entry point selects SET/RES/BIT, bit number is computed
;; from col and patched in at runtime.

;; void jsp_ftt_mark_fg( uint8_t row, uint8_t col ) __smallc __z88dk_callee;

_jsp_ftt_mark_fg:
	ld a,0xc6			;; for SET, second byte is 0xc6 + 8*b
	ld (ftt_smc_bit_set_res_bit+1),a
	jp jsp_ftt_mark_fg_bg_test

;; void jsp_ftt_mark_bg( uint8_t row, uint8_t col ) __smallc __z88dk_callee;

_jsp_ftt_mark_bg:
	ld a,0x86			;; for RES, second byte is 0x86 + 8*b
	ld (ftt_smc_bit_set_res_bit+1),a
	jp jsp_ftt_mark_fg_bg_test

;; uint8_t jsp_ftt_is_fg( uint8_t row, uint8_t col ) __smallc __z88dk_callee;

_jsp_ftt_is_fg:
	ld a,0x46			;; for BIT, second byte is 0x46 + 8*b
	ld (ftt_smc_bit_set_res_bit+1),a
;	jp jsp_ftt_mark_fg_bg_test

jsp_ftt_mark_fg_bg_test:

	pop af			;; pop retaddr

	pop de			;; DE = col
	pop hl			;; HL = row
				;; cleaned stack for caller

	push af			;; push back retaddr

	ld d,l			;; D = row, E = col
	push de			;; save DE
	call jsp_rowcolindex_dtt	;; L = offset (0-95) - H is already 0
	pop de			;; restore

	ld a,0x07		;; A = col % 8 -> # bit to set
	and e			;; (save for later)

	ld de,_jsp_ftt		;; index into FTT table
	add hl,de		;; HL = byte to modify

	sla a			;; SMC: second byte of set 0,(hl) instruction below
	sla a			;; multiply bit number by 8
	sla a

ftt_smc_bit_set_res_bit:
	add a,0			;; SMC: value 0xC6 for SET, 0x86 for RES, 0x46 for BIT

	ld (ftt_smc_bit_number+1),a	;; modify code below
	xor a			;; reset flags, Z=1

ftt_smc_bit_number:
	set 0,(hl)		;; SMC: operation (SET/RES/BIT) and bit number patched above
	jp z,ftt_return_0

	ld l,1			;; z88dk expects 8-bit return value in L
	ret

ftt_return_0:
	ld l,0
	ret
