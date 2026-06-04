;; CPC jsp_covered_mono — covered-cell compositor for CPC_MODE1_MONO (assembly).
;;
;; Phase 6.1 (doc/CPC-ASSETS-FORMAT.md §3.1).  MONO renders plain 1bpp
;; (Mode-2/SP1 format) assets on a Mode-1 screen; the 1bpp->Mode-1 conversion
;; is done here, in the blitter, per covered cell — nothing is stored expanded.
;;
;; This is a fork of jsp_covered.asm: the row-sweep, clip, z-order loop, BTT
;; seed and screen blit are identical.  The ONLY change is the per-sprite
;; compositing slice.  A 1bpp source byte is 8 px = TWO Mode-1 screen cells; so
;; for a covered screen cell at sprite-relative screen column j = col - c0:
;;
;;   src_col = j >> 1     nibble = j & 1   (0 = source px 7..4, 1 = px 3..0)
;;
;; The slice expands THIS cell's nibble and the LEFT screen cell's nibble (for
;; the shift carry) into two transient Mode-1 scratch cells (mono_this /
;; mono_left), then calls the EXISTING Mode-1 middle kernel (jsp_draw_mask2 /
;; jsp_draw_load1) with (dst=cc_scratch, graph=mono_this, graph_left=mono_left).
;; Because mono_left is always supplied (zeroed at the sprite's left edge, j==0),
;; MONO needs only the middle kernels — no lb/rb variants.  The footprint is
;; 2*cols wide (jsp_frame / jsp_sprite_defer, via JSP_MONO_DBL).
;;
;; Per-nibble expansion (the tools/cpcgfx.pl transform, in asm):
;;   parity 0 (high 4 px):  eg = g & 0xF0          em = (m&0xF0)|((m&0xF0)>>4)
;;   parity 1 (low  4 px):  eg = (g & 0x0F) << 4   em = ((m&0x0F)<<4)|(m&0x0F)
;;
;; struct jsp_sprite_frame layout (16 bytes), offsets used here:
;;   +0 r0  +1 c0  +2 r1  +3 c1  +4 cs  +5 ismask2  +6 rottbl_msb
;;   +7 cols  +8 color  +9 color_mask  +10 base(w)  +12 rowstride(w)  +14 clip(w)

	IFDEF JSP_TARGET_CPC
	IFDEF CPC_MODE1_MONO

	section code_compiler

	INCLUDE "jsp_cpc_geom.inc"	; JSP_GEOM_COLS / COLBYTES / CELLSHIFT

	extern _jsp_frame_count
	extern _jsp_frame_sprites
	extern _jsp_btt
	extern _jsp_current_rottbl_msb
	extern _jsp_draw_load1
	extern _jsp_draw_mask2
	extern jsp_draw_screen_tile_saddr

	public _jsp_redraw_covered_cell
	public _jsp_cc_row_active_row
	public cc_cell
	public cc_row			; (row,col) supplied by jsp_redraw (lazy
	public cc_col			; tracking), so no divide-by-COLS needed here
	public cc_scratch
	public mono_tile_expand		; also used by the MONO bg path in jsp_redraw.asm

;; void jsp_redraw_covered_cell( uint16_t cell ) __z88dk_fastcall;
_jsp_redraw_covered_cell:
	;; (cc_row, cc_col) are set by jsp_redraw before the call, so no
	;; divide-by-COLS here.
	xor a
	ld (cc_covered),a

;; ---- row-sweep: rebuild jsp_cc_row_active[] when the row changes ----
	ld a,(cc_row)
	ld hl,_jsp_cc_row_active_row
	cp (hl)
	jp z,cc_row_ready
	ld (hl),a
	xor a
	ld (cc_row_active_n),a
	ld a,(_jsp_frame_count)
	or a
	jp z,cc_row_ready
	ld b,a
	ld hl,_jsp_frame_sprites
	ld iy,cc_row_active
cc_sweep:
	ld a,(cc_row)
	cp (hl)				; CF if row < r0
	jr c,cc_sweep_skip
	push hl
	inc hl
	inc hl				; HL -> r1
	cp (hl)				; row vs r1: CF if row<r1, Z if ==
	pop hl
	jr c,cc_sweep_hit
	jr nz,cc_sweep_skip		; row > r1
cc_sweep_hit:
	ld (iy+0),l
	ld (iy+1),h
	inc iy
	inc iy
	ld a,(cc_row_active_n)
	inc a
	ld (cc_row_active_n),a
cc_sweep_skip:
	ld de,16
	add hl,de
	djnz cc_sweep
cc_row_ready:

;; ---- composite every row-active sprite that also covers this col ----
	ld a,(cc_row_active_n)
	or a
	jp z,cc_draw
	ld (cc_loop_n),a
	ld hl,cc_row_active
	ld (cc_slot),hl

cc_comp_loop:
	ld hl,(cc_slot)
	ld e,(hl)
	inc hl
	ld d,(hl)			; DE = frame sprite pointer
	inc hl
	ld (cc_slot),hl
	push de
	pop ix				; IX = frame sprite

  IFDEF JSP_CELL_MODEL_PIXEL
	;; pixel: the cell spans Mode-1 byte-cols [B0..B0+COLBYTES-1] (B0 =
	;; cc_col<<CELLSHIFT); the sprite spans M1-byte [c0..c1].  Overlap test.
	ld a,(cc_col)
	REPT JSP_GEOM_CELLSHIFT
	add a,a
	ENDR
	ld (mono_bcol),a		; B0
	cp (ix+3)			; B0 vs c1
	jp z,cc_col_ok
	jp nc,cc_comp_next		; B0 > c1
	ld a,(mono_bcol)
	add a,JSP_GEOM_COLBYTES-1	; B1
	cp (ix+1)			; B1 vs c0
	jp c,cc_comp_next		; B1 < c0
  ELSE
	;; col >= c0 ?  col <= c1 ?
	ld a,(cc_col)
	cp (ix+1)			; CF if col < c0
	jp c,cc_comp_next
	cp (ix+3)			; col vs c1: CF if col<c1, Z if ==
	jp c,cc_col_ok
	jp nz,cc_comp_next		; col > c1
  ENDIF
cc_col_ok:

	;; clip rectangle test (if fs->clip != NULL)
	ld l,(ix+14)
	ld h,(ix+15)
	ld a,h
	or l
	jr z,cc_clip_ok
	call cc_clip_check
	jp nz,cc_comp_next
cc_clip_ok:

	;; seed scratch on the first covering sprite.  MONO tiles are 1bpp too, so
	;; the background is the BTT tile EXPANDED (nibble col&1) into Mode-1 bytes.
	ld a,(cc_covered)
	or a
	jr nz,cc_seeded
	inc a
	ld (cc_covered),a
	ld hl,(cc_cell)
	add hl,hl
	ld de,_jsp_btt
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)			; DE = jsp_btt[cell] 1bpp tile ptr
  IFDEF JSP_CELL_MODEL_PIXEL
	;; pixel: the 8-px cell is 2 Mode-1 byte-columns = the source byte's high
	;; nibble (col 0) + low nibble (col 1); expand both into cc_scratch.
	ld (mono_savetile),de
	ex de,hl			; HL = tile
	xor a				; parity 0 (high 4 px) -> cc_scratch[0..7]
	ld de,cc_scratch
	call mono_tile_expand
	ld hl,(mono_savetile)
	ld a,1				; parity 1 (low 4 px)  -> cc_scratch[8..15]
	ld de,cc_scratch+8
	call mono_tile_expand
  ELSE
	ex de,hl			; HL = tile
	ld a,(cc_col)
	and 1				; parity = col & 1
	ld de,cc_scratch
	call mono_tile_expand		; cc_scratch <- expanded Mode-1 background
  ENDIF
