// JSP-CPC Phase 2 test — background-tile-only Mode 2 image.
//
// Sets CPC Mode 2 (full RAM, both ROMs off) + a black/white palette, inits JSP,
// fills the 80x25 cell grid with a tile pattern, and calls jsp_redraw() once.
// Proves the CPC screen layer end-to-end (data placement, rowcolindex, the
// 250-group DTT walk, the 0xC000+cell / +0x800 cell blit) — no sprites.
//
// Build:  make cpc-bg     (zcc +cpc, CPC_MODE2)   then verify in cap32.

#include <stdint.h>
#include "jsp.h"

// 8x8 Mode-2 (1bpp) tile graphics: 8 bytes, 1 byte per pixel line.
static uint8_t tile_solid[8]   = { 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF };
static uint8_t tile_frame[8]   = { 0xFF,0x81,0x81,0x81,0x81,0x81,0x81,0xFF };
static uint8_t tile_stripe[8]  = { 0xAA,0x55,0xAA,0x55,0xAA,0x55,0xAA,0x55 };
static uint8_t tile_blank[8]   = { 0,0,0,0,0,0,0,0 };

// Set Mode 2 + black(pen0)/white(pen1) via the Gate Array; both ROMs off (0x8E)
// so the whole 0x0000-0xBFFF is RAM (code at 0x1200 stays visible — see the
// project_cpc_bringup_rmr_rom memory).
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
    ld a,0x8e          ; RMR: mode 2, both ROMs OFF (full RAM)
    out (c),a
    __endasm;
}

void main( void ) {
    uint8_t r, c;

    cpc_setup_mode2();
    jsp_init( tile_blank, 0 );          // default bg = blank (attr unused on CPC)

    for ( r = 0; r < 25; r++ ) {
        for ( c = 0; c < 80; c++ ) {
            uint8_t *t;
            if ( r == 0 || r == 24 || c == 0 || c == 79 )
                t = tile_solid;          // white border around the screen
            else if ( ( r ^ c ) & 1 )
                t = tile_stripe;         // checker of stripes ...
            else
                t = tile_frame;          // ... and little frames
            jsp_draw_background_tile( r, c, t );
        }
    }

    jsp_redraw();

    for ( ;; ) ;
}
