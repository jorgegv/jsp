	section code_compiler

	public _jsp_draw_sprite

	extern _jsp_rottbl
	extern jsp_rowcolindex
	extern _jsp_drt
	extern _jsp_memcpy
	extern _sp1_draw_mask2lb
	extern _sp1_draw_mask2rb
	extern _sp1_draw_mask2

; var definitions as global for optimized access

_start_row:	db 0
_start_col:	db 0
_bg_ptr:	dw 0
_pix_ptr:	dw 0
_pix_ptr_left:	dw 0
_rottbl:	dw 0

; void jsp_draw_sprite( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) __smallc __z88dk_callee {
_jsp_draw_sprite:
	pop af		; save ret addr
	pop bc		; C = ypos
	pop de		; E = xpos
	pop hl		; HL = sp
	push af		; restore ret addr

	push ix		; save!

	push hl
	pop ix		; ix = sprite pointer (sp parameter)

	; during all the routine, we'll keep ix = sprite pointer (sp) and
	; b = xpos, c = ypos

	ld b,e		; B = xpos, C = ypos

	;     if ( ! sp->flags.initialized ) return;
	ld a,0x01
	and (hl)
	jp z,jsp_draw_sprite_return

	;     start_row = ypos / 8;
	ld a,0x07
	and c
	ld (_start_row),a

	;     start_col = xpos / 8;
	ld a,0x07
	and b
	ld (_start_col),a

	;     rottbl = &jsp_rottbl[ 512 * ( xpos % 8 ) ] - 512;
	ld a,0x07
	and b			; A = xpos % 8
	add a,a			; A = 2 * xpos % 8
	ld d,_jsp_rottbl/256	; (top byte)
	add a,d			; A = top byte of &jsp_rottbl[ 512 * ( xpos % 8 ) ]
	dec a
	dec a			; A = top byte of jsp_rottbl[ 512 * ( xpos % 8 ) ] - 512
	ld (_rottbl+1),a	; store high byte
	xor a
	ld (_rottbl),a		; ensure low byte is zero

	;     // fill the sprite PDB with the current DRT records as background
	;     // cell by cell
	;     for ( i = 0; i < sp->rows + 1; i++ )
	;         for ( j = 0; j < sp->cols + 1; j++ )
	;             jsp_memcpy( &sp->pdbuf[ ( i * ( sp->cols + 1 ) + j ) * 8 ], jsp_drt[ ( start_row + i ) * 32  + ( start_col + j ) ], 8 );

	push bc			; save xpos,ypos

	ld l,(ix+7)
	ld h,(ix+8)		; HL = sp->pdbuf (it will be incrementing by 8 each time)

	ld b,0			; B = i (row counter) - reset 

jsp_draw_sprite_i:
	ld c,0			; C = j (col counter) - reset

jsp_draw_sprite_j:
	push bc			; save i,j counters
	push hl			; save dst address

	ld a,(_start_row)
	add b
	ld d,a			; D = start_row + i
	ld a,(_start_col)
	add c
	ld e,a			; E = start_col + j
	call jsp_rowcolindex	; HL = DRT index
	add hl,hl		; multiply by 2 to get real byte offset
	ld de,_jsp_drt
	add hl,de		; HL = jsp_drt[ ( start_row + i ) * 32  + ( start_col + j ) ]
	ex de,hl		; DE = jsp_drt[ ( start_row + i ) * 32  + ( start_col + j ) ]
	pop hl			; HL = pdbuf address

	push hl			; save dst addr!

	;             jsp_memcpy( &sp->pdbuf[ ( i * ( sp->cols + 1 ) + j ) * 8 ], jsp_drt[ ( start_row + i ) * 32  + ( start_col + j ) ], 8 );
	push hl			; param: dst
	push de			; param: src
	ld e,8
	ld d,0
	push de			; param: 8
	call _jsp_memcpy	; no cleanup needed: __z88dk_callee

	pop hl			; recover dst addr!

	ld de,8
	add hl,de		; dst += 8

	pop bc			; restore i,j counters

	inc c			; j++
	ld a,(ix+1)
	inc a			; A = sp->cols + 1
	cp c			; is j == sp->cols + 1?
	jp nz,jsp_draw_sprite_j ; no, loop another column

	inc b			; i++
	ld a,(ix+0)
	inc a			; A = sp->rows + 1
	cp b			; is i == sp->rows + 1?
	jp nz,jsp_draw_sprite_i ; no, loop another row

	;     // initialize pointers for drawing
	;     pix_ptr = pix_ptr_left = sp->pixels - ( ypos % 8 ) * 2;

	ld a,0x07
	and c			; A = ypos % 8
	ld l,a
	ld h,0
	add hl,hl		; HL = ( ypos % 8 ) * 2
	ld e,(ix+5)
	ld d,(ix+6)		; DE = sp->pixels
	ex de,hl
	sbc hl,de		; HL = sp->pixels - ( ypos % 8 ) * 2
	ld (_pix_ptr),hl	; store to pix_ptr
	ld (_pix_ptr_left),hl	; store to pix_ptr_left

	;     // draw left column
	;     bg_ptr = &sp->pdbuf[ 0 ];
	;     for ( i = 0; i < sp->rows + 1; i++ ) {
	;         sp1_draw_mask2lb( bg_ptr, pix_ptr, rottbl );
	;         bg_ptr += ( sp->cols + 1 ) * 8;
	;         pix_ptr += 16;
	;     }

	; precalc ( sp->cols + 1 ) * 8 outside of the loop
	ld l,(ix+1)
	inc l
	ld h,0			; HL = sp->cols + 1
	add hl,hl
	add hl,hl
	add hl,hl		; HL = ( sp->cols + 1 ) * 8
	ex de,hl		; save to DE

	ld l,(ix+7)
	ld h,(ix+8)		; HL = sp->pdbuf

	ld b,(ix+0)
	inc b			; B = counter

	; during the loop we keep bg_ptr in HL
jsp_draw_sprite_left_i:
	push bc			; save counter
	push de			; save precalculated ( sp->cols + 1 ) * 8

	push hl			; save bg_ptr

	push hl			; param: bg_ptr
	ld de,(_pix_ptr)
	push de			; param: pix_ptr
	ld de,(_rottbl)
	push de			; param: rottbl
	call _sp1_draw_mask2lb	; no clean up - __z88dk_callee

	ld hl,(_pix_ptr)
	ld de,16
	add hl,de
	ld (_pix_ptr),hl	; pix_ptr += 16

	pop hl			; restore bg_ptr

	; update bg_ptr
	pop de			; restore precalculated ( sp->cols + 1 ) * 8
	add hl,de		; HL(bg_ptr) += ( sp->cols + 1 ) * 8

	pop bc			; restore counter
	djnz jsp_draw_sprite_left_i

	;     // draw middle columns if they exist
	;     for ( j = 1; j < sp->cols; j++ ) {
	;         bg_ptr = &sp->pdbuf[ j * 8 ];
	;         for ( i = 0; i < sp->rows + 1; i++ ) {
	;             sp1_draw_mask2( bg_ptr, pix_ptr, pix_ptr_left, rottbl );
	;             bg_ptr += ( sp->cols + 1 ) * 8;
	;             pix_ptr += 16;
	;             pix_ptr_left += 16;
	;         }
	;     }

	ld c,1			; C = j (col counter) - reset 

	; during the loop we keep bg_ptr in HL
jsp_draw_sprite_middle_j:
	push de			; save precalculated ( sp->cols + 1 ) * 8

	ld l,c
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl		
	ld e,(ix+7)
	ld d,(ix+8)
	add hl,de		; bg_ptr = &sp->pdbuf[ j * 8 ]

	ld b,1			; B = i (row counter) - reset

	pop de			; restore precalculated ( sp->cols + 1 ) * 8

jsp_draw_sprite_middle_i:
	push bc			; save counters i,j
	push de			; save precalculated ( sp->cols + 1 ) * 8
	push hl			; save bg_ptr

	push hl			; param: bg_ptr
	ld hl,(_pix_ptr)
	push hl			; param: pix_ptr
	ld hl,(_pix_ptr_left)
	push hl			; param: pix_ptr_left
	ld hl,(_rottbl)
	push hl			; param: rottbl
	call _sp1_draw_mask2	; no cleanup - __z88dk_callee

	pop hl			; restore bg_ptr
	pop de
	push de
	add hl,de		; bg_ptr += ( sp->cols + 1 ) * 8;

	push hl			; save bg_ptr

	ld de,16

	ld hl,(_pix_ptr)
	add hl,de
	ld (_pix_ptr),hl	; pix_ptr += 16

	ld hl,(_pix_ptr_left)
	add hl,de
	ld (_pix_ptr_left),hl	; pix_ptr_left += 16

	pop hl			; restore bg_ptr
	pop de			; restore precalculated ( sp->cols + 1 ) * 8
	pop bc			; restore counters i,j

	inc b			; i++
	ld a,(ix+0)
	cp b			; i == sp->rows ? (i < sp->rows + 1 ?)
	jp nz,jsp_draw_sprite_middle_i	; no, loop another row

	inc c			; j++
	ld a,(ix+1)
	dec a
	cp c			; j == sp->cols - 1 ? (j < sp->cols ?)
	jp nz,jsp_draw_sprite_middle_j	; no, loop another column

	;     // draw right column if needed
	;     if ( xpos % 8 ) {
	;         bg_ptr = &sp->pdbuf[ sp->cols * 8 ];
	;         // the right column uses the same data as the last middle one, i.e. pix_ptr_left
	;         pix_ptr = pix_ptr_left;
	;         for ( i = 0; i < sp->rows + 1; i++ ) {
	;             sp1_draw_mask2rb( bg_ptr, pix_ptr, rottbl );
	;             bg_ptr += ( sp->cols + 1 ) * 8;
	;             pix_ptr += 16;
	;         }
	;     }

	pop bc			; restore xpos,ypos
	push bc			; save xpos,ypos again
	push de			; save precalculated ( sp->cols + 1 ) * 8

	ld a,b			; skip if xpos % 8 == 0
	and 0x07
	jp z,jsp_draw_sprite_update_drt

	ld hl,(_pix_ptr)
	ld (_pix_ptr_left),hl	; pix_ptr = pix_ptr_left

	ld l,(ix+1)
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	ld e,(ix+7)
	ld d,(ix+8)
	add hl,de		; bg_ptr = &sp->pdbuf[ sp->cols * 8 ]

	ld b,(ix+0)		; i = sp->rows + 1
	inc b

	pop de			; restore precalculated ( sp->cols + 1 ) * 8

	; during the loop we keep bg_ptr in HL
jsp_draw_sprite_right_i:
	push bc			; save counter i
	push hl			; save bg_ptr
	push de			; save precalculated ( sp->cols + 1 ) * 8

	push hl			; param: bg_ptr
	ld hl,(_pix_ptr)
	push hl			; param: pix_ptr
	ld hl,(_rottbl)
	push hl			; param: rottbl
	call _sp1_draw_mask2rb	; no cleanup - __z88dk_callee

	pop de			; restore precalculated ( sp->cols + 1 ) * 8
	pop hl			; restore bg_ptr
	add hl,de		; bg_ptr += ( sp->cols + 1 ) * 8
	push hl			; save bg_ptr

	push de			; save precalculated...
	ld hl,(_pix_ptr)
	ld de,16
	add hl,de
	ld (_pix_ptr),hl	; pix_ptr += 16
	pop de			; restore precalculated...

	pop hl			; restore bg_ptr

	pop bc			; restore counter i
	djnz jsp_draw_sprite_right_i

	;     // update DRT pointers and mark cells as dirty
	;     for ( i = 0; i < sp->rows + 1; i++ )
	;         for ( j = 0; j < sp->cols + 1; j++ ) {
	;             jsp_drt[ ( start_row + i ) * 32  + ( start_col + j ) ] = &sp->pdbuf[ ( i * ( sp->cols + 1 ) + j ) * 8 ];
	;             jsp_dtt_mark_dirty( start_row + i, start_col + j );
	;         }
jsp_draw_sprite_update_drt:

	ld c,0			; i=0
	ld l,(ix+7)
	ld h,(ix+8)		; HL = sp->pdbuf

jsp_draw_sprite_update_drt_i:
	ld b,0			; j=0

jsp_draw_sprite_update_drt_j:
	push bc			; save counters i,j
	push hl			; save current pdbuf pointer

	ld hl,_start_row
	ld a,(hl)
	add a,c
	ld d,a			; D = start_row + i

	ld hl,_start_col
	ld a,(hl)
	add a,b
	ld e,a			; E = start_col + j

	call jsp_rowcolindex	; HL = index into DRT (0-767)
	add hl,hl		; multiply by 2 to get real byte offset

	ld de,_jsp_drt
	add hl,de		; HL = &jsp_drt[ ( start_row + i ) * 32  + ( start_col + j ) ]

	pop de			; DE = current pdbuf pointer
	push de

	ld (hl),e
	inc hl
	ld (hl),d		; jsp_drt[ ( start_row + i ) * 32  + ( start_col + j ) ] = &sp->pdbuf[ ( i * ( sp->cols + 1 ) + j ) * 8 ]

	pop hl			; HL = current pdbuf ptr
	ld de,8
	add hl,de		; pdbuf ptr += 8

	pop bc			; restore counters i,j

	inc b			; j++
	ld a,(ix+1)
	inc a			; A = sp->cols + 1
	cp b			; j == sp-cols + 1 ?
	jp nz,jsp_draw_sprite_update_drt_j

	inc c			; i++
	ld a,(ix+0)
	inc a			; A = sp->rows + 1
	cp c			; i == sp-rows + 1 ?
	jp nz,jsp_draw_sprite_update_drt_i

	;     // update sprite with new pos
	;     sp->xpos = xpos;
	;     sp->ypos = ypos;
	pop bc			; restore xpos,ypos
	ld (ix+2),b		; sp->xpos = xpos
	ld (ix+3),c		; sp->ypos = ypos

jsp_draw_sprite_return:
	pop ix		; restore!
	ret

; }
; 
; void jsp_move_sprite( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) __smallc __z88dk_callee {
; 
;     // mark old positions as dirty
;     start_row = sp->ypos / 8;
;     start_col = sp->xpos / 8;
; 
;     for ( i = 0; i < sp->rows + 1; i++ )
;         for ( j = 0; j < sp->cols + 1; j++ )
;             jsp_dtt_mark_dirty( start_row + i, start_col + j );
; 
;     // draw on new position
;     jsp_draw_sprite( sp, xpos, ypos );
; }
; 
