// JSP-CPC Phase 6.1 regression test — Mode 1 MONO sprites over a Mode-1
// textured background.
//
// MONO renders plain 1bpp (Mode-2/SP1 format) sprite assets on a Mode-1 screen:
// the 1bpp->Mode-1 (pen 0/1) expansion happens in the covered-cell compositor
// (lib/cpc/jsp_covered_mono.asm), nothing is stored expanded.  So this test
// links the SAME 1bpp ball asset the ZX / CPC-Mode-2 tests use
// (test_sprite_mask2_pixels), with cols=2 (1bpp 8-px cells, vs cols=4 for the
// full-Mode-1 two-nibble-plane asset).
//
// Background TILES are 1bpp too in MONO: the BTT holds the 1bpp tile and the
// blit expands nibble(col&1) to Mode-1 (a 1bpp 8-px tile spans two Mode-1
// cells, so a uniform fill tiles the 8-px pattern seamlessly).  This test draws
// the SAME 1bpp grid tile the CPC-Mode-2 sprite test uses, with the SAME
// per-cell loop — both sprite and tile assets are plain Mode-2 1bpp, halving
// their memory vs full Mode 1.
//
// Build:  make cpc-sprite-mode1-mono   then verify in cap32
//         (make run-cpc-sprite-mode1-mono).

#include <stdint.h>
#include "jsp.h"

extern uint8_t test_sprite_mask2_pixels[];      // the 1bpp (Mode-2 format) ball

#define NUM_SPRITES 5
#define ANIM_FRAMES 240

// 16x16 ball = 2 (1bpp) cols x 2 rows; MONO expands each to 2 Mode-1 screen cells.
DEFINE_SPRITE( sprite0, 2, 2, test_sprite_mask2_pixels, 0, 0, JSP_TYPE_MASK2 );
DEFINE_SPRITE( sprite1, 2, 2, test_sprite_mask2_pixels, 0, 0, JSP_TYPE_MASK2 );
DEFINE_SPRITE( sprite2, 2, 2, test_sprite_mask2_pixels, 0, 0, JSP_TYPE_MASK2 );
DEFINE_SPRITE( sprite3, 2, 2, test_sprite_mask2_pixels, 0, 0, JSP_TYPE_MASK2 );
DEFINE_SPRITE( sprite4, 2, 2, test_sprite_mask2_pixels, 0, 0, JSP_TYPE_MASK2 );

struct {
    uint16_t x;             // 0..319 (Mode-1 screen is 320 px wide)
    uint8_t  y;
    int8_t   dx, dy;
    struct jsp_sprite_s *sp;
} mover[ NUM_SPRITES ] = {
    {  20,  10,  3,  2, &sprite0 },
    { 100,  40, -2,  3, &sprite1 },
    { 170,  90,  4, -1, &sprite2 },
    { 240,  20, -3, -2, &sprite3 },
    { 295,  70,  1,  4, &sprite4 },
};

// Plain 1bpp (Mode-2 / ZX) crossbar-grid tile — the SAME asset the Mode-2 test
// uses.  MONO expands it nibble(col&1) at blit; a uniform fill tiles the 8x8-box
// grid seamlessly across two Mode-1 cells per tile.
static uint8_t tile_grid[8]  = { 0xFF,0x80,0x80,0x80,0x80,0x80,0x80,0x80 };
static uint8_t tile_blank[8] = { 0,0,0,0,0,0,0,0 };

static void cpc_setup_mode1( void ) {
    __asm
    di
    ld bc,0x7f00
    ld a,0x00
    out (c),a
    ld a,0x54          ; pen0 = black   (paper / ball body)
    out (c),a
    ld a,0x01
    out (c),a
    ld a,0x4b          ; pen1 = bright white  (ball highlight / bar 1)
    out (c),a
    ld a,0x02
    out (c),a
    ld a,0x4e          ; pen2 = bright cyan   (bar 2)
    out (c),a
    ld a,0x03
    out (c),a
    ld a,0x44          ; pen3 = bright yellow (bar 3)
    out (c),a
    ld a,0x8d          ; RMR: mode 1, both ROMs OFF (full RAM)
    out (c),a
    __endasm;
}

void main( void ) {
    uint8_t  r, c;
    uint16_t f;

    cpc_setup_mode1();
    jsp_init( tile_blank, 0 );

    for ( r = 0; r < 25; r++ )
        for ( c = 0; c < 80; c++ )
            jsp_draw_background_tile( r, c, tile_grid );

    for ( f = 0; f < ANIM_FRAMES; f++ ) {
        for ( r = 0; r < NUM_SPRITES; r++ ) {
            jsp_move_sprite( mover[r].sp, mover[r].x, mover[r].y );

            if ( mover[r].x + mover[r].dx > 300 || mover[r].x + mover[r].dx < 4 )
                mover[r].dx = -mover[r].dx;
            mover[r].x += mover[r].dx;

            if ( mover[r].y + mover[r].dy > 170 || mover[r].y + mover[r].dy < 4 )
                mover[r].dy = -mover[r].dy;
            mover[r].y += mover[r].dy;
        }
        jsp_redraw();
    }

    for ( ;; ) ;
}
