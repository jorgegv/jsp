;; jsp_sprite_defer — deferred sprite move/draw/park + DTT rect-mark (asm)
;;
;; Task 4.1: assembly rewrite of the deferred-operation hot path, formerly
;; the C jsp_dtt_mark_rect / mark_footprint_dirty / jsp_move_sprite /
;; jsp_draw_sprite / jsp_sprite_park in lib/jsp_sprite_c.c.  These never
;; touch the screen: they update the sprite descriptor and OR the cell's
;; footprint into the DTT bitmap; compositing happens in jsp_redraw().
;;
;; The original C of each converted function is kept verbatim as a comment
;; block above its assembly (per the CLAUDE.md conversion guideline).
;;
;; struct jsp_sprite_s (13 bytes), offsets used here:
;;   +0 rows  +1 cols  +2 xpos  +3 ypos  +4 flags  +11 clip(w)
;;   flags bits: 0 initialized, 1 active, 2 registered
;; struct jsp_rect: +0 row  +1 col  +2 width  +3 height
;;
;; The C entry points (jsp_move_sprite/jsp_draw_sprite/jsp_sprite_park) are
;; called from C, which uses IX as its frame pointer — so every entry that
;; clobbers IX saves and restores it.

	section code_compiler

	extern _jsp_dtt
	extern _jsp_register_sprite

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
;;     if ( r1 > 23 ) r1 = 23;
;;     if ( c1 > 31 ) c1 = 31;
;;     for ( r = r0; r <= r1; r++ ) {
;;         cell = (uint16_t)r * 32 + c0;
;;         byte = cell >> 3;
;;         mask = 1 << ( cell & 7 );        // one variable shift per row
;;         for ( c = c0; c <= c1; c++ ) {
;;             jsp_dtt[ byte ] |= mask;
;;             mask <<= 1;
;;             if ( mask == 0 ) { mask = 1; byte++; }
;;         }
;;     }
;; }
;;
;; Implementation note: cell&7 = c0&7 (row*32 is a multiple of 8), so the
;; bit mask is constant for every row; the row's first DTT byte is
;; r0*4 + (c0>>3).  Does not touch IX.
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
	ld a,(mr_r1)			; if ( r1 > 23 ) r1 = 23;
	cp 24
	jr c,mrc_r1ok
	ld a,23
	ld (mr_r1),a
mrc_r1ok:
	ld a,(mr_c1)			; if ( c1 > 31 ) c1 = 31;
	cp 32
	jr c,mrc_c1ok
	ld a,31
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
	ld a,(mr_c0)			; rowptr = jsp_dtt + r0*4 + (c0>>3)
	rrca
	rrca
	rrca
	and 0x1F
	ld e,a
	ld a,(mr_r0)
	add a,a
	add a,a				; r0 * 4
	add a,e				; + c0>>3
	ld l,a
	ld h,0
	ld de,_jsp_dtt
	add hl,de
	ld (mr_rowptr),hl
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
	ld de,4
	add hl,de			; next char row = +4 DTT bytes
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
;;     uint8_t yrot = sp->ypos & 7;
;;     uint8_t r1 = r0 + ( yrot ? sp->rows : sp->rows - 1 );  // no extra row when aligned
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
	ld a,(ix+3)			; r0 = ypos >> 3
	rrca
	rrca
	rrca
	and 0x1F
	ld (mr_r0),a
	;; r1 = r0 + (yrot ? rows : rows-1) — match the frame's vertical footprint
	;; (no extra bottom row when cell-aligned, see lib/zx/jsp_frame.asm).
	ld c,(ix+0)			; C = rows
	ld a,(ix+3)			; yrot = ypos & 7
	and 7
	jr nz,mf_vr1
	dec c				; aligned (yrot==0): rows-1
mf_vr1:
	ld a,(mr_r0)
	add a,c
	ld (mr_r1),a
	ld a,(ix+2)			; c0 = xpos >> 3
	rrca
	rrca
	rrca
	and 0x1F
	ld (mr_c0),a
	add a,(ix+1)			; c1 = c0 + cols
	ld (mr_c1),a
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
	ld a,l
	ld (defer_xpos),a
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
	ld a,l
	ld (defer_xpos),a
	pop hl
	ld (defer_sp),hl
	push ix				; preserve caller's SDCC frame pointer
	xor a
	ld (defer_ismove),a

defer_body:
	ld ix,(defer_sp)
	bit 0,(ix+4)			; initialized?
	jr z,defer_done
	ld hl,(defer_sp)		; jsp_register_sprite(sp)
	call _jsp_register_sprite	; C (__z88dk_fastcall); preserves IX
	ld a,(defer_ismove)
	or a
	jr z,defer_reposition		; draw: no old footprint
	bit 1,(ix+4)			; move: mark OLD footprint if active
	jr z,defer_reposition
	ld de,0				; clip = NULL (old position unclipped)
	call mark_footprint
defer_reposition:
	ld a,(defer_xpos)		; sp->xpos = xpos
	ld (ix+2),a
	ld a,(defer_ypos)		; sp->ypos = ypos
	ld (ix+3),a
	set 1,(ix+4)			; sp->flags.active = 1
	ld e,(ix+11)			; DE = sp->clip
	ld d,(ix+12)
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
	bit 1,(ix+4)			; active?
	jr z,park_done
	ld de,0				; clip = NULL
	call mark_footprint
park_done:
	res 1,(ix+4)			; sp->flags.active = 0
	pop ix
	ret

	section data_compiler
defer_ret:	dw 0
defer_sp:	dw 0
defer_xpos:	db 0
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
