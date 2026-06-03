// JSP-CPC Model-B (pixel-cell) Mode 1 sprite test — MASK2 balls over a graph-
// paper background, on the 8x8-PIXEL cell grid (40x25, 16-byte cells).
//
// Same sprite art, count and motion as test_cpc_sprite_mode1.c (the Model-A M1
// test) so the two are directly comparable for the tile-size-model performance
// study; the ONLY difference is the cell model (-DJSP_CELL_MODEL_PIXEL) and the
// resulting 16-byte, column-major background tiles.  The 16-px ball is still 4
// Mode-1 byte-columns (cols=4) — byte-level sprite data is identical between
// models, so the same asset is reused unchanged.
//
// Build:  make cpc-sprite-mode1-pixcell    (forces JSP_CELL_MODEL=pixel, CPC_MODE1)

#include <stdint.h>
#include "jsp.h"

extern uint8_t test_sprite_mask2_m1_pixels[];

#define NUM_SPRITES 5
#ifdef TIME_LIMITED
#if TIME_LIMITED > 65535
#error "TIME_LIMITED must be <= 65535 (the redraw-cycle counter is uint16_t)"
#endif
#define ANIM_FRAMES TIME_LIMITED
#else
#define ANIM_FRAMES 240
#endif

// 16x16 ball = 4 Mode-1 byte-columns x 2 cell-rows.  cols=4 (byte columns).
DEFINE_SPRITE( sprite0, 2, 4, test_sprite_mask2_m1_pixels, 0, 0, JSP_TYPE_MASK2 );
DEFINE_SPRITE( sprite1, 2, 4, test_sprite_mask2_m1_pixels, 0, 0, JSP_TYPE_MASK2 );
DEFINE_SPRITE( sprite2, 2, 4, test_sprite_mask2_m1_pixels, 0, 0, JSP_TYPE_MASK2 );
DEFINE_SPRITE( sprite3, 2, 4, test_sprite_mask2_m1_pixels, 0, 0, JSP_TYPE_MASK2 );
DEFINE_SPRITE( sprite4, 2, 4, test_sprite_mask2_m1_pixels, 0, 0, JSP_TYPE_MASK2 );

struct {
    uint16_t x;
    uint8_t  y;
    int8_t   dx, dy;
    struct jsp_sprite_s *sp;
} mover[ NUM_SPRITES ] = {
    {  20,  10,  1,  1, &sprite0 },
    { 100,  40, -2,  3, &sprite1 },
    { 170,  90,  4, -1, &sprite2 },
    { 240,  20, -3, -2, &sprite3 },
    { 295,  70,  1,  4, &sprite4 },
};

// 8x8 box-outline cell, Mode-1, COLUMN-MAJOR (2 byte-columns x 8 lines = 16 B).
// pen2 (cyan): top line full (0x0F), left edge pixel (0x08) down the left column.
static uint8_t tile_box[16] = {
    0x0F, 0x08,0x08,0x08,0x08,0x08,0x08,0x08,   // col 0 (left screen byte)
    0x0F, 0x00,0x00,0x00,0x00,0x00,0x00,0x00,   // col 1 (right screen byte)
};
static uint8_t tile_blank[16] = { 0 };

static void cpc_setup_mode1( void ) {
    __asm
    di
    ld bc,0x7f00
    ld a,0x00
    out (c),a
    ld a,0x54          ; pen0 = black
    out (c),a
    ld a,0x01
    out (c),a
    ld a,0x4b          ; pen1 = bright white (ball)
    out (c),a
    ld a,0x02
    out (c),a
    ld a,0x4e          ; pen2 = bright cyan (grid)
    out (c),a
    ld a,0x03
    out (c),a
    ld a,0x44          ; pen3 = bright yellow
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

    for ( r = 0; r < JSP_GRID_ROWS; r++ )        // 25
        for ( c = 0; c < JSP_GRID_COLS; c++ )    // 40 (Model B M1)
            jsp_draw_background_tile( r, c, tile_box );

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
    rst 0
    __endasm;
#else
    for ( ;; ) ;
#endif
}
