// JSP-CPC Phase 5 test — background tile draw / delete / redraw (CPC Mode 2).
//
// CPC Mode-2 port of tests/zx/test_btt_redraw.c: fill a region with a tile, then
// delete a sub-rectangle and redraw.  Deleted cells revert to the default
// background tile (set in jsp_init).  The final still frame shows the filled
// region with a cleared "hole" — verifying jsp_draw_background_tile,
// jsp_delete_background_tile and the deferred redraw on the 80x25 CPC grid.
//
// Build:  make cpc-btt-redraw     verify:  make run-cpc-btt-redraw

#include <stdint.h>
#include "jsp.h"

// geometric "ball" tile (filled blob) — 1bpp, works directly in Mode 2
static uint8_t tile_ball[8]  = { 60, 126, 255, 255, 255, 255, 126, 60 };
static uint8_t tile_blank[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };

// Mode 2 + black/white palette; both ROMs off (project_cpc_bringup_rmr_rom).
static void cpc_setup_mode2( void ) {
    __asm
    di
    ld bc,0x7f00
    ld a,0x00
    out (c),a
    ld a,0x54          ; pen0 = black
    out (c),a
    ld a,0x01
    out (c),a
    ld a,0x4b          ; pen1 = bright white
    out (c),a
    ld a,0x8e          ; RMR: mode 2, both ROMs OFF
    out (c),a
    __endasm;
}

void main( void ) {
    uint8_t r, c;

    cpc_setup_mode2();
    jsp_init( tile_blank, 0 );          // default bg = blank (black)

    // fill a region (rows 2..21, cols 8..71) with the ball tile, then redraw
    for ( r = 2; r < 22; r++ )
        for ( c = 8; c < 72; c++ )
            jsp_draw_background_tile( r, c, tile_ball );
    jsp_redraw();

    // delete a central rectangle (rows 8..15, cols 28..51): reverts to default
    for ( r = 8; r < 16; r++ )
        for ( c = 28; c < 52; c++ )
            jsp_delete_background_tile( r, c );
    jsp_redraw();

    for ( ;; ) ;
}
