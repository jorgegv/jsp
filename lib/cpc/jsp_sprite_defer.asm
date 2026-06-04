;; CPC jsp_sprite_defer — deferred sprite move/draw/park + DTT rect-mark (asm)
;;
;; Phase 3 (doc/CPC-TARGET-PLAN.md §2/§7): CPC Model-A port of lib/zx/
;; jsp_sprite_defer.asm.  These never touch the screen: they update the sprite
;; descriptor and OR the cell's footprint into the DTT bitmap; compositing
;; happens in jsp_redraw().
;;
;; ONLY divergence from the ZX version is the grid arithmetic in
;; mark_rect_core: the CPC Model-A grid is 80 cols x 25 rows, so a cell index
;; is row*80 + col and its packed-DTT byte is row*10 + col/8.  80 is a multiple
;; of 8, so row*80 mod 8 == 0 and the "constant bit-mask per row" optimisation
;; (mask = 1 << (c0 & 7), shifted across the row) is preserved exactly as on ZX.
;; Clamps widen to the 25x80 grid (r1<=24, c1<=79).  Everything else (deferred
;; draw/move/park, mark_footprint, clip handling) is identical to ZX.
;;
;; X is 16-bit (jsp_xcoord_t) on CPC so a sprite can span the full 640px Mode-2
;; screen (80 cells); Y stays 8-bit.  c0 = xpos>>3 is a 16-bit shift (0..79, no
;; cap); xrot = xpos&7 (low byte).  (plan §3.)
;;
;; struct jsp_sprite_s (CPC layout, 14 bytes), offsets used here:
;;   +0 rows  +1 cols  +2..+3 xpos(16b)  +4 ypos  +5 flags  +12..+13 clip(w)
;;   flags bits: 0 initialized, 1 active, 2 registered
;; struct jsp_rect: +0 row  +1 col  +2 width  +3 height
;;
;; The C entry points are called from C, which uses IX as its frame pointer —
;; so every entry that clobbers IX saves and restores it.

	IFDEF JSP_TARGET_CPC

	section code_compiler

	;; Per-mode horizontal split + MONO doubling, shared with jsp_frame.asm so
	;; the cells a sprite renders into and the cells marked dirty for it agree.
	include "lib/cpc/jsp_cpc_geom.inc"

	extern _jsp_dtt
	extern _jsp_register_sprite
	IFDEF JSP_CELL_MODEL_PIXEL
	extern jsp_rowcolindex_dtt	; row-aligned DTT byte index (Model B mark)
	ENDIF

	public _jsp_dtt_mark_rect
	public _jsp_move_sprite
	public _jsp_draw_sprite
	public _jsp_sprite_park

;; ====================================================================
;; jsp_dtt_mark_rect — mark an inclusive cell rectangle dirty
;; ====================================================================
;;
;; void jsp_dtt_mark_rect( uint8_t r0, uint8_t c0, uint8_t r1, uint8_t c1 ) {
;;     uint8_t  r, c, mask;
;;     uint16_t cell, byte;
;;
;;     if ( r1 > 24 ) r1 = 24;
;;     if ( c1 > 79 ) c1 = 79;
;;     for ( r = r0; r <= r1; r++ ) {
;;         cell = (uint16_t)r * 80 + c0;
;;         byte = cell >> 3;                // = r*10 + c0/8
;;         mask = 1 << ( cell & 7 );        // one variable shift per row
;;         for ( c = c0; c <= c1; c++ ) {
;;             jsp_dtt[ byte ] |= mask;
;;             mask <<= 1;
;;             if ( mask == 0 ) { mask = 1; byte++; }
;;         }
;;     }
;; }
;;
;; Implementation note: cell&7 = c0&7 (row*80 is a multiple of 8), so the
;; bit mask is constant for every row; the row's first DTT byte is
;; r0*10 + (c0>>3).  Does not touch IX.
;;
;; void jsp_dtt_mark_rect(...) __smallc __z88dk_callee;
;; __smallc pushes left-to-right, so the stack top->down is: ret,c1,r1,c0,r0.

_jsp_dtt_mark_rect:
	pop hl
	ld (defer_ret),hl
	pop hl
	ld a,l
	ld (mr_c1),a
	pop hl
	ld a,l
	ld (mr_r1),a
	pop hl
	ld a,l
	ld (mr_c0),a
	pop hl
	ld a,l
	ld (mr_r0),a
	call mark_rect_core
	ld hl,(defer_ret)
	jp (hl)

