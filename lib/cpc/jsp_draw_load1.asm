
; DRAW LOAD SPRITE 1 BYTE DEFINITION ROTATED
; 01.2006 aralbrec, Sprite Pack v3.0
; sinclair spectrum version
; 12.2024 adapted by zxjogv (zx@jogv.es) for JSP

	IFDEF JSP_TARGET_CPC		; CPC shift kernel (shared by all CPC shifting modes) - port of lib/zx/jsp_draw_load1.asm. Table-driven via jsp_rottbl, so the pixel encoding lives in the table, not here: identical for M2 (1bpp linear) and M1 (nibble-plane). plan section 5
	IF CPC_MODE0_FAST || CPC_MODE1_FAST || CPC_MODE2_FAST
	; FAST (byte-aligned) build: this rotating kernel is unused — the
	; covered-cell compositor calls the no-rotate kernel directly, so no
	; shift kernel (or its redirect prologue) is linked into a FAST binary.
	ELSE

	section code_compiler

	INCLUDE "jsp_cpc_geom.inc"	; JSP_GEOM_COLBYTES
	INCLUDE "jsp_cc_store.inc"	; CC_WR — absolute (Model A/M2) or (iy+n) (Model B)

	public _JSP_DRAW_LOAD1
	public _jsp_draw_load1

	extern _JSP_DRAW_LOAD1NR
	extern _jsp_current_rottbl_msb
	extern _jsp_rottbl
	extern cc_scratch		; Model A / M2: dst is the fixed 8-byte buffer,
					; written absolutely (13T).  Model B M1/M0: dst is
					; a per-byte-column slot passed in BC -> IY (19T).

; void jsp_draw_load1( uint8_t *dst, uint8_t *graph, uint8_t *graph_left ) __smallc __z88dk_callee;
; Trashes DE'!
_jsp_draw_load1:
	exx
	pop de		; save ret addr
	exx

	ld a,(_jsp_current_rottbl_msb)		; a = hor rot table

	pop de		; de = left graphic def ptr
	pop hl		; hl = graphic def ptr
	pop bc		; bc = graphic disp

	exx
	push de		;; restore ret addr
	exx

;  a = hor rot table
; bc = graphic disp
; hl = graphic def ptr
; ix = left graphic def ptr

_JSP_DRAW_LOAD1:

	cp _jsp_rottbl/256 - 2
	jp z, _JSP_DRAW_LOAD1NR

	push ix	; save

	push de
	pop ix

	ex de,hl

	ld h,a

	;  h = shift table
	; de = sprite def (graph only)
	; ix = left sprite def
	; dst = cc_scratch (Model A/M2) or BC->IY per-column slot (Model B)
	IF JSP_GEOM_COLBYTES > 1
	push bc				; BC = dst (popped above) -> IY for (iy+n) writes
	pop iy
	ENDIF

_JSPLoad1Rotate:

	; 0

	ld a,(de)
	inc de
	ld l,a
	ld a,(hl)
	inc h
	ld l,(ix+0)
	or (hl)
	CC_WR 0
	ld l,(ix+1)
	ld b,(hl)
	dec h
	ld a,(de)
	inc de
	ld l,a
	ld a,b
	or (hl)
	CC_WR 1

	; 1

	ld a,(de)
	inc de
	ld l,a
	ld a,(hl)
	inc h
	ld l,(ix+2)
	or (hl)
	CC_WR 2
	ld l,(ix+3)
	ld b,(hl)
	dec h
	ld a,(de)
	inc de
	ld l,a
	ld a,b
	or (hl)
	CC_WR 3

	; 2

	ld a,(de)
	inc de
	ld l,a
	ld a,(hl)
	inc h
	ld l,(ix+4)
	or (hl)
	CC_WR 4
	ld l,(ix+5)
	ld b,(hl)
	dec h
	ld a,(de)
	inc de
	ld l,a
	ld a,b
	or (hl)
	CC_WR 5

	; 3

	ld a,(de)
	inc de
	ld l,a
	ld a,(hl)
	inc h
	ld l,(ix+6)
	or (hl)
	CC_WR 6
	ld l,(ix+7)
	ld b,(hl)
	dec h
	ld a,(de)
	ld l,a
	ld a,b
	or (hl)
	CC_WR 7

	pop ix	; restore
	ret

	ENDIF			; CPC_MODE*_FAST (rotating kernel skipped)
	ENDIF			; JSP_TARGET_CPC
