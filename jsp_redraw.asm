	section code_compiler

	extern _jsp_draw_tile
	extern _jsp_drt
	extern _jsp_dtt

	public _jsp_redraw

;; The pseudocode for this function is shown below.  Nevertheless, the asm
;; version has been heavily optimized for the common case, that is, almost
;; all cells are not dirty most of the time, and we can process them 8 at a
;; time with the DTT.

;; // redraw full screen
;; void jsp_redraw( void ) {
;;     uint8_t row,col;
;;     uint16_t i;
;;     row = 0;
;;     col = 0;
;;     for ( i = 0; i < 768 ; i++ ) {
;;         if ( jsp_dtt_is_dirty( row, col ) )
;;             jsp_draw_tile( row, col, jsp_drt[ i ] );
;;         col++;
;;         if ( col == 32 ) {
;;             row++;
;;             col = 0;
;;         }
;;     }
;; }

_jsp_redraw:

	xor a
	ld d,a				;; D = row = 0
	ld e,a				;; E = col = 0

	ld b,96				;; B = DTT counter
	ld hl,_jsp_dtt			;; hl = start of dtt

next_cell_group:
	ld a,(hl)
	call nz,process_dirty_cells	;; go to process them

	inc hl				;; prepare next 8 cells

	ld a,8				;; col += 8
	add a,e
	ld e,a				;; now a = col

	and 32				;; if col != 32, continue
	jp z,inc_update_ctr

	inc d				;; if col == 32, row++ and col = 0
	ld e,0				;; and continue

inc_update_ctr:
	ld a,b				;; counter -= 8
	sub 8
	ld b,a
	jp nz,next_cell_group		;; if != 0 process next group

	ret				;; finished processing all DTT

;; process_dirty_cells
;; D: row, E: start col (always a multiple of 8)
;; A: dirty bitmap of next 8 cells
;; trashes A
process_dirty_cells:
	push bc
	push hl

	ld b,8				;; B = counter
	ld c,0				;; C = bit index

dirty_loop:
	rrca
	call c,dirty_cell
	inc c				;; next bit index
	djnz dirty_loop

dirty_exit:
	pop hl
	pop bc
	ret

;; at this point:
;; B = counter, C = col % 8 (bit index)
;; D = row, E = start col
;; trashes HL
dirty_cell:
	push af
	push bc
	push de

	ld h,0				;; HL = row
	ld l,d

	add hl,hl			;; multiply by 32
	add hl,hl	
	add hl,hl	
	add hl,hl	
	add hl,hl	

	ld a,e				;; A = start col
	add a,c				;; A = real col

	or l				;; add the top bits of L
	ld l,a				;; HL = cell index (0-767)

	add hl,hl			;; multiply by 2 to get offset into DRT table
	push de
	ld de,_jsp_drt
	add hl,de			;; HL = _jsp_drt[ cell_index ]
	pop de				;; D = row, E = col

	ld b,0
	ld c,d				;; BC = row
	push bc				;; push row
	ld c,a				;; BC = real col (A still contains real col)
	push bc				;; push real col
	push hl				;; push drt record address

	call _jsp_draw_tile		;; jsp_draw_tile( row, col, jsp_drt[ i ] )
					;; no cleanup - it's _z88dk_callee

	pop de
	pop bc
	pop af
	ret
