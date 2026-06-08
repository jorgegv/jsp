;; CPC jsp_covered — covered-cell compositor (assembly).
;;
;; Phase 3 (doc/CPC-TARGET-PLAN.md §5/§6/§7): CPC Mode-2 port of lib/zx/
;; jsp_covered.asm.  Called by the CPC jsp_redraw for every cell flagged
;; sprite-covered:
;;
;;   - seed an 8-byte scratch with the BTT background tile
;;   - composite every covering frame sprite in z-order (row-sweep set +
;;     column test, identical to ZX), calling the CPC jsp_draw_* kernels
;;     (verbatim 1bpp Mode-2 ports; they composite into cc_scratch)
;;   - blit the result with one store at 0xC000 + cell (Model A: cell == byte
;;     offset, 8 lines step +0x800)
;;
;; Divergences from ZX (§6): the CPC has NO attribute RAM, so there is no
;; jsp_bat read, no per-sprite colour merge, and no 0x5800 attribute store —
;; colour lives in the pixels.  Also, the CPC redraw walks a running cell
;; counter (not row/col), so this routine DERIVES (row,col) from cc_cell by
;; dividing by 80 (cell = row*80 + col); the redraw therefore needs no change.
;;
;; struct jsp_sprite_frame layout (16 bytes), offsets used here:
;;   +0 r0  +1 c0  +2 r1  +3 c1  +4 cs  +5 ismask2  +6 rottbl_msb
;;   +7 cols  +8 color  +9 color_mask  +10 base(w)  +12 rowstride(w)
;;   +14 clip(w)
;; struct jsp_rect: +0 row  +1 col  +2 width  +3 height

	IFDEF JSP_TARGET_CPC
	IFNDEF CPC_MODE1_MONO		; MONO uses lib/cpc/jsp_covered_mono.asm instead

	section code_compiler

	INCLUDE "jsp_cpc_geom.inc"	; JSP_GEOM_COLS / COLBYTES / CELLSHIFT

	extern _jsp_frame_count
	extern _jsp_frame_sprites
	extern _jsp_btt
	extern _jsp_current_rottbl_msb
	IF CPC_MODE0_FAST || CPC_MODE1_FAST || CPC_MODE2_FAST
	; FAST (byte-aligned): only the no-rotate kernels exist; the rotating
	; kernels are not assembled (see lib/cpc/jsp_draw_*.asm).
	extern _jsp_draw_load1nr
	extern _jsp_draw_mask2nr
	ELSE
	extern _jsp_draw_load1
	extern _jsp_draw_load1lb
	extern _jsp_draw_load1rb
	; The transparent kernel family is MASK2 normally, or IMASK (graph-only,
	; LUT-derived mask) in _IMASK builds — same signatures, so only the call
	; target below changes (CALL_MASK_* macros).
	IF CPC_MODE0_IMASK || CPC_MODE1_IMASK
	extern _jsp_draw_imask
	extern _jsp_draw_imasklb
	extern _jsp_draw_imaskrb
	ELSE
	extern _jsp_draw_mask2
	extern _jsp_draw_mask2lb
	extern _jsp_draw_mask2rb
	ENDIF
	ENDIF

	; Transparent-kernel call macros: IMASK in _IMASK builds, MASK2 otherwise.
	MACRO CALL_MASK_MID
	IF CPC_MODE0_IMASK || CPC_MODE1_IMASK
	call _jsp_draw_imask
	ELSE
	call _jsp_draw_mask2
	ENDIF
	ENDM
	MACRO CALL_MASK_LB
	IF CPC_MODE0_IMASK || CPC_MODE1_IMASK
	call _jsp_draw_imasklb
	ELSE
	call _jsp_draw_mask2lb
	ENDIF
	ENDM
	MACRO CALL_MASK_RB
	IF CPC_MODE0_IMASK || CPC_MODE1_IMASK
	call _jsp_draw_imaskrb
	ELSE
	call _jsp_draw_mask2rb
	ENDIF
	ENDM
	extern jsp_draw_screen_tile_saddr

	public _jsp_redraw_covered_cell
	public _jsp_cc_row_active_row
	public cc_cell			; cell-index input, written by jsp_redraw
	public cc_row			; (row,col) also supplied by jsp_redraw (lazy
	public cc_col			; tracking), so no divide-by-COLS needed here
	public cc_scratch		; compositing buffer; the jsp_draw_* kernels
					; address it absolutely (see those files)