;; mark_rect_core — inputs in mr_r0/mr_c0/mr_r1/mr_c1; call/ret;
;; trashes A,BC,DE,HL; an empty rectangle marks nothing.
mark_rect_core:
	ld a,(mr_r1)			; if ( r1 > 24 ) r1 = 24;
	cp 25
	jr c,mrc_r1ok
	ld a,24
	ld (mr_r1),a
mrc_r1ok:
	ld a,(mr_c1)			; if ( c1 > COLS-1 ) c1 = COLS-1;
	cp JSP_GEOM_COLS
	jr c,mrc_c1ok
	ld a,JSP_GEOM_COLS-1
	ld (mr_c1),a
mrc_c1ok:
	ld a,(mr_c1)			; inner count = c1 - c0 + 1
	ld hl,mr_c0
	sub (hl)
	ret c				; c0 > c1 -> empty
	inc a
	ld (mr_count),a
	ld a,(mr_r1)			; row count = r1 - r0 + 1
	ld hl,mr_r0
	sub (hl)
	ret c				; r0 > r1 -> empty
	inc a
	ld (mr_rowcount),a
	ld a,(mr_c0)			; mask = 1 << (c0 & 7)
	and 7
	ld b,a
	ld c,1
	inc b
	jr mrc_mskt
mrc_mskl:
	sla c
mrc_mskt:
	djnz mrc_mskl
	ld a,c
	ld (mr_mask0),a
	IFDEF JSP_CELL_MODEL_PIXEL
	;; Model B: rowptr = jsp_dtt + row-aligned DTT byte index of (r0, c0_cell)
	ld a,(mr_r0)
	ld d,a
	ld a,(mr_c0)
	ld e,a
	call jsp_rowcolindex_dtt		; HL = DTT byte index (per-model)
	ld de,_jsp_dtt
	add hl,de
	ld (mr_rowptr),hl
	ELSE
	ld a,(mr_c0)			; rowptr = jsp_dtt + r0*10 + (c0>>3)
	rrca
	rrca
	rrca
	and 0x1F
	ld e,a				; E = c0>>3 (0..9)
	ld a,(mr_r0)			; A = r0
	add a,a				; 2*r0
	ld d,a				; D = 2*r0
	add a,a				; 4*r0
	add a,a				; 8*r0
	add a,d				; 10*r0
	add a,e				; + c0>>3
	ld l,a
	ld h,0
	ld de,_jsp_dtt
	add hl,de
	ld (mr_rowptr),hl
	ENDIF
mrc_row:
	ld hl,(mr_rowptr)
	ld a,(mr_mask0)
	ld c,a				; C = working mask
	ld a,(mr_count)
	ld b,a				; B = cells in this row
mrc_inner:
	ld a,(hl)
	or c
	ld (hl),a
	rlc c				; mask <<= 1, CF on byte wrap
	jr nc,mrc_noadv
	inc hl
mrc_noadv:
	djnz mrc_inner
	ld hl,(mr_rowptr)
	ld de,JSP_GEOM_DTT_ROWBYTES	; next cell row = +ROWBYTES DTT bytes (COLS/8)
	add hl,de
	ld (mr_rowptr),hl
	ld hl,mr_rowcount
	dec (hl)
	jp nz,mrc_row
	ret

