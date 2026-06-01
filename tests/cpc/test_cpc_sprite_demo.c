// JSP-CPC Mode 2 sprite DEMO — masked, sub-byte-shifted balls bouncing
// continuously across the full 640px Mode-2 screen over a striped background.
//
// This is the live-viewing companion to tests/cpc/test_cpc_sprite.c: identical
// setup, but it animates forever (never settles) so there is something to watch
// in the emulator.  The regression test settles into a still frame for
// deterministic screenshots; this one does not.
//
// X is 16-bit (full 640px screen); Y is 8-bit.  Reuses the ZX 1bpp mask2 sprite
// asset (Mode 2 is 1bpp-linear — identical byte format).
//
// Build:  make cpc-sprite-demo-mode2     then run in cap32:
//   cap32 -a 'run"CPCSPRD.' CPCSPRD.dsk

#include <stdint.h>
#include "jsp.h"

extern uint8_t test_sprite_mask2_pixels[];

#define NUM_SPRITES 5

DEFINE_SPRITE( sprite0, 2, 2, test_sprite_mask2_pixels, 0, 0, JSP_TYPE_MASK2 );
DEFINE_SPRITE( sprite1, 2, 2, test_sprite_mask2_pixels, 0, 0, JSP_TYPE_MASK2 );
DEFINE_SPRITE( sprite2, 2, 2, test_sprite_mask2_pixels, 0, 0, JSP_TYPE_MASK2 );
DEFINE_SPRITE( sprite3, 2, 2, test_sprite_mask2_pixels, 0, 0, JSP_TYPE_MASK2 );
DEFINE_SPRITE( sprite4, 2, 2, test_sprite_mask2_pixels, 0, 0, JSP_TYPE_MASK2 );

struct {
    uint16_t x;             // 16-bit X: full 640px Mode-2 screen
    uint8_t  y;
    int8_t   dx, dy;
    struct jsp_sprite_s *sp;
} mover[ NUM_SPRITES ] = {
    {  40,  10,  1,  1, &sprite0 },    // slow: 1 px/frame -> shows sub-pixel positioning
    { 200,  40, -2,  3, &sprite1 },
    { 340,  90,  4, -1, &sprite2 },
    { 470,  20, -3, -2, &sprite3 },
    { 590,  70,  1,  4, &sprite4 },
};

// Crossbar / graph-paper grid (top + left edge -> 8x8-box grid); calmer under
// continuous motion than a fine stripe (the unsynced blit tears less visibly).
static uint8_t tile_grid[8]  = { 0xFF,0x80,0x80,0x80,0x80,0x80,0x80,0x80 };
static uint8_t tile_blank[8] = { 0,0,0,0,0,0,0,0 };

// Set Mode 2 + black(pen0)/white(pen1); both ROMs off (0x8E) so 0x0000-0xBFFF
// is RAM (code at 0x1200 stays visible — project_cpc_bringup_rmr_rom memory).
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
    jsp_init( tile_blank, 0 );

    (void)tile_blank;
    // crossbar grid background across the full 80x25 grid (texture under the balls)
    for ( r = 0; r < 25; r++ )
        for ( c = 0; c < 80; c++ )
            jsp_draw_background_tile( r, c, tile_grid );

    // bounce forever across the full 640px Mode-2 screen (16-bit X)
    for ( ;; ) {
        for ( r = 0; r < NUM_SPRITES; r++ ) {
            jsp_move_sprite( mover[r].sp, mover[r].x, mover[r].y );

            if ( mover[r].x + mover[r].dx > 620 || mover[r].x + mover[r].dx < 4 )
                mover[r].dx = -mover[r].dx;
            mover[r].x += mover[r].dx;

            if ( mover[r].y + mover[r].dy > 170 || mover[r].y + mover[r].dy < 4 )
                mover[r].dy = -mover[r].dy;
            mover[r].y += mover[r].dy;
        }
        jsp_redraw();
    }
}