;; void jsp_redraw_covered_cell( uint16_t cell ) __z88dk_fastcall;
;; The caller (jsp_redraw) stores the cell index (row*80 + col) in cc_cell
;; before the call.  We derive (row,col) from it here.  (Internal helper —
;; only jsp_redraw calls it.)
_jsp_redraw_covered_cell:
	;; (cc_row, cc_col) are set by jsp_redraw before the call (it tracks the
	;; row lazily across its monotonic cell walk), so no divide-by-COLS here.
	xor a
	ld (cc_covered),a

;; ---- row-sweep: rebuild jsp_cc_row_active[] when the row changes ----
	ld a,(cc_row)
	ld hl,_jsp_cc_row_active_row
	cp (hl)
	jp z,cc_row_ready
	ld (hl),a			; row_active_row = row
	xor a
	ld (cc_row_active_n),a
	ld a,(_jsp_frame_count)
	or a
	jp z,cc_row_ready
	ld b,a				; B = frame sprite count
	ld hl,_jsp_frame_sprites
	ld iy,cc_row_active		; IY = write pointer
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
	ld de,16			; sizeof(struct jsp_sprite_frame)
	add hl,de
	djnz cc_sweep
cc_row_ready:

;; ---- composite every row-active sprite that also covers this col ----
	ld a,(cc_row_active_n)
	or a
	jp z,cc_draw			; nothing -> draw background
	ld (cc_loop_n),a
	ld hl,cc_row_active
	ld (cc_slot),hl

cc_comp_loop:
	ld hl,(cc_slot)
	ld e,(hl)
	inc hl
	ld d,(hl)			; DE = frame sprite pointer
	inc hl
	ld (cc_slot),hl			; advance to next slot
	push de
	pop ix				; IX = frame sprite

	IFDEF JSP_CELL_MODEL_PIXEL
;; ============================================================
;; Model B (pixel-cell): the cell spans COLBYTES screen byte-columns
;; [B0 .. B0+COLBYTES-1], B0 = cc_col << CELLSHIFT.  The sprite covers screen
;; byte-columns [c0..c1] (c0/c1 are BYTE columns from jsp_frame, unchanged).
;; For every cell byte-column the sprite covers, composite source byte-column
;; (bc-c0) into wide-scratch slot (bc-B0)*8, reusing the Model-A graph math.
;; ============================================================
	ld a,(cc_col)			; B0 = cc_col << CELLSHIFT
	REPT JSP_GEOM_CELLSHIFT
	add a,a
	ENDR
	ld (cc_bcol),a

	;; overlap: B0 <= c1 AND B0+COLBYTES-1 >= c0
	cp (ix+3)			; B0 vs c1
	jp z,cb_ovl1
	jp nc,cc_comp_next		; B0 > c1 -> no overlap
cb_ovl1:
	ld a,(cc_bcol)
	add a,JSP_GEOM_COLBYTES-1	; B1
	cp (ix+1)			; B1 vs c0
	jp c,cc_comp_next		; B1 < c0 -> no overlap

	;; clip rectangle test (cell coords; only if fs->clip != NULL)
	ld l,(ix+14)
	ld h,(ix+15)
	ld a,h
	or l
	jr z,cb_clip_ok
	call cc_clip_check
	jp nz,cc_comp_next
cb_clip_ok:

	;; seed the WHOLE cell scratch (COLBYTES*8) from the BTT tile, 1st sprite
	ld a,(cc_covered)
	or a
	jr nz,cb_seeded
	inc a
	ld (cc_covered),a
	ld hl,(cc_cell)
	add hl,hl
	ld de,_jsp_btt
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)			; DE = BTT tile pointer
	ld hl,cc_scratch
	ex de,hl			; HL = src, DE = dst
	REPT JSP_GEOM_COLBYTES*8
	ldi
	ENDR
cb_seeded:

	ld a,(ix+6)			; rottbl_msb (same for all byte-columns)
	ld (_jsp_current_rottbl_msb),a
	ld a,(cc_row)			; i = row - r0
	sub (ix+0)
	ld (cc_i),a

	;; base_i = base + i*cs — constant across the cell's byte-columns, so hoist
	;; it out of cb_kloop (only pdc*rowstride varies per column).
	ld l,(ix+10)
	ld h,(ix+11)			; HL = base
	or a				; A = i
	jr z,cb_basei_done
	ld b,a
	ld d,0
	ld e,(ix+4)			; DE = cs
