// JSP-CPC Phase 6 regression test — masked, sub-byte-shifted Mode 1 sprites
// over a 4-colour textured background.
//
// Mode 1 is 4 px/byte (2 bits/pixel, two interleaved nibble-planes), 320 px
// wide -> 80 byte-columns.  This is the Mode-1 analogue of test_cpc_sprite.c:
// it sets CPC Mode 1 + a 4-pen palette, inits JSP, paints a 4-colour vertical-
// bar background (exercising both bit-planes), then animates MASK2 balls and
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
#define ANIM_FRAMES 240

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
    {  20,  10,  3,  2, &sprite0 },
    { 100,  40, -2,  3, &sprite1 },
    { 170,  90,  4, -1, &sprite2 },
    { 240,  20, -3, -2, &sprite3 },
    { 295,  70,  1,  4, &sprite4 },
};

// 4-colour vertical bars: each byte = pixels (pen0,pen1,pen2,pen3) left-to-right
// in the Mode-1 interleaved encoding (plane0 bit @ 7-p, plane1 bit @ 3-p):
//   p0=pen0=00 -> -      p1=pen1=01 -> bit6
//   p2=pen2=10 -> bit1   p3=pen3=11 -> bit4|bit0   => 0x53
static uint8_t tile_bars[8]  = { 0x53,0x53,0x53,0x53,0x53,0x53,0x53,0x53 };
static uint8_t tile_blank[8] = { 0,0,0,0,0,0,0,0 };

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

    // 4-colour bar background across the full 80x25 grid (texture under balls)
    for ( r = 0; r < 25; r++ )
        for ( c = 0; c < 80; c++ )
            jsp_draw_background_tile( r, c, tile_bars );

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

    for ( ;; ) ;
}
