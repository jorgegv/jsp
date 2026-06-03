// JSP-CPC Mode 1 background test — PIXEL-CELL model (Model B, 8x8-pixel cells).
//
// Phase-1 verification for the pixel-cell grid math + wide-cell addressing: in
// Model B M1 the grid is 40x25 and a cell is 8px wide = 2 screen bytes/line =
// 16 bytes, stored COLUMN-MAJOR (col0's 8 lines, then col1's 8 lines).  Filling
// the whole grid with an 8x8 box-outline tile must paint clean graph-paper boxes
// edge-to-edge across the full 320x200 Mode-1 screen.  A wrong COLBYTES / cell
// stride would smear or misalign the boxes.
//
// Build:  make cpc-bg-mode1-pixcell      (forces JSP_CELL_MODEL=pixel, CPC_MODE1)
// Run:    tools/cap32-shot.sh CPCBGP1.dsk CPCBGP1

#include <stdint.h>
#include "jsp.h"

// 8x8 box-outline cell, Mode-1, COLUMN-MAJOR (2 byte-columns x 8 lines = 16 B).
// Pen2 (=0x0F for a full 4-px byte; 0x08 for the single leftmost pixel), matching
// the Mode-1 tile encoding in test_cpc_sprite_mode1.c.
//   col0 (left 4 px):  top line full (0x0F), then left edge pixel (0x08) x7
//   col1 (right 4 px):  top line full (0x0F), then blank x7
static uint8_t tile_box[16] = {
    0x0F, 0x08,0x08,0x08,0x08,0x08,0x08,0x08,   // col 0  (left screen byte)
    0x0F, 0x00,0x00,0x00,0x00,0x00,0x00,0x00,   // col 1  (right screen byte)
};
static uint8_t tile_blank[16] = { 0 };

static void cpc_setup_mode1( void ) {
    __asm
    di
    ld bc,0x7f00
    ld a,0x00
    out (c),a
    ld a,0x54          ; pen0 = black (paper)
    out (c),a
    ld a,0x01
    out (c),a
    ld a,0x4b          ; pen1 = bright white
    out (c),a
    ld a,0x02
    out (c),a
    ld a,0x4e          ; pen2 = bright cyan (box lines)
    out (c),a
    ld a,0x03
    out (c),a
    ld a,0x44          ; pen3 = bright yellow
    out (c),a
    ld a,0x8d          ; RMR: mode 1, both ROMs OFF (full RAM)
    out (c),a
    __endasm;
}

void main( void ) {
    uint8_t r, c;

    cpc_setup_mode1();
    jsp_init( tile_blank, 0 );

    for ( r = 0; r < JSP_GRID_ROWS; r++ )        // 25
        for ( c = 0; c < JSP_GRID_COLS; c++ )    // 40 (Model B M1)
            jsp_draw_background_tile( r, c, tile_box );

    jsp_redraw();

    for ( ;; ) ;
}