cb_basei_add:
	add hl,de
	djnz cb_basei_add
cb_basei_done:
	ld (cc_basei),hl

	xor a				; k = 0
	ld (cc_k),a
cb_kloop:
	ld hl,cc_k
	ld a,(cc_bcol)
	add a,(hl)			; A = bc = B0 + k
	ld (cc_bc),a
	cp (ix+1)			; bc vs c0
	jp c,cb_knext			; bc < c0 -> column not covered
	cp (ix+3)			; bc vs c1
	jp z,cb_kin
	jp nc,cb_knext			; bc > c1 -> not covered
cb_kin:
	ld a,(cc_bc)			; j = bc - c0
	sub (ix+1)
	ld (cc_j),a
	;; pdc = (j==0)?0 : (j>=cols)? cols-1 : j
	or a
	jr z,cb_pdc_done
	cp (ix+7)
	jr c,cb_pdc_done
	ld a,(ix+7)
	dec a
cb_pdc_done:
	;; graph = base_i + pdc*rowstride   (base_i = base + i*cs, hoisted above)
	ld hl,(cc_basei)
	ld e,(ix+12)
	ld d,(ix+13)			; rowstride
	or a				; A = pdc
	jr z,cb_no_pdc
	ld b,a
cb_pdc_add:
	add hl,de
	djnz cb_pdc_add
cb_no_pdc:
	ld (cc_graph),hl

	;; dst = cc_scratch + k*8
	ld a,(cc_k)
	add a,a
	add a,a
	add a,a
	ld e,a
	ld d,0
	ld hl,cc_scratch
	add hl,de
	ld (cc_dst),hl

	IF CPC_MODE0_FAST || CPC_MODE1_FAST || CPC_MODE2_FAST
	;; FAST: no rotation/border/graph_left
	ld de,(cc_dst)
	push de
	ld de,(cc_graph)
	push de
	ld a,(ix+5)			; ismask2
	or a
	jr nz,cb_fast_mask
	call _jsp_draw_load1nr
	jp cb_knext
cb_fast_mask:
	call _jsp_draw_mask2nr
	jp cb_knext
	ELSE
	;; dispatch: j==0 left border, j>=cols right border, else middle
	ld a,(cc_j)
	or a
	jp z,cb_lb
	cp (ix+7)
	jp nc,cb_rb
	;; middle: graph_left = graph - rowstride
	ld hl,(cc_graph)
	ld e,(ix+12)
	ld d,(ix+13)
	or a
	sbc hl,de
	ld de,(cc_dst)
	push de
	ld de,(cc_graph)
	push de
	push hl				; graph_left
	ld a,(ix+5)
	or a
	jr nz,cb_mid_mask
	call _jsp_draw_load1
	jp cb_knext
cb_mid_mask:
	CALL_MASK_MID
	jp cb_knext
cb_lb:
	ld de,(cc_dst)
	push de
	ld de,(cc_graph)
	push de
	ld a,(ix+5)
	or a
	jr nz,cb_lb_mask
	call _jsp_draw_load1lb
	jp cb_knext
cb_lb_mask:
	CALL_MASK_LB
	jp cb_knext
cb_rb:
	ld de,(cc_dst)
	push de
	ld de,(cc_graph)
	push de
	ld a,(ix+5)
	or a
	jr nz,cb_rb_mask
	call _jsp_draw_load1rb
	jp cb_knext
cb_rb_mask:
	CALL_MASK_RB
	ENDIF			; CPC_MODE*_FAST

cb_knext:
	ld hl,cc_k
	inc (hl)
	ld a,(hl)
	cp JSP_GEOM_COLBYTES
	jp c,cb_kloop
	jp cc_comp_next

	ELSE
	;; ===== Model A (byte-cell): one source column per cell =====
	;; col >= c0 ?  col <= c1 ?
	ld a,(cc_col)
	cp (ix+1)			; CF if col < c0
	jp c,cc_comp_next
	cp (ix+3)			; col vs c1: CF if col<c1, Z if ==
	jp c,cc_col_ok
	jp nz,cc_comp_next		; col > c1
cc_col_ok:

	;; clip rectangle test (if fs->clip != NULL)
	ld l,(ix+14)
	ld h,(ix+15)			; HL = clip pointer
	ld a,h
	or l
	jr z,cc_clip_ok
	call cc_clip_check		; Z = inside, NZ = outside
	jp nz,cc_comp_next
