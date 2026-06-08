// JSP-CPC Phase 7 regression test — masked, sub-byte-shifted Mode 0 sprites
// over a multi-colour wireframe grid on a black background.
//
// Mode 0 is 2 px/byte (4 bits/pixel, 16 colours), 160 px wide -> 80 byte-cols.
// The background is black (pen 0) with a 16x16-px wireframe grid whose lines
// cycle through the colour pens (2..15); each 16x16 square is one colour.  The
// white/black MASK2 balls bounce over it (pen 0 = black body, pen 1 = white),
// so the masked rim shows the grid through.  A single shift phase (xrot 0/1)
// exercises the odd/even interleave shift table + the shared table-driven kernels.
//
// 16x16-px grid squares = 8 byte-cols x 2 cell-rows (cells are 2 px wide, 8 px
// tall): a vertical line sits in cells where col%8==0, a horizontal line where
// row%2==0.  The ball asset is the Mode-0 re-encoding of the 2-colour source art
// (cols=8, 2 px/cell).
//
// Build:  make cpc-sprite-mode0   then verify in cap32 (make run-cpc-sprite-mode0).

#include <stdint.h>
#include "jsp.h"

extern uint8_t test_sprite_mask2_m0_pixels[];
// Multicolour ball (many-pen Mode-0 asset) + its emitted Gate-Array palette
// (tools/gfxgen.pl --platform cpc --multicolor --palette-symbol).  The 16-pen screen palette is
// programmed straight from this array, so the ball's rainbow body shows in its
// true colours and the wireframe grid (pens 2..15) reuses the same palette.
extern uint8_t ball_m0_pixels[];
extern uint8_t ball_m0_palette[];

#define NUM_SPRITES 5
#ifdef TIME_LIMITED
#if TIME_LIMITED > 65535
#error "TIME_LIMITED must be <= 65535 (the redraw-cycle counter is uint16_t)"
#endif
#define ANIM_FRAMES TIME_LIMITED   // perf harness: run exactly N redraw cycles, then rst 0
#else
#define ANIM_FRAMES 240
#endif

// 16x16 ball = 8 Mode-0 cols x 2 rows (2 px/cell).
DEFINE_SPRITE( sprite0, 16, 16, test_sprite_mask2_m0_pixels, 0, 0, JSP_TYPE_MASK2 );
DEFINE_SPRITE( sprite1, 16, 16, test_sprite_mask2_m0_pixels, 0, 0, JSP_TYPE_MASK2 );
DEFINE_SPRITE( sprite2, 16, 16, test_sprite_mask2_m0_pixels, 0, 0, JSP_TYPE_MASK2 );
DEFINE_SPRITE( sprite3, 16, 16, test_sprite_mask2_m0_pixels, 0, 0, JSP_TYPE_MASK2 );
// multicolour ball — bounces around the scene like the mono balls
DEFINE_SPRITE( mcball,  16, 16, ball_m0_pixels,             0, 0, JSP_TYPE_MASK2 );

struct {
    uint16_t x;             // 0..159 (Mode-0 screen is 160 px wide)
    uint8_t  y;
    int8_t   dx, dy;
    struct jsp_sprite_s *sp;
} mover[ NUM_SPRITES ] = {
    {  10,  10,  1,  1, &sprite0 },    // slow: 1 px/frame -> shows sub-pixel positioning
    {  70,  40, -1,  3, &sprite1 },
    { 110,  90,  3, -1, &sprite2 },
    { 140,  20, -2, -2, &sprite3 },
    {  72,  88,  2, -3, &mcball  },    // moving multicolour ball
};

// Wireframe tiles per pen, built at run time: a vertical line (left edge), a
// horizontal line (top scanlines), and the corner (both).  Plus a black cell.
// Same multicolour 16x16-px grid in both models; the cell byte-size differs:
// byte-cell = 2-px cells (80x25, 8-byte tiles); pixel-cell = 8-px cells (20x25,
// 32-byte COLUMN-MAJOR tiles = 4 byte-cols x 8 lines).
#ifdef JSP_CELL_MODEL_PIXEL
static uint8_t vline_tile[16][32];
static uint8_t hline_tile[16][32];
static uint8_t corner_tile[16][32];
static uint8_t tile_black[32] = { 0 };
#else
static uint8_t vline_tile[16][8];
static uint8_t hline_tile[16][8];
static uint8_t corner_tile[16][8];
static uint8_t tile_black[8] = { 0,0,0,0,0,0,0,0 };
#endif

