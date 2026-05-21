;; jsp_redraw — flicker-free single-pass recompositing (assembly)
;;
;; Reuses the byte-skip DTT-walk pattern of the original jsp_redraw.asm.
;; jsp_redraw_begin() (C) first precomputes jsp_frame_sprites[] for the
;; frame.  Then, for every dirty cell:
;;
;;   - foreground cell, or no active sprite covers it  -> blit the BTT
;;     tile and the BAT attribute straight to the screen (the common
;;     case: the whole initial redraw and every sprite trail)
;;   - covered by a sprite -> hand the cell to the C helper
;;     jsp_redraw_covered_cell(), which composites and draws it
;;
;; One store per cell => flicker-free.  See jsp_composite.c / ENGINE.md.
;;
;; All loop state lives in memory, so the C calls (which trash the
;; registers) are harmless; nothing relies on IX/IY here.

	section code_compiler

	extern _jsp_redraw_begin
	extern _jsp_frame_count
	extern _jsp_frame_sprites
	extern _jsp_dtt
	extern _jsp_ftt
	extern _jsp_btt
	extern _jsp_bat
	extern _jsp_redraw_covered_cell
	extern jsp_draw_screen_tile_regs

	public _jsp_redraw

; void jsp_redraw( void );
_jsp_redraw:
	call _jsp_redraw_begin		; fill jsp_frame_sprites[], set _jsp_frame_count

	xor a
	ld (rd_g),a			; g = 0

;; ---- per-group loop: 96 groups of 8 cells ----
rd_group:
	ld a,(rd_g)
	ld e,a
	ld d,0				; DE = g

	ld hl,_jsp_dtt
	add hl,de
	ld a,(hl)			; A = jsp_dtt[g]
	or a
	jp z,rd_group_next		; clean group: skip fast

	ld (rd_dtt),a
	ld hl,_jsp_ftt
	add hl,de
	ld a,(hl)
	ld (rd_ftt),a			; A = jsp_ftt[g]

	;; derive row / colbase / cellbase from g
	ld a,(rd_g)
	srl a
	srl a				; A = g >> 2 = row
	ld (rd_row),a

	ld a,(rd_g)
	and 3
	add a,a
	add a,a
	add a,a				; A = (g & 3) << 3 = colbase
	ld (rd_colbase),a

	ld a,(rd_g)
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl			; HL = g << 3 = cellbase (row*32+colbase)
	ld (rd_cellbase),hl

	xor a
	ld (rd_bit),a

;; ---- per-bit loop: 8 cells in the group ----
rd_bit_loop:
	;; mask = 1 << rd_bit
	ld a,(rd_bit)
	ld b,a
	ld a,1
	inc b
rd_mask:
	dec b
	jr z,rd_mask_done
	add a,a
	jr rd_mask
rd_mask_done:
	ld (rd_mask_v),a		; rd_mask_v = 1 << bit

	ld c,a
	ld a,(rd_dtt)
	and c
	jp z,rd_bit_next		; this cell is not dirty

	;; dirty cell: rd_col = colbase + bit
	ld a,(rd_colbase)
	ld hl,rd_bit
	add a,(hl)
	ld (rd_col),a

	;; foreground cell? (FTT bit set) -> background path
	ld a,(rd_mask_v)
	ld c,a
	ld a,(rd_ftt)
	and c
	jp nz,rd_bg_cell

	;; any active sprite at all?
	ld a,(_jsp_frame_count)
	or a
	jp z,rd_bg_cell

	;; is this cell inside some sprite's footprint rectangle?
	call rd_is_covered		; Z = not covered, NZ = covered
	jp z,rd_bg_cell

	;; covered cell: composite + draw via the C helper
	ld a,(rd_row)
	ld h,a
	ld a,(rd_col)
	ld l,a				; HL = (row << 8) | col
	call _jsp_redraw_covered_cell	; __z88dk_fastcall
	jp rd_bit_next