cc_clip_ok:

	;; seed scratch with the BTT tile on the first covering sprite
	ld a,(cc_covered)
	or a
	jr nz,cc_seeded
	inc a
	ld (cc_covered),a
	ld hl,(cc_cell)
	add hl,hl			; cell * 2
	ld de,_jsp_btt
	add hl,de
	ld e,(hl)
	inc hl
	ld d,(hl)			; DE = jsp_btt[cell] tile pointer
	ld hl,cc_scratch
	ex de,hl			; HL = src, DE = dst
	;; 8-byte contiguous copy: 8x LDI (128 T) beats LDIR (163 T)
	ldi
	ldi
	ldi
	ldi
	ldi
	ldi
	ldi
	ldi
cc_seeded:

	;; --- composite this frame sprite's slice into cc_scratch ---
	ld a,(ix+6)			; rottbl_msb
	ld (_jsp_current_rottbl_msb),a

	;; i = row - r0 ; j = col - c0
	ld a,(cc_row)
	sub (ix+0)
	ld (cc_i),a
	ld a,(cc_col)
	sub (ix+1)
	ld (cc_j),a

	;; pdc = (j==0) ? 0 : (j>=cols) ? cols-1 : j
	or a				; A = j
	jr z,cc_pdc_done		; j==0 -> pdc 0
	cp (ix+7)			; j vs cols: CF if j<cols
	jr c,cc_pdc_done		; pdc = j
	ld a,(ix+7)
	dec a				; pdc = cols-1
cc_pdc_done:
	;; pdc is now in A; the ld r,(ix+d) below do not touch A, so it
	;; stays live straight into the rowstride-add count.

	;; graph = base + pdc*rowstride + i*cs  (repeated addition)
	ld l,(ix+10)
	ld h,(ix+11)			; HL = base
	ld e,(ix+12)
	ld d,(ix+13)			; DE = rowstride
	or a				; A = pdc
	jr z,cc_no_pdc
	ld b,a
cc_pdc_add:
	add hl,de
	djnz cc_pdc_add
cc_no_pdc:
	ld a,(cc_i)
	or a
	jr z,cc_no_i
	ld b,a
	ld d,0
	ld e,(ix+4)			; DE = cs
cc_i_add:
	add hl,de
	djnz cc_i_add
cc_no_i:
	ld (cc_graph),hl

	IF CPC_MODE0_FAST || CPC_MODE1_FAST || CPC_MODE2_FAST

;; ---- FAST (byte-aligned): straight no-rotate copy of this column ----
;; xrot is forced to 0, so every covering cell maps to exactly one source
;; column — there is no sub-byte shift, no left/right border and no
;; graph_left.  Call the no-rotate kernel with (dst, graph); no rotating
;; kernel (or its rottbl redirect) is linked into a FAST binary.
	ld de,cc_scratch
	push de				; dst
	ld de,(cc_graph)
	push de				; graph
	ld a,(ix+5)			; ismask2
	or a
	jr nz,cc_fast_mask
	call _jsp_draw_load1nr
	jr cc_comp_next
cc_fast_mask:
	call _jsp_draw_mask2nr
	jr cc_comp_next

	ELSE

	;; dispatch: j==0 left border, j>=cols right border, else middle
	ld a,(cc_j)
	or a
	jp z,cc_draw_lb
	cp (ix+7)			; j vs cols
	jp nc,cc_draw_rb		; j >= cols

;; ---- middle column: graph_left = graph - rowstride ----
	ld hl,(cc_graph)
	ld e,(ix+12)
	ld d,(ix+13)
	or a				; clear carry
	sbc hl,de			; HL = graph_left
	;; push args (__smallc: dst, graph, graph_left)
	ld de,cc_scratch
	push de
	ld de,(cc_graph)
	push de
	push hl				; graph_left
	ld a,(ix+5)			; ismask2
	or a
	jr nz,cc_mid_mask
	call _jsp_draw_load1
	jr cc_comp_next
cc_mid_mask:
	CALL_MASK_MID
	jr cc_comp_next

;; ---- left border ----
cc_draw_lb:
	ld de,cc_scratch
	push de
	ld de,(cc_graph)
	push de
	ld a,(ix+5)
	or a
	jr nz,cc_lb_mask
	call _jsp_draw_load1lb
	jr cc_comp_next
cc_lb_mask:
	CALL_MASK_LB
	jr cc_comp_next

