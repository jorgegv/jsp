;; CPC jsp_frame — per-frame sprite precompute (assembly).
;;
;; Phase 3 (doc/CPC-TARGET-PLAN.md §3/§4): CPC Mode-2 port of lib/zx/
;; jsp_frame.asm.  Run once per frame at the start of jsp_redraw(); for every
;; active registered sprite it fills one jsp_frame_sprites[] entry with the
;; constants the per-cell compositor needs.
;;
;; The only per-mode difference is the horizontal coordinate split: the byte
;; column is c0 = xpos / ppb and the sub-byte phase is xrot = xpos % ppb, with
;; ppb = 8/4/2 for Mode 2/1/0 (plan §3).  That is parametrised below by
;; JSP_PPB_SHIFT (= log2(ppb): 3/2/1) and JSP_XROT_MASK (= ppb-1: 7/3/1; FAST
;; modes force 0 -> always byte-aligned).  Everything else — the rottbl_msb
;; stride (rottbl>>8 + 2*xrot - 2), cs (8/16), base, rowstride and the vertical
;; split (r0 = ypos>>3, yrot = ypos&7, always 8 lines/cell) — is IDENTICAL across
;; modes, because the in-byte/carry shift mechanics are encoded in jsp_rottbl,
;; not here.  color/color_mask are still copied into the frame entry but the CPC
;; covered-cell compositor ignores them (no attribute RAM, §6); copying is harmless.
;;
;; X is 16-bit (jsp_xcoord_t) on CPC: c0 = xpos>>JSP_PPB_SHIFT is a 16-bit shift
;; (0..79, no 0x1F cap); xrot = xpos & JSP_XROT_MASK. Y stays 8-bit. (plan §3.)
;;
;; struct jsp_sprite_s (CPC layout, 14 bytes):
;;   +0 rows  +1 cols  +2..+3 xpos(16b)  +4 ypos  +5 flags  +6 pixels(w)
;;   +8 type_ptr(w)  +10 color  +11 color_mask  +12 clip(w)
;; struct jsp_sprite_frame (16 bytes):
;;   +0 r0  +1 c0  +2 r1  +3 c1  +4 cs  +5 ismask2  +6 rottbl_msb
;;   +7 cols  +8 color  +9 color_mask  +10 base(w)  +12 rowstride(w)
;;   +14 clip(w)

	IFDEF JSP_TARGET_CPC

	section code_compiler

	extern _jsp_sprite_registry
	extern _jsp_sprite_registry_count
	extern _jsp_frame_sprites
	extern _jsp_frame_count
	extern _jsp_rottbl
	extern _JSP_TYPE_MASK2
	extern _jsp_cc_row_active_row

	public _jsp_redraw_begin

