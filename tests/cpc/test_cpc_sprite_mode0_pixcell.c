// JSP-CPC Model-B (pixel-cell) Mode 0 sprite test — MASK2 balls over a graph-
// paper background, on the 8x8-PIXEL cell grid (20x25, 32-byte cells).
//
// Mode 0 is the extreme case: 2 px/byte, 160 px wide -> 20 pixel-cells/row, and
// a cell is 4 screen bytes (32 bytes incl. 8 lines).  COLS=20 is not a multiple
// of 8, so the DTT is row-aligned (3 bytes/row, 4 dead bits).  Same balls/motion
// as the Model-A M0 test (test_cpc_sprite_mode0.c) for the performance study;
// the 16-px ball is still 8 Mode-0 byte-columns (cols=8), asset reused unchanged.
//
// Build:  make cpc-sprite-mode0-pixcell    (forces JSP_CELL_MODEL=pixel, CPC_MODE0)

#include <stdint.h>
#include "jsp.h"

extern uint8_t test_sprite_mask2_m0_pixels[];

#define NUM_SPRITES 4
#ifdef TIME_LIMITED
#if TIME_LIMITED > 65535
#error "TIME_LIMITED must be <= 65535 (the redraw-cycle counter is uint16_t)"
#endif
#define ANIM_FRAMES TIME_LIMITED
#else
#define ANIM_FRAMES 240
#endif

// 16x16 ball = 8 Mode-0 byte-columns x 2 cell-rows.  cols=8 (byte columns).
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
    {  10,  10,  1,  1, &sprite0 },
    {  70,  40, -1,  3, &sprite1 },
    { 110,  90,  3, -1, &sprite2 },
    { 140,  20, -2, -2, &sprite3 },
};

static uint8_t palette_inks[16] = {
    0x54, 0x4B, 0x44, 0x55, 0x5C, 0x58, 0x5D, 0x4C,
    0x45, 0x4D, 0x56, 0x46, 0x57, 0x5E, 0x40, 0x4E
};

// 8x8-pixel box cell, COLUMN-MAJOR: 4 byte-columns x 8 lines = 32 bytes.
static uint8_t tile_box[32];
static uint8_t tile_blank[32] = { 0 };

// Mode-0 byte with pixel0 = pen p0, pixel1 = pen p1 (interleaved planes).
static uint8_t m0_cell( uint8_t p0, uint8_t p1 ) {
    uint8_t b = 0, q;
    for ( q = 0; q < 4; q++ ) {
        if ( p0 & ( 1 << q ) ) b |= ( 1 << ( 7 - 2 * q ) );
        if ( p1 & ( 1 << q ) ) b |= ( 1 << ( 6 - 2 * q ) );
    }
    return b;
}

static void cpc_setup_mode0( void ) {
    __asm
    di
    ld hl,_palette_inks
    ld e,0
pal_loop:
    ld bc,0x7f00
    out (c),e
    ld a,(hl)
    out (c),a
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
    uint8_t  r, c, i;
    uint16_t f;

    cpc_setup_mode0();

    // Build the 32-byte column-major box tile: pen-2 top edge across all 4
    // byte-columns (line 0 full), pen-2 left edge down byte-column 0.
    {
        uint8_t full = m0_cell( 2, 2 );     // both pixels pen 2
        uint8_t left = m0_cell( 2, 0 );     // left pixel pen 2, right pen 0
        for ( c = 0; c < 4; c++ )           // 4 byte-columns
            for ( i = 0; i < 8; i++ )       // 8 lines
                tile_box[ c * 8 + i ] =
                    ( i == 0 ) ? full : ( c == 0 ? left : 0 );
    }

    jsp_init( tile_blank, 0 );

    for ( r = 0; r < JSP_GRID_ROWS; r++ )        // 25
        for ( c = 0; c < JSP_GRID_COLS; c++ )    // 20 (Model B M0)
            jsp_draw_background_tile( r, c, tile_box );

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

#ifdef TIME_LIMITED
    __asm
    di
    rst 0
    __endasm;
#else
    for ( ;; ) ;
#endif
}