// Mode-0 byte with pixel 0 = pen p0, pixel 1 = pen p1.  Plane q of cell-pixel cp
// sits at bit (7-cp) - 2q: px0 -> bits 7,5,3,1 ; px1 -> bits 6,4,2,0.
static uint8_t m0_cell( uint8_t p0, uint8_t p1 ) {
    uint8_t b = 0, q;
    for ( q = 0; q < 4; q++ ) {
        if ( p0 & ( 1 << q ) ) b |= ( 1 << ( 7 - 2 * q ) );
        if ( p1 & ( 1 << q ) ) b |= ( 1 << ( 6 - 2 * q ) );
    }
    return b;
}

// Set Mode 0 + program all 16 pens straight from the multicolour ball's emitted
// palette (gfxgen.pl --platform cpc --palette-symbol _ball_m0_palette); both ROMs off
// (0x8C = RMR mode 0, ROMs off).
static void cpc_setup_mode0( void ) {
    __asm
    di
    ld hl,_ball_m0_palette
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
    uint8_t  r, c, p, i;
    uint16_t f;

    cpc_setup_mode0();

#ifdef JSP_CELL_MODEL_PIXEL
    // Pixel-cell wireframe tiles (32-byte COLUMN-MAJOR, 4 byte-cols x 8 lines).
    // Same 16x16-px grid as byte-cell, drawn pixel-identically: a vertical line is
    // the left 2-px byte-column (full height); a horizontal line is the top 3
    // scanlines across all 4 byte-cols; the corner is both.
    for ( p = 0; p < 16; p++ ) {
        uint8_t full = m0_cell( p, p );     // full 2-px byte-column = pen p
        for ( c = 0; c < 4; c++ )           // byte-column 0..3
            for ( i = 0; i < 8; i++ ) {     // line 0..7
                uint8_t idx = c * 8 + i;
                vline_tile[ p ][ idx ]  = ( c == 0 )           ? full : 0;
                hline_tile[ p ][ idx ]  = ( i < 3 )            ? full : 0;
                corner_tile[ p ][ idx ] = ( c == 0 || i < 3 )  ? full : 0;
            }
    }

    jsp_init( tile_black, 0 );

    // 16x16-px wireframe grid: vertical line every 2 cells (16 px), horizontal
    // every 2 rows; each 16x16 square (gx=col/2, gy=row/2) cycles pen 2..15.
    for ( r = 0; r < JSP_GRID_ROWS; r++ )           // 25
        for ( c = 0; c < JSP_GRID_COLS; c++ ) {     // 20 (pixel-cell M0)
            uint8_t pen = 2 + ( ( ( c >> 1 ) + ( r >> 1 ) ) % 14 );
            uint8_t vl  = ( ( c & 1 ) == 0 );
            uint8_t hl  = ( ( r & 1 ) == 0 );
            uint8_t *t  = tile_black;
            if ( vl && hl ) t = corner_tile[ pen ];
            else if ( vl )  t = vline_tile[ pen ];
            else if ( hl )  t = hline_tile[ pen ];
            jsp_draw_background_tile( r, c, t );
        }
#else
    // build the per-pen wireframe tiles.  Thicker lines: the vertical line fills
    // the whole 2-px cell (2x the 1-px line), the horizontal line is 3 scanlines
    // tall (3x), and an intersection is a solid cell.
    for ( p = 0; p < 16; p++ ) {
        uint8_t full = m0_cell( p, p );     // full 2-px-wide cell column = pen p
        for ( i = 0; i < 8; i++ ) {
            vline_tile[ p ][ i ]  = full;
            hline_tile[ p ][ i ]  = ( i < 3 ) ? full : 0;
            corner_tile[ p ][ i ] = full;
        }
    }

    jsp_init( tile_black, 0 );

    // 16x16-px wireframe grid: vertical line every 8 cols, horizontal every 2
    // rows; each square (gx=col/8, gy=row/2) gets one cycling colour pen 2..15.
    for ( r = 0; r < 25; r++ )
        for ( c = 0; c < 80; c++ ) {
            uint8_t pen = 2 + ( ( ( c >> 3 ) + ( r >> 1 ) ) % 14 );
            uint8_t vl  = ( ( c & 7 ) == 0 );
            uint8_t hl  = ( ( r & 1 ) == 0 );
            uint8_t *t  = tile_black;
            if ( vl && hl ) t = corner_tile[ pen ];
            else if ( vl )  t = vline_tile[ pen ];
            else if ( hl )  t = hline_tile[ pen ];
            jsp_draw_background_tile( r, c, t );
        }
#endif

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
    rst 0          ; perf harness: cap32 CAP32_WAITBREAK stops the emulator here
    __endasm;
#else
    for ( ;; ) ;
#endif
}