;; ---- background-only cell: blit BTT tile + BAT attribute ----
rd_bg_cell:
	ld hl,(rd_cellbase)
	ld a,(rd_bit)
	ld e,a
	ld d,0
	add hl,de			; HL = cell index (0..767)
	push hl				; save cell

	add hl,hl			; HL = cell * 2
	ld de,_jsp_btt
	add hl,de			; HL = &jsp_btt[cell]
	ld e,(hl)
	inc hl
	ld d,(hl)			; DE = jsp_btt[cell] (tile gfx ptr)

	ld a,(rd_row)
	ld h,a
	ld a,(rd_col)
	ld l,a				; H = row, L = col
	call jsp_draw_screen_tile_regs	; blit DE -> screen cell (8 bytes)

	pop hl				; HL = cell
	ld de,_jsp_bat
	add hl,de
	ld a,(hl)			; A = jsp_bat[cell]
	ld e,a				; stash attr in E

	ld hl,(rd_cellbase)
	ld a,(rd_bit)
	ld c,a
	ld b,0
	add hl,bc			; HL = cell
	ld bc,0x5800
	add hl,bc			; HL = 0x5800 + cell (attribute address)
	ld (hl),e			; store attribute

rd_bit_next:
	ld a,(rd_bit)
	inc a
	ld (rd_bit),a
	cp 8
	jp c,rd_bit_loop

rd_group_next:
	ld a,(rd_g)
	inc a
	ld (rd_g),a
	cp 96
	jp c,rd_group

	;; clear the DTT (96 bytes) for the next frame
	ld hl,_jsp_dtt
	ld d,h
	ld e,l
	inc de
	ld (hl),0
	ld bc,95
	ldir
	ret

;; ---- rd_is_covered -------------------------------------------------
;; Returns NZ if cell (rd_row,rd_col) lies inside some frame sprite's
;; [r0,r1] x [c0,c1] rectangle, Z otherwise.  Caller guarantees
;; _jsp_frame_count > 0.  Each jsp_sprite_frame is 16 bytes; the
;; rectangle is at offsets +0 r0, +1 c0, +2 r1, +3 c1.
;; Trashes A,BC,DE,HL.
rd_is_covered:
	ld a,(_jsp_frame_count)
	ld b,a				; B = sprite counter
	ld hl,_jsp_frame_sprites
rd_cov_loop:
	;; row >= r0 ?
	ld a,(rd_row)
	cp (hl)				; CF if row < r0
	jr c,rd_cov_skip
	;; row <= r1 ?
	inc hl
	inc hl				; HL -> r1
	cp (hl)				; A=row ; CF if row<r1, Z if row==r1
	dec hl
	dec hl				; HL -> base (dec hl does not touch flags)
	jr c,rd_cov_row_ok		; row < r1
	jr nz,rd_cov_skip		; row > r1
rd_cov_row_ok:
	;; col >= c0 ?
	inc hl				; HL -> c0
	ld a,(rd_col)
	cp (hl)				; CF if col < c0
	dec hl				; HL -> base
	jr c,rd_cov_skip
	;; col <= c1 ?
	inc hl
	inc hl
	inc hl				; HL -> c1
	ld c,(hl)
	dec hl
	dec hl
	dec hl				; HL -> base
	ld a,(rd_col)
	cp c				; CF if col<c1, Z if col==c1
	jr c,rd_cov_hit
	jr z,rd_cov_hit
	jr rd_cov_skip			; col > c1
rd_cov_hit:
	ld a,1
	or a				; NZ: covered
	ret
rd_cov_skip:
	ld de,16			; sizeof(struct jsp_sprite_frame)
	add hl,de			; next frame sprite
	djnz rd_cov_loop
	xor a				; Z: not covered
	ret

	section data_compiler
rd_g:		db 0
rd_row:		db 0
rd_col:		db 0
rd_colbase:	db 0
rd_bit:		db 0
rd_dtt:		db 0
rd_ftt:		db 0
rd_mask_v:	db 0
rd_cellbase:	dw 0
