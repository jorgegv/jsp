// JSP-CPC Phase 3 regression test — masked, sub-byte-shifted Mode 2 sprites
// over a textured background.
//
// Sets CPC Mode 2 (full RAM, both ROMs off) + a black/white palette, inits
// JSP, paints a crossbar (grid) background, then animates several MASK2 balls for
// a fixed number of frames and settles into a still final frame (deterministic
// for screenshots).  Exercises the full Phase-3 sprite path: deferred move
// (old-footprint dirtying -> no trails), the per-frame precompute, the
// covered-cell compositor and the verbatim 1bpp Mode-2 shift kernels (sub-byte
// X positions -> pixel-rotated masking).
//
// X is 16-bit (full 640px Mode-2 screen); Y is 8-bit.  Reuses the ZX 1bpp mask2
// sprite asset (Mode 2 is 1bpp-linear — identical byte format).
//
// Build:  make cpc-sprite      then verify in cap32 (make run-cpc-sprite).
// For a continuous (non-settling) version to watch live, see
// tests/cpc/test_cpc_sprite_demo.c  (make cpc-sprite-demo-mode2).

#include <stdint.h>
#include "jsp.h"

extern uint8_t test_sprite_mask2_pixels[];

#define NUM_SPRITES 5
#ifdef TIME_LIMITED
#if TIME_LIMITED > 65535
#error "TIME_LIMITED must be <= 65535 (the redraw-cycle counter is uint16_t)"
#endif
#define ANIM_FRAMES TIME_LIMITED   // perf harness: run exactly N redraw cycles, then rst 0
#else
#define ANIM_FRAMES 240
#endif

DEFINE_SPRITE( sprite0, 16, 16, test_sprite_mask2_pixels, 0, 0, JSP_TYPE_MASK2 );
DEFINE_SPRITE( sprite1, 16, 16, test_sprite_mask2_pixels, 0, 0, JSP_TYPE_MASK2 );
DEFINE_SPRITE( sprite2, 16, 16, test_sprite_mask2_pixels, 0, 0, JSP_TYPE_MASK2 );
DEFINE_SPRITE( sprite3, 16, 16, test_sprite_mask2_pixels, 0, 0, JSP_TYPE_MASK2 );
DEFINE_SPRITE( sprite4, 16, 16, test_sprite_mask2_pixels, 0, 0, JSP_TYPE_MASK2 );

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

// Crossbar / graph-paper grid: top edge + left edge, so a uniform fill draws a
// grid of 8x8 boxes (horizontal + vertical lines every 8 px).  Calmer under
// motion than a fine stripe (the unsynced blit tears less visibly, §5.1).
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
    uint8_t  r, c;
    uint16_t f;

    cpc_setup_mode2();
    jsp_init( tile_blank, 0 );

    (void)tile_blank;
    // crossbar grid background across the full 80x25 grid (texture under the balls)
    for ( r = 0; r < 25; r++ )
        for ( c = 0; c < 80; c++ )
            jsp_draw_background_tile( r, c, tile_grid );

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

#ifdef TIME_LIMITED
    __asm
    di
    rst 0          ; perf harness: cap32 CAP32_WAITBREAK stops the emulator here
    __endasm;
#else
    for ( ;; ) ;
#endif
}
