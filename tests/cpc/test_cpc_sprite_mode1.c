// JSP-CPC Phase 6 regression test — masked, sub-byte-shifted Mode 1 sprites
// over a 4-colour textured background.
//
// Mode 1 is 4 px/byte (2 bits/pixel, two interleaved nibble-planes), 320 px
// wide -> 80 byte-columns.  This is the Mode-1 analogue of test_cpc_sprite.c:
// it sets CPC Mode 1 + a 4-pen palette, inits JSP, paints a cyan crossbar-grid
// background (a Mode-1-only colour), then animates MASK2 balls and
// settles into a still final frame (deterministic for screenshots).
//
// The ball asset is the Mode-1 two-nibble-plane re-encoding of the same source
// art (tools/cpcgfx.pl): a 16-px-wide ball is 4 Mode-1 cells wide, so the sprite
// descriptors use cols=4 (vs cols=2 in Mode 2).  Sub-byte X positions exercise
// the Mode-1 nibble shift table + the shared table-driven kernels.
//
// Build:  make cpc-sprite-mode1   then verify in cap32 (make run-cpc-sprite-mode1).

#include <stdint.h>
#include "jsp.h"

extern uint8_t test_sprite_mask2_m1_pixels[];

#define NUM_SPRITES 5
#ifdef TIME_LIMITED
#define ANIM_FRAMES TIME_LIMITED   // perf harness: run exactly N redraw cycles, then rst 0
#else
#define ANIM_FRAMES 240
#endif

// 16x16 ball = 4 Mode-1 cols x 2 rows (8 px tall/cell).
DEFINE_SPRITE( sprite0, 2, 4, test_sprite_mask2_m1_pixels, 0, 0, JSP_TYPE_MASK2 );
DEFINE_SPRITE( sprite1, 2, 4, test_sprite_mask2_m1_pixels, 0, 0, JSP_TYPE_MASK2 );
DEFINE_SPRITE( sprite2, 2, 4, test_sprite_mask2_m1_pixels, 0, 0, JSP_TYPE_MASK2 );
DEFINE_SPRITE( sprite3, 2, 4, test_sprite_mask2_m1_pixels, 0, 0, JSP_TYPE_MASK2 );
DEFINE_SPRITE( sprite4, 2, 4, test_sprite_mask2_m1_pixels, 0, 0, JSP_TYPE_MASK2 );

struct {
    uint16_t x;             // 0..319 (Mode-1 screen is 320 px wide)
    uint8_t  y;
    int8_t   dx, dy;
    struct jsp_sprite_s *sp;
} mover[ NUM_SPRITES ] = {
    {  20,  10,  1,  1, &sprite0 },    // slow: 1 px/frame -> shows sub-pixel positioning
    { 100,  40, -2,  3, &sprite1 },
    { 170,  90,  4, -1, &sprite2 },
    { 240,  20, -3, -2, &sprite3 },
    { 295,  70,  1,  4, &sprite4 },
};

// Crossbar / graph-paper grid in cyan (pen2) on black (pen0).  Mode-1 cells are
// only 4 px wide, so two tiles alternate per column to space the vertical lines
// every 8 px (every other cell): tile_grid_a carries the vertical line, _b only
// the shared horizontal top line.  Mode-1 pen2 = binary 10 -> plane-1 bit only:
//   top row, 4 px pen2 = low nibble all set = 0x0F
//   left px pen2       = plane-1 bit (3-0) = 0x08
// Calmer under motion than the old per-pixel 4-colour bars, and still shows a
// Mode-1-only colour (cyan) the ball/Mode-2 cannot.
static uint8_t tile_grid_a[8] = { 0x0F, 0x08,0x08,0x08,0x08,0x08,0x08,0x08 };
static uint8_t tile_grid_b[8] = { 0x0F, 0x00,0x00,0x00,0x00,0x00,0x00,0x00 };
static uint8_t tile_blank[8]  = { 0,0,0,0,0,0,0,0 };

// Set Mode 1 + a 4-pen palette; both ROMs off (0x8D = RMR mode 1, ROMs off) so
// 0x0000-0xBFFF is RAM (code at 0x1200 stays visible).
static void cpc_setup_mode1( void ) {
    __asm
    di
    ld bc,0x7f00
    ld a,0x00
    out (c),a
    ld a,0x54          ; pen0 = black   (paper)
    out (c),a
    ld a,0x01
    out (c),a
    ld a,0x4b          ; pen1 = bright white  (ball / bar 1)
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

    // cyan crossbar grid across the full 80x25 grid (vertical line every 8 px)
    for ( r = 0; r < 25; r++ )
        for ( c = 0; c < 80; c++ )
            jsp_draw_background_tile( r, c, ( c & 1 ) ? tile_grid_b : tile_grid_a );

    // animate for a fixed number of frames, bouncing across the 320px screen,
    // then settle into a clean final frame.
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

#ifdef TIME_LIMITED
    __asm
    di
    rst 0          ; perf harness: cap32 CAP32_WAITBREAK stops the emulator here
    __endasm;
#else
    for ( ;; ) ;
#endif
}