;; Per-mode horizontal split + MONO doubling (shared with jsp_sprite_defer.asm
;; so render cells and dirtied cells agree).
	include "lib/cpc/jsp_cpc_geom.inc"

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
;;
;;         xrot = sp->xpos & 0x07;
;;         yrot = sp->ypos & 0x07;
;;         // footprint is rows+1 / cols+1 when pixel-shifted, rows / cols when
;;         // aligned (the +1 covers the sub-cell shift spill into the next cell)
;;         fs->r1 = fs->r0 + ( yrot ? sp->rows : (uint8_t)( sp->rows - 1 ) );
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
;;         fs->rowstride = (uint16_t)( sp->rows + 1 ) * cs;
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
	ld a,(ix+5)			; CPC flags @ +5
	and 0x03			; bits 0,1 = initialized, active
	cp 0x03
	jp nz,rb_skip

	;; --- precompute the cross-field values (CPC descriptor layout:
	;;     xpos +2..+3 16-bit, ypos +4, flags +5, pixels +6, type +8,
	;;     color +10, cmask +11, clip +12) ---
	ld a,(ix+4)			; r0 = ypos >> 3   (ypos 8-bit, 0..24)
	rrca
	rrca
	rrca
	and 0x1F
	ld (rb_r0),a
	ld e,(ix+2)			; c0 = xpos >> JSP_PPB_SHIFT (xpos 16-bit, 0..79)
	ld d,(ix+3)			; (use DE, not HL: HL is the frame write ptr)
	REPT JSP_PPB_SHIFT		; ppb=8 -> 3, ppb=4 -> 2, ppb=2 -> 1
	srl d
	rr e
	ENDR
	ld a,e				; no 0x1F cap: 80-col grid needs c0 up to 79
	ld (rb_c0),a
	ld a,(ix+2)			; xrot = xpos & JSP_XROT_MASK (low byte; FAST forces 0)
	and JSP_XROT_MASK
	ld (rb_xrot),a
	ld a,(ix+4)			; yrot = ypos & 7
	and 7
	ld (rb_yrot),a
	ld a,(ix+1)			; cols
	ld (rb_cols),a
	ld bc,_JSP_TYPE_MASK2		; ismask2 = (type_ptr == JSP_TYPE_MASK2)
	ld a,(ix+8)
	cp c
	jr nz,rb_notmask
	ld a,(ix+9)
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
	;; +2 r1 = r0 + (yrot ? rows : rows-1).  Vertical analog of the c1/xrot
	;; rule below: when yrot==0 the sprite is cell-aligned and spans exactly
	;; `rows` cell-rows, so the extra bottom row must NOT be composited — doing
	;; so renders a spurious row whose lines read past the column's 8-line
	;; trailing pad (stale-pixel artifact one cell below the sprite).
	ld a,(ix+0)			; rows
	ld c,a
	ld a,(rb_yrot)
	or a
	ld a,c				; A = rows (ld a,c does not affect flags)
	jr nz,rb_r1
	dec a				; aligned (yrot==0): rows-1
rb_r1:
	ld c,a
	ld a,(rb_r0)
	add a,c
	ld (hl),a
	inc hl
	;; +3 c1 = c0 + (xrot ? W : W-1).  W = cols normally; in MONO each 1bpp
	;; source column spans 2 Mode-1 screen cells, so W = 2*cols.  The doubling
	;; must happen BEFORE the xrot test (add a,a clobbers flags; ld a,(nn) /
	;; ld a,c do not), so we compute W into C first, then test xrot.
	ld a,(rb_cols)
	REPT JSP_MONO_DBL		; MONO: W = 2*cols (1bpp col -> 2 Mode-1 cells)
	add a,a
	ENDR
	ld c,a				; C = W
	ld a,(rb_xrot)
	or a
	ld a,c				; A = W  (does not affect flags)
	jr nz,rb_c1
	dec a				; aligned: W-1
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
	ld a,(ix+10)			; +8 color      (CPC color @ +10)
	ld (hl),a
	inc hl
	ld a,(ix+11)			; +9 color_mask (CPC cmask @ +11)
	ld (hl),a
	inc hl
	ld a,(rb_yrot)			; +10/11 base = pixels - yrot*(cs>>3)
	ld c,a				; C = disp = yrot (load1)
	ld a,(rb_ismask2)
	or a
	jr z,rb_base
	sla c				; mask2: disp = yrot * 2
rb_base:
	ld a,(ix+6)			; pixels lo - disp  (CPC pixels @ +6)
	sub c
	ld (hl),a
	inc hl
	ld a,(ix+7)			; pixels hi - borrow
	sbc a,0
	ld (hl),a
	inc hl
	ld a,(ix+0)			; +12/13 rowstride = (rows+1)*cs
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
	;; columns sit a full 8-line cell apart, so the stride is exactly
	;; (rows+1)*cs (no correction).  The matching 8-line trailing pad per
	;; column is emitted by tools/gfxgen.pl / cpcgfx.pl (RAGE1-compatible layout).
	ld (hl),c
	inc hl
	ld (hl),b
	inc hl
	ld a,(ix+12)			; +14/15 clip   (CPC clip @ +12..+13)
	ld (hl),a
	inc hl
	ld a,(ix+13)
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

	ENDIF			; JSP_TARGET_CPC
