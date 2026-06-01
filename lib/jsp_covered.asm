;; jsp_covered — covered-cell compositor (assembly, Task 3.3)
;;
;; Single asm routine folding the former C jsp_redraw_covered_cell +
;; jsp_composite_frame_cell (lib/jsp_composite.c).  Called by the asm
;; jsp_redraw for every cell flagged sprite-covered:
;;
;;   - seed an 8-byte scratch with the BTT background tile
;;   - composite every covering frame sprite in z-order (row-sweep set +
;;     column test, same logic as the C version), calling the existing
;;     jsp_draw_* rotation kernels
;;   - blit the result with one store, then write the cell attribute
;;
;; jsp_redraw_begin() (C) still precomputes jsp_frame_sprites[] per frame
;; and resets jsp_cc_row_active_row so the first covered cell rebuilds the
;; row-sweep set.
;;
;; struct jsp_sprite_frame layout (16 bytes), offsets used here:
;;   +0 r0  +1 c0  +2 r1  +3 c1  +4 cs  +5 ismask2  +6 rottbl_msb
;;   +7 cols  +8 color  +9 color_mask  +10 base(w)  +12 rowstride(w)
;;   +14 clip(w)
;; struct jsp_rect: +0 row  +1 col  +2 width  +3 height

	section code_compiler

	extern _jsp_frame_count
	extern _jsp_frame_sprites
	extern _jsp_btt
	extern _jsp_bat
	extern _jsp_current_rottbl_msb
	extern _jsp_draw_load1
	extern _jsp_draw_load1lb
	extern _jsp_draw_load1rb
	extern _jsp_draw_mask2
	extern _jsp_draw_mask2lb
	extern _jsp_draw_mask2rb
	extern jsp_draw_screen_tile_regs

	public _jsp_redraw_covered_cell
	public _jsp_cc_row_active_row
	public cc_cell			; cell-index input, written by jsp_redraw
	public cc_scratch		; compositing buffer; the jsp_draw_* kernels
					; address it absolutely (see those files)

;; void jsp_redraw_covered_cell( uint16_t rowcol ) __z88dk_fastcall;
;; HL = (row << 8) | col
;; The caller must also store the cell index (row*32 + col) in cc_cell
;; before the call; jsp_redraw already has it, so this avoids recomputing
;; it here.  (Internal helper — only jsp_redraw calls it.)
_jsp_redraw_covered_cell:
	ld a,h
	ld (cc_row),a
	ld a,l
	ld (cc_col),a

	;; cell index is supplied by the caller (jsp_redraw) in cc_cell — it
	;; already has it, so we avoid recomputing row*32 + col here.

	;; cc_attr = jsp_bat[cell]
	ld hl,(cc_cell)
	ld de,_jsp_bat
	add hl,de
	ld a,(hl)
	ld (cc_attr),a

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
	ld a,(ix+8)
	ld (cc_color),a			; color
	ld a,(ix+9)
	ld (cc_cmask),a			; color_mask

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
	jr cc_after_draw
cc_mid_mask:
	call _jsp_draw_mask2
	jr cc_after_draw

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
	jr cc_after_draw
cc_lb_mask:
	call _jsp_draw_mask2lb
	jr cc_after_draw

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
	jr cc_after_draw
cc_rb_mask:
	call _jsp_draw_mask2rb

;; ---- apply sprite colour (skipped when color == 0) ----
;; SEAM (ZX, doc/CPC-TARGET-PLAN.md §6): ZX attribute colour merge — no-op on CPC (colour is in the pixels).
cc_after_draw:
	ld a,(cc_color)
	or a
	jr z,cc_comp_next
	;; attr = (attr & cmask) | (color & ~cmask)
	ld hl,cc_attr
	ld a,(cc_cmask)
	and (hl)
	ld c,a				; C = attr & cmask
	ld a,(cc_cmask)
	cpl
	ld b,a				; B = ~cmask
	ld a,(cc_color)
	and b
	or c
	ld (hl),a

cc_comp_next:
	ld hl,cc_loop_n
	dec (hl)
	jp nz,cc_comp_loop

;; ---- blit the cell + write its attribute ----
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
	;; jsp_draw_screen_tile_regs: H=row, L=col, DE=src
	ld a,(cc_row)
	ld h,a
	ld a,(cc_col)
	ld l,a
	call jsp_draw_screen_tile_regs

;; SEAM (ZX, doc/CPC-TARGET-PLAN.md §6): ZX attribute RAM store — dropped on CPC.
	;; *(0x5800 + cell) = cc_attr
	ld hl,(cc_cell)
	ld de,0x5800
	add hl,de
	ld a,(cc_attr)
	ld (hl),a
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
cc_attr:		db 0
cc_covered:		db 0
cc_i:			db 0
cc_j:			db 0
cc_color:		db 0
cc_cmask:		db 0
cc_graph:		dw 0
cc_loop_n:		db 0
cc_slot:		dw 0
cc_row_active_n:	db 0
cc_scratch:		ds 8

;; Reset to 0xFF by jsp_redraw_begin() so the first covered cell of each
;; frame rebuilds the row-sweep set.
_jsp_cc_row_active_row:	db 0xFF

;; Frame-sprite pointers whose [r0,r1] span includes the current row.
cc_row_active:		ds 32