;; ====================================================================
;; mark_footprint_dirty — mark a sprite's footprint dirty (clipped)
;; ====================================================================
;;
;; static void mark_footprint_dirty( struct jsp_sprite_s *sp,
;;                                   struct jsp_rect *clip ) {
;;     uint8_t r0 = sp->ypos >> 3;
;;     uint8_t c0 = sp->xpos >> 3;
;;     uint8_t r1 = r0 + sp->rows;
;;     uint8_t c1 = c0 + sp->cols;
;;
;;     if ( clip ) {
;;         uint8_t cr1 = clip->row + clip->height - 1;
;;         uint8_t cc1 = clip->col + clip->width  - 1;
;;         if ( r0 < clip->row ) r0 = clip->row;
;;         if ( c0 < clip->col ) c0 = clip->col;
;;         if ( r1 > cr1 )       r1 = cr1;
;;         if ( c1 > cc1 )       c1 = cc1;
;;         if ( r0 > r1 || c0 > c1 )
;;             return;                      // footprint outside the clip
;;     }
;;     jsp_dtt_mark_rect( r0, c0, r1, c1 );
;; }
;;
;; asm entry: IX = sprite, DE = clip rect pointer (0 = no clip).
;; call/ret; preserves IX; trashes A,BC,DE,HL,IY.
mark_footprint:
	ld a,(ix+4)			; r0 = ypos >> 3   (CPC ypos @ +4, 8-bit)
	rrca
	rrca
	rrca
	and 0x1F
	ld (mr_r0),a
	add a,(ix+0)			; r1 = r0 + rows
	ld (mr_r1),a
	ld l,(ix+2)			; c0 = xpos >> JSP_PPB_SHIFT (xpos @ +2..+3, 16-bit)
	ld h,(ix+3)
	REPT JSP_PPB_SHIFT		; ppb=8/4/2 -> 3/2/1 shifts
	srl h
	rr l
	ENDR
	ld a,l				; no 0x1F cap (80-col grid, c0 up to 79)
	ld (mr_c0),a
	;; c1 = c0 + W, W = cols (full) or 2*cols (MONO: 1bpp col spans 2 cells).
	;; mark_rect marks the inclusive c0..c1, i.e. W+1 columns — the +1 covers
	;; the sub-cell shift spill (matches the frame's xrot footprint widening).
	ld a,(ix+1)			; cols
	REPT JSP_MONO_DBL
	add a,a
	ENDR
	ld c,a				; C = W
	ld a,(mr_c0)
	add a,c
	ld (mr_c1),a
	IFDEF JSP_CELL_MODEL_PIXEL
	;; Model B: mr_c0/mr_c1 are BYTE columns; convert to CELL columns
	;; (cell = COLBYTES bytes) so the DTT marks cells, matching the compositor's
	;; cell coverage (floor(c0/COLBYTES) .. floor(c1/COLBYTES)).  Over-marking by
	;; at most one cell (the +1 shift-spill column) is safe — it just repaints bg.
	ld a,(mr_c0)
	REPT JSP_GEOM_CELLSHIFT
	srl a
	ENDR
	ld (mr_c0),a
	ld a,(mr_c1)
	REPT JSP_GEOM_CELLSHIFT
	srl a
	ENDR
	ld (mr_c1),a
	ENDIF
	ld a,d				; clip == NULL ?
	or e
	jp z,mark_rect_core		; no clip -> mark straight away
	push de
	pop iy				; IY = clip rect
	ld a,(mr_r0)			; if ( r0 < clip->row ) r0 = clip->row;
	cp (iy+0)
	jr nc,mf_r0ok
	ld a,(iy+0)
	ld (mr_r0),a
mf_r0ok:
	ld a,(mr_c0)			; if ( c0 < clip->col ) c0 = clip->col;
	cp (iy+1)
	jr nc,mf_c0ok
	ld a,(iy+1)
	ld (mr_c0),a
mf_c0ok:
	ld a,(iy+0)			; cr1 = clip->row + clip->height - 1
	add a,(iy+3)
	dec a
	ld c,a
	ld a,(mr_r1)			; if ( r1 > cr1 ) r1 = cr1;
	cp c
	jr c,mf_r1ok
	jr z,mf_r1ok
	ld a,c
	ld (mr_r1),a
mf_r1ok:
	ld a,(iy+1)			; cc1 = clip->col + clip->width - 1
	add a,(iy+2)
	dec a
	ld c,a
	ld a,(mr_c1)			; if ( c1 > cc1 ) c1 = cc1;
	cp c
	jr c,mf_c1ok
	jr z,mf_c1ok
	ld a,c
	ld (mr_c1),a
mf_c1ok:
	ld a,(mr_r0)			; if ( r0 > r1 || c0 > c1 ) return;
	ld hl,mr_r1
	cp (hl)
	jr z,mf_chkc
	jr nc,mf_empty
mf_chkc:
	ld a,(mr_c0)
	ld hl,mr_c1
	cp (hl)
	jp z,mark_rect_core
	jr nc,mf_empty
	jp mark_rect_core
mf_empty:
	ret

;; ====================================================================
;; jsp_move_sprite / jsp_draw_sprite — deferred reposition
;; ====================================================================
;;
;; void jsp_draw_sprite( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) {
;;     if ( !sp->flags.initialized )
;;         return;
;;     jsp_register_sprite( sp );
;;     sp->xpos = xpos;
;;     sp->ypos = ypos;
;;     sp->flags.active = 1;
;;     mark_footprint_dirty( sp, sp->clip );
;; }
;;
;; void jsp_move_sprite( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) {
;;     if ( !sp->flags.initialized )
;;         return;
;;     jsp_register_sprite( sp );
;;     if ( sp->flags.active )
;;         mark_footprint_dirty( sp, 0 );      // old position, unclipped
;;     sp->xpos = xpos;
;;     sp->ypos = ypos;
;;     sp->flags.active = 1;
;;     mark_footprint_dirty( sp, sp->clip );   // new position, clipped
;; }
;;
;; void jsp_move_sprite(...) __smallc __z88dk_callee;  (jsp_draw_sprite too)
;; __smallc stack top->down: ret, ypos, xpos, sp.

_jsp_move_sprite:
	pop hl
	ld (defer_ret),hl
	pop hl
	ld a,l
	ld (defer_ypos),a
	pop hl
	ld (defer_xpos),hl		; 16-bit xpos
	pop hl
	ld (defer_sp),hl
	push ix				; preserve caller's SDCC frame pointer
	ld a,1
	ld (defer_ismove),a
	jr defer_body

_jsp_draw_sprite:
	pop hl
	ld (defer_ret),hl
	pop hl
	ld a,l
	ld (defer_ypos),a
	pop hl
	ld (defer_xpos),hl		; 16-bit xpos
	pop hl
	ld (defer_sp),hl
	push ix				; preserve caller's SDCC frame pointer
	xor a
	ld (defer_ismove),a

defer_body:
	ld ix,(defer_sp)
	bit 0,(ix+5)			; initialized?  (CPC flags @ +5)
	jr z,defer_done
	ld hl,(defer_sp)		; jsp_register_sprite(sp)
	call _jsp_register_sprite	; C (__z88dk_fastcall); preserves IX
	ld a,(defer_ismove)
	or a
	jr z,defer_reposition		; draw: no old footprint
	bit 1,(ix+5)			; move: mark OLD footprint if active
	jr z,defer_reposition
	ld de,0				; clip = NULL (old position unclipped)
	call mark_footprint
defer_reposition:
	ld hl,(defer_xpos)		; sp->xpos = xpos (16-bit @ +2..+3)
	ld (ix+2),l
	ld (ix+3),h
	ld a,(defer_ypos)		; sp->ypos = ypos (8-bit @ +4)
	ld (ix+4),a
	set 1,(ix+5)			; sp->flags.active = 1
	ld e,(ix+12)			; DE = sp->clip (CPC clip @ +12..+13)
	ld d,(ix+13)
	call mark_footprint		; mark NEW footprint (clipped)
defer_done:
	pop ix				; restore caller's frame pointer
	ld hl,(defer_ret)
	jp (hl)

;; ====================================================================
;; jsp_sprite_park — deactivate a sprite, mark its footprint dirty
;; ====================================================================
;;
;; void jsp_sprite_park( struct jsp_sprite_s *sp ) __z88dk_fastcall {
;;     if ( sp->flags.active )
;;         mark_footprint_dirty( sp, 0 );
;;     sp->flags.active = 0;
;; }
;;
;; __z88dk_fastcall: HL = sprite pointer.

_jsp_sprite_park:
	push ix				; preserve caller's frame pointer
	push hl
	pop ix				; IX = sprite
	bit 1,(ix+5)			; active?  (CPC flags @ +5)
	jr z,park_done
	ld de,0				; clip = NULL
	call mark_footprint
park_done:
	res 1,(ix+5)			; sp->flags.active = 0
	pop ix
	ret

	section data_compiler
defer_ret:	dw 0
defer_sp:	dw 0
defer_xpos:	dw 0		; 16-bit X (CPC)
defer_ypos:	db 0
defer_ismove:	db 0
mr_r0:		db 0
mr_c0:		db 0
mr_r1:		db 0
mr_c1:		db 0
mr_count:	db 0
mr_rowcount:	db 0
mr_mask0:	db 0
mr_rowptr:	dw 0

	ENDIF			; JSP_TARGET_CPC
