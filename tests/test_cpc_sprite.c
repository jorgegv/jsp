// JSP-CPC Phase 3 test — masked, sub-byte-shifted Mode 2 sprites over a
// textured background.
//
// Sets CPC Mode 2 (full RAM, both ROMs off) + a black/white palette, inits
// JSP, paints a striped background grid, then animates several MASK2 balls for
// a fixed number of frames and settles into a still final frame.  Exercises the
// full Phase-3 sprite path: deferred move (old-footprint dirtying -> no trails),
// the per-frame precompute, the covered-cell compositor and the verbatim 1bpp
// Mode-2 shift kernels (sub-byte X positions -> pixel-rotated masking).
//
// Coordinates are 8-bit for this milestone (left ~256 px / 32 cells), matching
// the ZX test_sprite_move range.  Reuses the ZX 1bpp mask2 sprite asset
// (Mode 2 is 1bpp-linear — identical byte format).
//
// Build:  make cpc-sprite      then verify in cap32 (make run-cpc-sprite).

#include <stdint.h>
#include "jsp.h"

extern uint8_t test_sprite_mask2_pixels[];

#define NUM_SPRITES 5
#define ANIM_FRAMES 240

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
    {  40,  10,  3,  2, &sprite0 },
    { 200,  40, -2,  3, &sprite1 },
    { 340,  90,  4, -1, &sprite2 },
    { 470,  20, -3, -2, &sprite3 },
    { 590,  70,  1,  4, &sprite4 },
};

static uint8_t tile_stripe[8] = { 0xAA,0x55,0xAA,0x55,0xAA,0x55,0xAA,0x55 };
static uint8_t tile_blank[8]  = { 0,0,0,0,0,0,0,0 };

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
    uint8_t  r, c;
    uint16_t f;

    cpc_setup_mode2();
    jsp_init( tile_blank, 0 );

    (void)tile_blank;
    // striped background across the full 80x25 grid (texture under the balls)
    for ( r = 0; r < 25; r++ )
        for ( c = 0; c < 80; c++ )
            jsp_draw_background_tile( r, c, tile_stripe );

    // animate for a fixed number of frames, bouncing across the FULL 640px
    // Mode-2 screen (16-bit X), then settle into a clean final frame.
    for ( f = 0; f < ANIM_FRAMES; f++ ) {
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

    for ( ;; ) ;
}
