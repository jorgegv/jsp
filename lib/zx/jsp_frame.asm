;; jsp_frame — per-frame sprite precompute (assembly, Task 4.2)
;;
;; Assembly rewrite of the C jsp_redraw_begin() formerly in
;; lib/jsp_composite.c.  Run once per frame at the start of jsp_redraw():
;; for every active registered sprite it fills one jsp_frame_sprites[]
;; entry with the constants the per-cell compositor needs, so that path
;; never recomputes per-sprite values.
;;
;; The two 16-bit multiplies the C version compiled to __mulint calls are
;; gone: cs is a power of two (8 for load1, 16 for mask2), so
;;   rowstride = (rows+1)*cs - (cs>>3)  ->  ((rows+1)<<3)-1, or ((rows+1)<<4)-2
;;   base disp = yrot*(cs>>3)  ->  yrot, or yrot<<1 for mask2
;;
;; struct jsp_sprite_s (13 bytes):
;;   +0 rows  +1 cols  +2 xpos  +3 ypos  +4 flags  +5 pixels(w)
;;   +7 type_ptr(w)  +9 color  +10 color_mask  +11 clip(w)
;; struct jsp_sprite_frame (16 bytes):
;;   +0 r0  +1 c0  +2 r1  +3 c1  +4 cs  +5 ismask2  +6 rottbl_msb
;;   +7 cols  +8 color  +9 color_mask  +10 base(w)  +12 rowstride(w)
;;   +14 clip(w)

	section code_compiler

	extern _jsp_sprite_registry
	extern _jsp_sprite_registry_count
	extern _jsp_frame_sprites
	extern _jsp_frame_count
	extern _jsp_rottbl
	extern _JSP_TYPE_MASK2
	extern _jsp_cc_row_active_row

	public _jsp_redraw_begin

;; ====================================================================
;; jsp_redraw_begin — fill jsp_frame_sprites[] for the frame
;; ====================================================================
;;
;; void jsp_redraw_begin( void ) {
;;     uint8_t i, n = 0;
;;
;;     for ( i = 0; i < jsp_sprite_registry_count; i++ ) {
;;         struct jsp_sprite_s     *sp = jsp_sprite_registry[ i ];
;;         struct jsp_sprite_frame *fs;
;;         uint8_t xrot, yrot, cs;
;;
;;         if ( !sp->flags.initialized || !sp->flags.active )
;;             continue;
;;
;;         fs = &jsp_frame_sprites[ n++ ];
;;
;;         fs->r0 = sp->ypos >> 3;
;;         fs->c0 = sp->xpos >> 3;
;;         fs->r1 = fs->r0 + sp->rows;
;;
;;         xrot = sp->xpos & 0x07;
;;         yrot = sp->ypos & 0x07;
;;         // footprint is cols+1 wide when pixel-shifted, cols wide when aligned
;;         fs->c1 = fs->c0 + ( xrot ? sp->cols : (uint8_t)( sp->cols - 1 ) );
;;
;;         fs->ismask2 = ( sp->type_ptr == JSP_TYPE_MASK2 );
;;         cs          = fs->ismask2 ? 16 : 8;
;;         fs->cs      = cs;
;;         fs->cols    = sp->cols;
;;
;;         fs->rottbl_msb =
;;             (uint8_t)( ( (uint16_t)jsp_rottbl >> 8 ) + 2 * xrot - 2 );
;;         fs->base      = sp->pixels - (uint16_t)yrot * ( cs >> 3 );
;;         fs->rowstride = (uint16_t)( sp->rows + 1 ) * cs - ( cs >> 3 );
;;
;;         fs->color      = sp->color;
;;         fs->color_mask = sp->color_mask;
;;         fs->clip       = sp->clip;
;;     }
;;     jsp_frame_count = n;
;;
;;     // invalidate the row-sweep set so the first covered cell rebuilds it
;;     jsp_cc_row_active_row = 0xFF;
;; }

_jsp_redraw_begin:
	push ix				; preserve the C caller's frame pointer

	xor a				; n = 0
	ld (rb_n),a

	ld a,(_jsp_sprite_registry_count)
	or a
	jp z,rb_finish			; no registered sprites
	ld (rb_count),a

	ld hl,_jsp_sprite_registry
	ld (rb_regptr),hl
	ld hl,_jsp_frame_sprites	; HL = running frame-entry write pointer

