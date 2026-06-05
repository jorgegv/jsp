// ZX bottom-line artifact regression test (Task 2, 2026-06-04).
//
// Guards the "yrot==0 spurious bottom cell-row" bug (lib/zx/jsp_frame.asm:
// r1 = r0 + (yrot ? rows : rows-1)).  When a sprite is cell-aligned vertically
// (ypos % 8 == 0) the engine used to composite ONE extra cell-row below it.
//
// LOAD1 (opaque) sprites on a fully-lit background: the spurious row's graphic
// is the column's blank trailing pad, so for a LOAD sprite it ERASES a whole
// cell-row of background (and, pre-fix, also painted a stray attribute there) ->
// a clear gap one cell-row below the sprite.  A correct frame keeps the lit
// background intact directly below every sprite.
//
// Captured headless via JNEXT at frame 300; ref: tests/refs/zx/test_artifact.png.

#include <stdint.h>
#include <spectrum.h>

#include "jsp.h"

extern uint8_t test_sprite_load1_pixels[];

#define NUM_SPRITES 3

DEFINE_SPRITE( a0, 16, 16, test_sprite_load1_pixels, 0, 0, JSP_TYPE_LOAD1 );
DEFINE_SPRITE( a1, 16, 16, test_sprite_load1_pixels, 0, 0, JSP_TYPE_LOAD1 );
DEFINE_SPRITE( a2, 16, 16, test_sprite_load1_pixels, 0, 0, JSP_TYPE_LOAD1 );

static struct jsp_sprite_s *spr[ NUM_SPRITES ] = { &a0, &a1, &a2 };

static uint8_t lit_tile[ 8 ] = { 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF };

void main( void ) {
    uint8_t r, c;

    zx_cls();
    jsp_init( lit_tile, 0x38 );

    for ( r = 0; r < 24; r++ )
        for ( c = 0; c < 32; c++ )
            jsp_draw_background_tile( r, c, lit_tile );

    // park LOAD sprites cell-aligned vertically (ypos % 8 == 0) with a clear gap
    // below each so the cell-row beneath is visible background.
    for ( r = 0; r < NUM_SPRITES; r++ )
        jsp_draw_sprite( spr[ r ], 24 + r * 48, 16 + r * 32 );

    jsp_redraw();

    for ( ;; ) ;
}
