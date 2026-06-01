;; CPC jsp_redraw — DTT-walk recompositing for the CPC Mode-2 screen.
;; doc/CPC-TARGET-PLAN.md §7. Background path only in Phase 2 (no sprite
;; compositing yet — that is Phase 3, via jsp_redraw_covered_cell).
;;
;; Walks the 250 DTT groups (2000 cells / 8). For each dirty cell:
;;   - foreground, or no active sprite (frame_count == 0): blit the BTT tile
;;     straight to the screen. A CPC Mode-2 cell's line-0 address is just
;;     0xC000 + cell (cell = row*80+col), and the 8 lines step +0x800 — so no
;;     row/col decomposition and no rd_rowtab are needed. No attribute store.
;;   - covered by a sprite: jsp_redraw_covered_cell (Phase 3).
;; Then the DTT is cleared.

	IFDEF JSP_TARGET_CPC

	section code_compiler

	extern _jsp_redraw_begin
	extern _jsp_frame_count
	extern _jsp_dtt
	extern _jsp_ftt
	extern _jsp_btt
	extern _jsp_redraw_covered_cell
	extern cc_cell
	extern jsp_draw_screen_tile_saddr

	IFDEF CPC_MODE1_MONO			; MONO tiles are 1bpp -> expand at blit
	extern cc_scratch
	extern mono_tile_expand
	ENDIF

	public _jsp_redraw

; void jsp_redraw( void );
_jsp_redraw:
	push ix				; jsp_redraw_covered_cell clobbers IX
	call _jsp_redraw_begin		; fill frame data, set _jsp_frame_count

	xor a
	ld (rd_g),a			; g = 0

;; ---- per-group loop: 250 groups of 8 cells ----
rd_group:
	ld a,(rd_g)
	ld e,a
	ld d,0				; DE = g
	ld hl,_jsp_dtt
	add hl,de
	ld a,(hl)			; A = jsp_dtt[g]
	or a
	jp z,rd_group_next		; clean group: skip

	ld c,a				; C = dtt (rrc per bit -> CY = dirty)
	ld hl,_jsp_ftt
	add hl,de
	ld a,(hl)
	ld d,a				; D = ftt (rrc per bit -> CY = foreground)

	;; cellbase = g << 3  (HL = cell index, inc per bit)
	ld a,(rd_g)
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl			; HL = g*8 = first cell of the group

	ld b,8				; B = bit counter

;; ---- per-bit loop: 8 cells in the group (state in MAIN: B,C,D,HL) ----
rd_bit_loop:
	rrc d				; CY = ftt bit
	sbc a,a				; A = 0xFF if foreground else 0x00
	rrc c				; CY = dtt bit (dirty?)
	jp c,rd_dirty

rd_advance:
	inc hl				; cell++
	djnz rd_bit_loop
	;; fall through

rd_group_next:
	ld a,(rd_g)
	inc a
	ld (rd_g),a
	cp 250
	jp c,rd_group

	;; clear the DTT (250 bytes) for the next frame
	ld hl,_jsp_dtt
	ld d,h
	ld e,l
	inc de
	ld (hl),0
	ld bc,249
	ldir
	pop ix
	ret

;; ---- dirty cell (HL = cell, A = 0xFF if foreground) ----
rd_dirty:
	or a				; foreground?
	jp nz,rd_bg_cell		; yes -> background path (sprites pass behind)

	ld a,(_jsp_frame_count)
	or a
	jp z,rd_bg_cell			; no active sprite -> background path

	;; covered by a sprite (Phase 3). Spill loop state, composite, reload.
	ld (rd_cell),hl
	ld (cc_cell),hl
	ld a,c
	ld (rd_dtt),a
	ld a,d
	ld (rd_ftt),a
	ld a,b
	ld (rd_bitc),a
	call _jsp_redraw_covered_cell	; HL still = cell (__z88dk_fastcall)
	ld a,(rd_bitc)
	ld b,a
	ld a,(rd_dtt)
	ld c,a
	ld a,(rd_ftt)
	ld d,a
	ld hl,(rd_cell)
	jp rd_advance

;; ---- background cell: blit BTT tile at 0xC000 + cell (no attribute) ----
rd_bg_cell:				; HL = cell ; preserve B,C,D across the blit
	ld (rd_cell),hl
	push bc				; save B (bit ctr) + C (dtt)
	push de				; save D (ftt) + E

	ld hl,(rd_cell)
	add hl,hl			; cell * 2
	ld de,_jsp_btt
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)			; DE = jsp_btt[cell] tile pointer

	IFDEF CPC_MODE1_MONO
	;; MONO: the BTT tile is 1bpp -> expand nibble(col&1) into cc_scratch and
	;; blit that.  cell & 1 == col & 1 (cell = row*80 + col, row*80 even).
	ex de,hl			; HL = 1bpp tile ptr
	ld a,(rd_cell)			; low byte of cell index
	and 1				; parity = col & 1
	ld de,cc_scratch
	call mono_tile_expand		; cc_scratch <- 8 Mode-1 bytes
	ld de,cc_scratch
	ENDIF

	ld hl,(rd_cell)
	ld bc,0xC000
	add hl,bc			; HL = cell line-0 screen address
	call jsp_draw_screen_tile_saddr	; blit DE -> screen (trashes A,B,D,HL)

	pop de				; restore D (ftt) + E
	pop bc				; restore B (bit ctr) + C (dtt)
	ld hl,(rd_cell)
	jp rd_advance

	section data_compiler
rd_g:		db 0
rd_cell:	dw 0
rd_dtt:		db 0
rd_ftt:		db 0
rd_bitc:	db 0

	ENDIF			; JSP_TARGET_CPC
