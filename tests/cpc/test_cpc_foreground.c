// JSP-CPC Phase 5 test — foreground tiles + sprite pool (CPC Mode 2).
//
// CPC Mode-2 port of tests/zx/test_foreground_tiles.c: a textured background, a
// foreground band (one horizontal + two vertical bars), and pool-allocated
// MASK2 sprites placed to STRADDLE the bars.  Foreground cells are painted from
// BTT and never composited over, so sprites pass BEHIND them — a sprite over a
// bar is clipped by the bar.  Static placement (no animation) so the occlusion
// is deterministic for the screenshot.
//
// Exercises, on CPC Mode 2: background tiles, foreground tiles (FTT), the sprite
// pool (jsp_sprite_pool_init / jsp_sprite_alloc), and sprite compositing with
// the foreground-behind rule.  Colour is dropped (no attribute RAM on CPC, §6).
//
// Build:  make cpc-foreground    verify:  make run-cpc-foreground

#include <stdint.h>
#include "jsp.h"

extern uint8_t test_sprite_mask2_pixels[];

#define POOL_SIZE 3
static struct jsp_sprite_s pool[POOL_SIZE];

static uint8_t tile_stripe[8] = { 0xAA,0x55,0xAA,0x55,0xAA,0x55,0xAA,0x55 };
static uint8_t tile_blank[8]  = { 0,0,0,0,0,0,0,0 };
static uint8_t tile_box[8]    = { 0xFF,0xFF,0xC3,0xC3,0xC3,0xC3,0xFF,0xFF };

// Mode 2 + black/white palette; both ROMs off (project_cpc_bringup_rmr_rom).
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
    ld a,0x8e          ; RMR: mode 2, both ROMs OFF
    out (c),a
    __endasm;
}

void main( void ) {
    uint8_t r, c, i;
    struct jsp_sprite_s *sp;

    cpc_setup_mode2();
    jsp_init( tile_blank, 0 );
    (void)tile_blank;

    // textured background across the whole 80x25 grid
    for ( r = 0; r < 25; r++ )
        for ( c = 0; c < 80; c++ )
            jsp_draw_background_tile( r, c, tile_stripe );

    // foreground band: one horizontal bar (row 11) + two vertical bars
    // (cols 24, 48) — placed inside the cap32-visible region.
    for ( c = 8; c < 72; c++ )
        jsp_draw_foreground_tile( 11, c, tile_box );
    for ( r = 2; r < 22; r++ ) {
        jsp_draw_foreground_tile( r, 24, tile_box );
        jsp_draw_foreground_tile( r, 48, tile_box );
    }

    // pool-allocated sprites positioned to STRADDLE the foreground bars, so
    // each ball is clipped where it overlaps a bar (sprite passes behind).
    jsp_sprite_pool_init( pool, POOL_SIZE );
    for ( i = 0; i < POOL_SIZE; i++ )
        pool[i].pixels = test_sprite_mask2_pixels;   // ensure a graphic is set

    // ball 0 straddles the horizontal band (row 11 -> y ~88)
    sp = jsp_sprite_alloc( 2, 2 ); if ( sp ) jsp_draw_sprite_mask2( sp, 120, 84 );
    // ball 1 straddles the left vertical bar (col 24 -> x ~192)
    sp = jsp_sprite_alloc( 2, 2 ); if ( sp ) jsp_draw_sprite_mask2( sp, 188, 40 );
    // ball 2 straddles the crossing of band + right vertical bar (col 48,row11)
    sp = jsp_sprite_alloc( 2, 2 ); if ( sp ) jsp_draw_sprite_mask2( sp, 380, 84 );

    jsp_redraw();
#ifdef TIME_LIMITED
    __asm
    di
    rst 0          ; harness: deterministic stop for reproducible screenshots
    __endasm;
#else
    for ( ;; ) ;
#endif
}