;; ---- right border ----
cc_draw_rb:
	ld de,cc_scratch
	push de
	ld de,(cc_graph)
	push de
	ld a,(ix+5)
	or a
	jr nz,cc_rb_mask
	call _jsp_draw_load1rb
	jr cc_comp_next
cc_rb_mask:
	CALL_MASK_RB

	ENDIF			; CPC_MODE*_FAST
	ENDIF			; JSP_CELL_MODEL_PIXEL (Model A vs Model B core)

;; SEAM (CPC, §6): no sprite colour merge — colour is baked into the pixels.

cc_comp_next:
	ld hl,cc_loop_n
	dec (hl)
	jp nz,cc_comp_loop

;; ---- blit the cell at 0xC000 + cell (no attribute on CPC) ----
cc_draw:
	ld a,(cc_covered)
	or a
	ld de,cc_scratch
	jr nz,cc_do_draw		; composited -> draw scratch
	;; uncovered (every covering sprite clipped out): draw BTT tile
	ld hl,(cc_cell)
	add hl,hl
	ld bc,_jsp_btt
	add hl,bc
	ld e,(hl)
	inc hl
	ld d,(hl)			; DE = jsp_btt[cell] tile pointer
cc_do_draw:
	;; jsp_draw_screen_tile_saddr: HL = line-0 screen addr, DE = src
	;; (JSP_CELL_BYTES, column-major).  Screen offset = cell << CELLSHIFT
	;; (CELLSHIFT = 0 Model A -> 0xC000 + cell; 1/2 for Model B M1/M0).
	ld hl,(cc_cell)
	REPT JSP_GEOM_CELLSHIFT
	add hl,hl
	ENDR
	ld bc,0xC000
	add hl,bc			; HL = cell line-0 screen address
	call jsp_draw_screen_tile_saddr
	ret

;; ---- cc_clip_check ------------------------------------------------
;; HL = struct jsp_rect* (row,col,width,height).  Returns Z if cell
;; (cc_row,cc_col) is inside the rectangle, NZ otherwise.
;; Trashes A,DE,HL.
cc_clip_check:
	ld a,(cc_col)
	inc hl				; HL -> rect->col
	cp (hl)				; CF if col < rect->col
	jr c,cc_clip_out
	ld a,(hl)			; rect->col
	inc hl				; HL -> rect->width
	add a,(hl)			; A = rect->col + width
	ld d,a
	ld a,(cc_col)
	cp d				; CF if col < col+width (inside)
	jr nc,cc_clip_out
	dec hl
	dec hl				; HL -> rect->row
	ld a,(cc_row)
	cp (hl)				; CF if row < rect->row
	jr c,cc_clip_out
	ld a,(hl)			; rect->row
	inc hl
	inc hl
	inc hl				; HL -> rect->height
	add a,(hl)			; A = rect->row + height
	ld d,a
	ld a,(cc_row)
	cp d				; CF if row < row+height (inside)
	jr nc,cc_clip_out
	xor a				; Z = inside
	ret
cc_clip_out:
	or 1				; NZ = outside
	ret

	section data_compiler
cc_row:			db 0
cc_col:			db 0
cc_cell:		dw 0
cc_covered:		db 0
cc_i:			db 0
cc_j:			db 0
cc_graph:		dw 0
cc_basei:		dw 0		; base + i*cs, hoisted out of the byte-column loop
cc_loop_n:		db 0
cc_slot:		dw 0
cc_row_active_n:	db 0
;; Model-B per-byte-column compositing scratch (unused in Model A, harmless):
cc_bcol:		db 0		; B0 = first screen byte-column of the cell
cc_k:			db 0		; byte-column loop index 0..COLBYTES-1
cc_bc:			db 0		; current byte-column = B0 + k
cc_dst:			dw 0		; cc_scratch + k*8 (kernel dst slot)
;; Wide enough for the cell: COLBYTES*8 = 8 (Model A/M2) or 16/32 (Model B M1/M0).
cc_scratch:		ds JSP_GEOM_COLBYTES*8

;; Reset to 0xFF by jsp_redraw_begin() so the first covered cell of each
;; frame rebuilds the row-sweep set.
_jsp_cc_row_active_row:	db 0xFF

;; Frame-sprite pointers whose [r0,r1] span includes the current row.
cc_row_active:		ds 32

	ENDIF			; IFNDEF CPC_MODE1_MONO
	ENDIF			; JSP_TARGET_CPC
