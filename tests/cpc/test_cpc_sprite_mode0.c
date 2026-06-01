// JSP-CPC Phase 7 regression test — masked, sub-byte-shifted Mode 0 sprites
// over a 16-colour background.
//
// Mode 0 is 2 px/byte (4 bits/pixel, 16 colours), 160 px wide -> 80 byte-cols.
// To show the full Mode-0 palette this paints a 4x4 grid of solid colour blocks
// (all 16 pens), then animates MASK2 balls over it and settles to a still frame.
// A single shift phase (xrot 0/1) exercises the odd/even interleave shift table
// + the shared table-driven kernels.
//
// The ball asset is the Mode-0 odd/even-interleave re-encoding of the same
// (2-colour) source art (tools/cpcgfx.pl --mode 0): a 16-px-wide ball is 8
// Mode-0 cells wide, so the sprite descriptors use cols=8 (2 px/cell).  The
// 16 colours come from the background; the ball stays pen 0/1.
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

// 16-pen palette (gate-array hardware ink values, 0x40 | hw).  The standard CPC
// firmware ink->hardware mapping for pens 0..15, giving 16 distinct colours.
static uint8_t palette_inks[16] = {
    0x54, 0x44, 0x55, 0x5C, 0x58, 0x5D, 0x4C, 0x45,
    0x4D, 0x56, 0x46, 0x57, 0x5E, 0x40, 0x4E, 0x4B
};

// One solid-pen Mode-0 tile per pen (8 identical bytes); built at run time.
static uint8_t tiles16[16][8];
static uint8_t tile_blank[8] = { 0,0,0,0,0,0,0,0 };

// Solid Mode-0 byte for pen P (both pixels = P).  Plane q of cell-pixel cp sits
// at bit (7-cp) - q*2: px0 -> bits 7,5,3,1 ; px1 -> bits 6,4,2,0 (planes 0..3).
static uint8_t m0_solid( uint8_t pen ) {
    uint8_t b = 0, q;
    for ( q = 0; q < 4; q++ )
        if ( pen & ( 1 << q ) ) {
            b |= ( 1 << ( 7 - 2 * q ) );    // pixel 0, plane q
            b |= ( 1 << ( 6 - 2 * q ) );    // pixel 1, plane q
        }
    return b;
}

// Set Mode 0 + program all 16 pens; both ROMs off (0x8C = RMR mode 0, ROMs off).
static void cpc_setup_mode0( void ) {
    __asm
    di
    ld hl,_palette_inks
    ld e,0                  ; pen index 0..15
pal_loop:
    ld bc,0x7f00
    out (c),e               ; select pen E
    ld a,(hl)
    out (c),a               ; set its ink
    inc hl
    inc e
    ld a,e
    cp 16
    jr nz,pal_loop
    ld bc,0x7f00
    ld a,0x8c               ; RMR: mode 0, both ROMs OFF (full RAM)
    out (c),a
    __endasm;
}

void main( void ) {
    uint8_t  r, c, pen;
    uint16_t f;

    cpc_setup_mode0();

    for ( pen = 0; pen < 16; pen++ ) {
        uint8_t b = m0_solid( pen ), i;
        for ( i = 0; i < 8; i++ ) tiles16[ pen ][ i ] = b;
    }

    jsp_init( tile_blank, 0 );

    // 4x4 grid of solid colour blocks across the 80x25 grid: 20 cells x ~6 rows
    // per block, pen = block_row*4 + block_col -> all 16 pens shown.
    for ( r = 0; r < 25; r++ ) {
        uint8_t br = ( r / 6 ); if ( br > 3 ) br = 3;
        for ( c = 0; c < 80; c++ ) {
            uint8_t bc = ( c / 20 ); if ( bc > 3 ) bc = 3;
            jsp_draw_background_tile( r, c, tiles16[ br * 4 + bc ] );
        }
    }

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