rb_loop:
	;; sp = *rb_regptr ; advance rb_regptr
	push hl				; save frame-entry pointer
	ld hl,(rb_regptr)
	ld e,(hl)
	inc hl
	ld d,(hl)			; DE = sp
	inc hl
	ld (rb_regptr),hl
	pop hl				; restore frame-entry pointer
	push de
	pop ix				; IX = sp

	;; if ( !initialized || !active ) continue;
	ld a,(ix+4)
	and 0x03			; bits 0,1 = initialized, active
	cp 0x03
	jp nz,rb_skip

	;; --- precompute the cross-field values ---
	ld a,(ix+3)			; r0 = ypos >> 3
	rrca
	rrca
	rrca
	and 0x1F
	ld (rb_r0),a
	ld a,(ix+2)			; c0 = xpos >> 3
	rrca
	rrca
	rrca
	and 0x1F
	ld (rb_c0),a
	ld a,(ix+2)			; xrot = xpos & 7
	and 7
	ld (rb_xrot),a
	ld a,(ix+3)			; yrot = ypos & 7
	and 7
	ld (rb_yrot),a
	ld a,(ix+1)			; cols
	ld (rb_cols),a
	ld bc,_JSP_TYPE_MASK2		; ismask2 = (type_ptr == JSP_TYPE_MASK2)
	ld a,(ix+7)
	cp c
	jr nz,rb_notmask
	ld a,(ix+8)
	cp b
	jr nz,rb_notmask
	ld a,1
	jr rb_setmask
rb_notmask:
	xor a
rb_setmask:
	ld (rb_ismask2),a

	;; --- write the 16-byte frame entry sequentially (HL = fs) ---
	ld a,(rb_r0)			; +0 r0
	ld (hl),a
	inc hl
	ld a,(rb_c0)			; +1 c0
	ld (hl),a
	inc hl
	ld a,(rb_r0)			; +2 r1 = r0 + rows
	add a,(ix+0)
	ld (hl),a
	inc hl
	ld a,(rb_xrot)			; +3 c1 = c0 + (xrot ? cols : cols-1)
	or a
	ld a,(rb_cols)			; (ld a,(nn) does not affect flags)
	jr nz,rb_c1
	dec a
rb_c1:
	ld c,a
	ld a,(rb_c0)
	add a,c
	ld (hl),a
	inc hl
	ld a,(rb_ismask2)		; +4 cs = ismask2 ? 16 : 8
	or a
	ld a,8
	jr z,rb_cs
	ld a,16
rb_cs:
	ld (hl),a
	inc hl
	ld a,(rb_ismask2)		; +5 ismask2
	ld (hl),a
	inc hl
	ld a,(rb_xrot)			; +6 rottbl_msb = jsp_rottbl>>8 + 2*xrot - 2
	add a,a
	add a,_jsp_rottbl/256
	sub 2
	ld (hl),a
	inc hl
	ld a,(rb_cols)			; +7 cols
	ld (hl),a
	inc hl
	ld a,(ix+9)			; +8 color
	ld (hl),a
	inc hl
	ld a,(ix+10)			; +9 color_mask
	ld (hl),a
	inc hl
	ld a,(rb_yrot)			; +10/11 base = pixels - yrot*(cs>>3)
	ld c,a				; C = disp = yrot (load1)
	ld a,(rb_ismask2)
	or a
	jr z,rb_base
	sla c				; mask2: disp = yrot * 2
rb_base:
	ld a,(ix+5)			; pixels lo - disp
	sub c
	ld (hl),a
	inc hl
	ld a,(ix+6)			; pixels hi - borrow
	sbc a,0
	ld (hl),a
	inc hl
	ld a,(ix+0)			; +12/13 rowstride = (rows+1)*cs - (cs>>3)
	inc a				; rows + 1
	ld c,a
	ld b,0				; BC = rows + 1
	sla c
	rl b				; * 2
	sla c
	rl b				; * 4
	sla c
	rl b				; * 8
	ld a,(rb_ismask2)
	or a
	jr z,rb_rowstride
	sla c
	rl b				; * 16 for mask2
rb_rowstride:
	;; columns sit 7 blank scanlines apart (not a full 8-line cell), so the
	;; stride is (rows+1)*cs - (cs>>3): -1 (load1) / -2 (mask2).  The matching
	;; 7-line trailing pad per column is emitted by tools/gfxgen.pl.
	dec bc				; - (cs>>3): load1 -> -1
	ld a,(rb_ismask2)
	or a
	jr z,rb_rs_store
	dec bc				; mask2 -> -2
rb_rs_store:
	ld (hl),c
	inc hl
	ld (hl),b
	inc hl
	ld a,(ix+11)			; +14/15 clip
	ld (hl),a
	inc hl
	ld a,(ix+12)
	ld (hl),a
	inc hl				; HL now -> next frame entry

	ld a,(rb_n)			; n++
	inc a
	ld (rb_n),a

rb_skip:
	ld a,(rb_count)
	dec a
	ld (rb_count),a
	jp nz,rb_loop

rb_finish:
	ld a,(rb_n)			; jsp_frame_count = n
	ld (_jsp_frame_count),a
	ld a,0xFF			; jsp_cc_row_active_row = 0xFF
	ld (_jsp_cc_row_active_row),a
	pop ix
	ret

	section data_compiler
rb_count:	db 0
rb_regptr:	dw 0
rb_n:		db 0
rb_r0:		db 0
rb_c0:		db 0
rb_xrot:	db 0
rb_yrot:	db 0
rb_cols:	db 0
rb_ismask2:	db 0