cc_seeded:

;; ==== MONO compositing slice ========================================
	ld a,(ix+6)			; rottbl_msb (Mode-1 table)
	ld (_jsp_current_rottbl_msb),a

	;; i = row - r0  (constant across the cell's Mode-1 byte-columns)
	ld a,(cc_row)
	sub (ix+0)
	ld (cc_i),a

	;; base_i = base + i*cs  (line offset, source column 0)
	ld l,(ix+10)
	ld h,(ix+11)			; HL = base
	ld a,(cc_i)
	or a
	jr z,mono_no_i
	ld b,a
	ld d,0
	ld e,(ix+4)			; DE = cs
mono_i_add:
	add hl,de
	djnz mono_i_add
mono_no_i:
	ld (mono_basei),hl

  IFDEF JSP_CELL_MODEL_PIXEL
	;; pixel: the cell is COLBYTES Mode-1 byte-cols [B0..B0+COLBYTES-1]
	;; (B0 = mono_bcol, set by the outer overlap test).  Composite each byte-col
	;; the sprite (M1-byte span [c0..c1]) covers into scratch slot k*8 — j =
	;; (B0+k)-c0 is the Model-A MONO screen-col index, so mono_slice_body reused.
	xor a
	ld (mono_k),a
mono_kloop:
	ld a,(mono_k)			; dst = cc_scratch + k*8
	add a,a
	add a,a
	add a,a
	ld e,a
	ld d,0
	ld hl,cc_scratch
	add hl,de
	ld (mono_dst),hl
	ld hl,mono_k
	ld a,(mono_bcol)
	add a,(hl)			; bc = B0 + k
	cp (ix+1)			; bc vs c0
	jp c,mono_knext			; bc < c0 -> not covered
	cp (ix+3)			; bc vs c1
	jp z,mono_kin
	jp nc,mono_knext		; bc > c1 -> not covered
mono_kin:
	sub (ix+1)			; cc_j = bc - c0
	ld (cc_j),a
	call mono_slice_body
mono_knext:
	ld hl,mono_k
	inc (hl)
	ld a,(hl)
	cp JSP_GEOM_COLBYTES
	jp c,mono_kloop
	jp cc_comp_next
  ELSE
	ld a,(cc_col)			; j = col - c0
	sub (ix+1)
	ld (cc_j),a
	ld hl,cc_scratch
	ld (mono_dst),hl
	call mono_slice_body
	jp cc_comp_next
  ENDIF

;; ---- mono_slice_body --------------------------------------------------
;; Composite one Mode-1 byte-column: inputs cc_j (screen-col index = bc-c0),
;; cc_i / mono_basei, mono_dst (scratch slot), IX = frame sprite.  Expands the
;; "this" + "left" 1bpp nibbles to Mode-1 and calls the middle kernel.
;; call/ret; the kernels preserve IX.
mono_slice_body:
	;; ---- THIS cell: src_col = j>>1, parity = j&1 ----
	ld a,(cc_j)
	and 1
	ld (mono_par),a			; this parity
	ld a,(cc_j)
	srl a				; A = src_col = j>>1
	cp (ix+7)			; src_col vs cols: CF if src_col < cols
	jr c,mono_this_real
	ld de,mono_this			; src_col >= cols -> transparent spill
	call mono_fill_transparent
	jr mono_this_done
mono_this_real:
	ld hl,(mono_basei)		; HL = base_i + src_col*rowstride
	or a
	jr z,mono_this_noadd
	ld b,a
	ld e,(ix+12)
	ld d,(ix+13)			; DE = rowstride
mono_this_radd:
	add hl,de
	djnz mono_this_radd
mono_this_noadd:
	ld a,(mono_par)
	ld de,mono_this
	call mono_expand_cell
mono_this_done:

	;; ---- LEFT cell (screen col j-1): supplies the shift carry ----
	ld a,(cc_j)
	or a
	jr z,mono_left_zero		; j==0 -> sprite left edge, no carry
	dec a				; jl = j-1
	ld c,a
	and 1
	ld (mono_par),a			; left parity = jl & 1
	ld a,c
	srl a				; A = left src_col = jl>>1 (always < cols)
	ld hl,(mono_basei)
	or a
	jr z,mono_left_noadd
	ld b,a
	ld e,(ix+12)
	ld d,(ix+13)
mono_left_radd:
	add hl,de
	djnz mono_left_radd
mono_left_noadd:
	ld a,(mono_par)
	ld de,mono_left
	call mono_expand_cell
	jr mono_left_done
mono_left_zero:
	ld de,mono_left
	call mono_fill_transparent
mono_left_done:

	;; call the middle kernel: (dst=mono_dst, graph=mono_this, graph_left=mono_left)
	ld de,(mono_dst)
	push de
	ld de,mono_this
	push de
	ld de,mono_left
	push de
	ld a,(ix+5)			; ismask2
	or a
	jr nz,cc_mono_mask
	call _jsp_draw_load1
	ret
cc_mono_mask:
	call _jsp_draw_mask2
	ret

cc_comp_next:
	ld hl,cc_loop_n
	dec (hl)
	jp nz,cc_comp_loop

;; ---- blit the cell at 0xC000 + cell (no attribute on CPC) ----
;; cc_scratch always holds the final 8 Mode-1 bytes: either composited above, or
;; (uncovered) the BTT 1bpp tile expanded here.
cc_draw:
	ld a,(cc_covered)
	or a
	jr nz,cc_do_draw		; composited -> cc_scratch ready
	;; uncovered (all covering sprites clipped out): expand the BTT 1bpp tile
	ld hl,(cc_cell)
	add hl,hl
	ld bc,_jsp_btt
	add hl,bc
	ld e,(hl)
	inc hl
	ld d,(hl)			; DE = jsp_btt[cell] 1bpp tile ptr
  IFDEF JSP_CELL_MODEL_PIXEL
	;; pixel: expand BOTH nibbles into the cell's 2 byte-cols (else col1 is stale)
	ld (mono_savetile),de
	ex de,hl
	xor a
	ld de,cc_scratch
	call mono_tile_expand
	ld hl,(mono_savetile)
	ld a,1
	ld de,cc_scratch+8
	call mono_tile_expand
  ELSE
	ex de,hl			; HL = tile
	ld a,(cc_col)
	and 1
	ld de,cc_scratch
	call mono_tile_expand
  ENDIF
cc_do_draw:
	ld de,cc_scratch		; blit cc_scratch (composited or expanded)
	ld hl,(cc_cell)
	REPT JSP_GEOM_CELLSHIFT
	add hl,hl			; cell << log2(COLBYTES) = screen byte offset
	ENDR
	ld bc,0xC000
	add hl,bc
	call jsp_draw_screen_tile_saddr
	ret

;; ---- mono_expand_cell --------------------------------------------------
;; HL = 1bpp source cell ptr (line 0), DE = dest scratch, A = parity (0/1).
;; Expands 8 lines of the selected nibble to Mode-1 (pen 0/1).  ismask2 from
;; (ix+5): load1 = 8 bytes (graph), mask2 = 16 bytes ((mask,graph) pairs).
;; Preserves IX; trashes A,BC,DE,HL.
mono_expand_cell:
	ld (mono_savepar),a
	ld a,(ix+5)
	or a
	jr nz,mono_exp_mask

	;; --- load1: 8 lines, 1 graph byte each ---
	ld b,8
mono_exp_l1:
	ld a,(mono_savepar)
	or a
	jr nz,mono_exp_l1_lo
	ld a,(hl)			; parity 0: eg = g & 0xF0
	and 0xF0
	jr mono_exp_l1_st
mono_exp_l1_lo:
	ld a,(hl)			; parity 1: eg = (g & 0x0F) << 4
	and 0x0F
	rlca
	rlca
	rlca
	rlca
mono_exp_l1_st:
	ld (de),a
	inc hl
	inc de
	djnz mono_exp_l1
	ret

	;; --- mask2: 8 lines, (mask,graph) pairs ---
mono_exp_mask:
	ld a,(mono_savepar)
	or a
	jr nz,mono_exp_mask_lo

	ld b,8				; parity 0 (high nibble)
mono_exp_m_hi:
	ld a,(hl)			; em = (m&0xF0) | ((m&0xF0)>>4)
	and 0xF0
	ld c,a
	rrca
	rrca
	rrca
	rrca
	or c
	ld (de),a
	inc hl
	inc de
	ld a,(hl)			; eg = g & 0xF0
	and 0xF0
	ld (de),a
	inc hl
	inc de
	djnz mono_exp_m_hi
	ret

mono_exp_mask_lo:
	ld b,8				; parity 1 (low nibble)
mono_exp_m_lo:
	ld a,(hl)			; em = ((m&0x0F)<<4) | (m&0x0F)
	and 0x0F
	ld c,a
	rlca
	rlca
	rlca
	rlca
	or c
	ld (de),a
	inc hl
	inc de
	ld a,(hl)			; eg = (g&0x0F) << 4
	and 0x0F
	rlca
	rlca
	rlca
	rlca
	ld (de),a
	inc hl
	inc de
	djnz mono_exp_m_lo
	ret

;; ---- mono_fill_transparent --------------------------------------------
;; DE = dest scratch.  Fills a fully-transparent Mode-1 cell: load1 = 8x $00,
;; mask2 = 8x ($FF,$00).  ismask2 from (ix+5).  Trashes A,B,DE.
mono_fill_transparent:
	ld a,(ix+5)
	or a
	jr nz,mft_mask
	ld b,8				; load1: 8 zero graph bytes
	xor a
mft_l1:
	ld (de),a
	inc de
	djnz mft_l1
	ret
mft_mask:
	ld b,8				; mask2: 8x (mask=$FF, graph=$00)
mft_m1:
	ld a,0xFF
	ld (de),a
	inc de
	xor a
	ld (de),a
	inc de
	djnz mft_m1
	ret

;; ---- mono_tile_expand --------------------------------------------------
;; Expand a 1bpp (Mode-2 format) 8-byte tile to 8 Mode-1 bytes (pen 0/1).
;; HL = 1bpp tile ptr, A = parity (0 = high 4 px / even col, 1 = low 4 px),
;; DE = dest (8 bytes).  Graph-only (tiles have no mask).  A 1bpp 8-px tile
;; spans two Mode-1 cells; the caller picks the half with col&1, so a uniform
;; fill tiles the 8-px pattern seamlessly.  Trashes A,B,DE,HL; preserves IX.
mono_tile_expand:
	or a
	jr nz,mte_lo
	ld b,8				; parity 0: eg = g & 0xF0
mte_hi:
	ld a,(hl)
	and 0xF0
	ld (de),a
	inc hl
	inc de
	djnz mte_hi
	ret
mte_lo:
	ld b,8				; parity 1: eg = (g & 0x0F) << 4
mte_l:
	ld a,(hl)
	and 0x0F
	rlca
	rlca
	rlca
	rlca
	ld (de),a
	inc hl
	inc de
	djnz mte_l
	ret

;; ---- cc_clip_check ----------------------------------------------------
;; HL = struct jsp_rect* (row,col,width,height).  Z if (cc_row,cc_col) inside.
cc_clip_check:
	ld a,(cc_col)
	inc hl
	cp (hl)
	jr c,cc_clip_out
	ld a,(hl)
	inc hl
	add a,(hl)
	ld d,a
	ld a,(cc_col)
	cp d
	jr nc,cc_clip_out
	dec hl
	dec hl
	ld a,(cc_row)
	cp (hl)
	jr c,cc_clip_out
	ld a,(hl)
	inc hl
	inc hl
	inc hl
	add a,(hl)
	ld d,a
	ld a,(cc_row)
	cp d
	jr nc,cc_clip_out
	xor a
	ret
cc_clip_out:
	or 1
	ret

	section data_compiler
cc_row:			db 0
cc_col:			db 0
cc_cell:		dw 0
cc_covered:		db 0
cc_i:			db 0
cc_j:			db 0
cc_loop_n:		db 0
cc_slot:		dw 0
cc_row_active_n:	db 0
cc_scratch:		ds JSP_GEOM_COLBYTES*8	; 8 (byte/M2) or 16 (pixel M1)

mono_basei:		dw 0
mono_bcol:		db 0		; pixel: B0 = first M1 byte-col of the cell
mono_k:			db 0		; pixel: byte-col loop index 0..COLBYTES-1
mono_dst:		dw 0		; kernel dst slot (cc_scratch[+k*8] in pixel)
mono_savetile:		dw 0		; pixel: BTT tile ptr saved across the 2-nibble seed
mono_par:		db 0
mono_savepar:		db 0
mono_this:		ds 16		; expanded Mode-1 "this" cell (cs<=16)
mono_left:		ds 16		; expanded Mode-1 "left" cell (carry source)

;; Reset to 0xFF by jsp_redraw_begin() so the first covered cell rebuilds the set.
_jsp_cc_row_active_row:	db 0xFF
cc_row_active:		ds 32

	ENDIF			; CPC_MODE1_MONO
	ENDIF			; JSP_TARGET_CPC
