// JSP-CPC Phase 7 regression test — masked, sub-byte-shifted Mode 0 sprites
// over a Mode-0 crossbar-grid background.
//
// Mode 0 is 2 px/byte (4 bits/pixel, 16 colours), 160 px wide -> 80 byte-cols.
// This is the Mode-0 analogue of test_cpc_sprite_mode1.c: it sets CPC Mode 0 + a
// palette, paints a green crossbar grid, then animates MASK2 balls and settles
// to a still frame.  A single shift phase (xrot 0/1) exercises the odd/even
// interleave shift table + the shared table-driven kernels.
//
// The ball asset is the Mode-0 odd/even-interleave re-encoding of the same
// source art (tools/cpcgfx.pl --mode 0): a 16-px-wide ball is 8 Mode-0 cells
// wide, so the sprite descriptors use cols=8 (2 px/cell).
//
// Build:  make cpc-sprite-mode0   then verify in cap32 (make run-cpc-sprite-mode0).

#include <stdint.h>
#include "jsp.h"

extern uint8_t test_sprite_mask2_m0_pixels[];

#define NUM_SPRITES 4
#define ANIM_FRAMES 240

// 16x16 ball = 8 Mode-0 cols x 2 rows (2 px/cell).
DEFINE_SPRITE( sprite0, 2, 8, test_sprite_mask2_m0_pixels, 0, 0, JSP_TYPE_MASK2 );
DEFINE_SPRITE( sprite1, 2, 8, test_sprite_mask2_m0_pixels, 0, 0, JSP_TYPE_MASK2 );
DEFINE_SPRITE( sprite2, 2, 8, test_sprite_mask2_m0_pixels, 0, 0, JSP_TYPE_MASK2 );
DEFINE_SPRITE( sprite3, 2, 8, test_sprite_mask2_m0_pixels, 0, 0, JSP_TYPE_MASK2 );

struct {
    uint16_t x;             // 0..159 (Mode-0 screen is 160 px wide)
    uint8_t  y;
    int8_t   dx, dy;
    struct jsp_sprite_s *sp;
} mover[ NUM_SPRITES ] = {
    {  10,  10,  2,  2, &sprite0 },
    {  70,  40, -1,  3, &sprite1 },
    { 110,  90,  3, -1, &sprite2 },
    { 140,  20, -2, -2, &sprite3 },
};

// Mode-0 crossbar grid in green (pen2).  Cells are 2 px wide, so the vertical
// line is drawn only on every 4th cell (8-px spacing) via the loop; both tiles
// carry the shared green horizontal top line.  Mode-0 pen2 = binary 10 ->
// plane-1 bit: pixel0 plane1 = bit5, pixel1 plane1 = bit4.
//   top row, 2 px pen2 = bits 5,4 = 0x30      left px pen2 = bit5 = 0x20
static uint8_t tile_grid_v[8] = { 0x30, 0x20,0x20,0x20,0x20,0x20,0x20,0x20 };
static uint8_t tile_grid_h[8] = { 0x30, 0x00,0x00,0x00,0x00,0x00,0x00,0x00 };
static uint8_t tile_blank[8]  = { 0,0,0,0,0,0,0,0 };

// Set Mode 0 + palette; both ROMs off (0x8C = RMR mode 0, ROMs off).
static void cpc_setup_mode0( void ) {
    __asm
    di
    ld bc,0x7f00
    ld a,0x00
    out (c),a
    ld a,0x54          ; pen0 = black   (paper / ball body)
    out (c),a
    ld a,0x01
    out (c),a
    ld a,0x4b          ; pen1 = bright white  (ball highlight)
    out (c),a
    ld a,0x02
    out (c),a
    ld a,0x55          ; pen2 = bright green  (grid)
    out (c),a
    ld a,0x8c          ; RMR: mode 0, both ROMs OFF (full RAM)
    out (c),a
    __endasm;
}

void main( void ) {
    uint8_t  r, c;
    uint16_t f;

    cpc_setup_mode0();
    jsp_init( tile_blank, 0 );

    // green crossbar grid: vertical line every 8 px (every 4th 2-px cell)
    for ( r = 0; r < 25; r++ )
        for ( c = 0; c < 80; c++ )
            jsp_draw_background_tile( r, c, ( c & 3 ) ? tile_grid_h : tile_grid_v );

    for ( f = 0; f < ANIM_FRAMES; f++ ) {
        for ( r = 0; r < NUM_SPRITES; r++ ) {
            jsp_move_sprite( mover[r].sp, mover[r].x, mover[r].y );

            if ( mover[r].x + mover[r].dx > 142 || mover[r].x + mover[r].dx < 2 )
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
