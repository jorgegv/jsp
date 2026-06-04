// JSP-CPC bottom-line artifact regression test (Task 2, 2026-06-04).
//
// Guards the "yrot==0 spurious bottom cell-row" bug (lib/cpc/jsp_frame.asm:
// r1 = r0 + (yrot ? rows : rows-1)).  When a sprite is cell-aligned vertically
// (ypos % 8 == 0) the engine used to composite ONE extra cell-row below it.
//
// We use LOAD1 (opaque) sprites on a fully-lit background: the spurious row's
// graphic is the column's blank trailing pad, so for a LOAD sprite it ERASES a
// whole cell-row of background -> a black gap one cell-row below the sprite.
// (A MASK sprite only shows the single overflow scanline, which is too small /
// position-dependent to be a reliable regression — hence LOAD here.)
//
// A CORRECT frame shows the lit background intact directly below every sprite.
//
// Built once per CPC mode (-DCPC_MODE<N>), mode picks the matching LOAD asset:
//   make cpc-artifact-mode2 / -mode1 / -mode0 / -mode1-mono
// then screenshot and compare against tests/refs/cpc/artifact/.

#include <stdint.h>
#include "jsp.h"

#if defined(CPC_MODE0) || defined(CPC_MODE0_FAST)
  extern uint8_t test_sprite_load1_m0_pixels[];
  #define LOAD_PIX   test_sprite_load1_m0_pixels    // Mode-0 re-encoded ball
  #define SPR_COLS   8
#elif ( defined(CPC_MODE1) || defined(CPC_MODE1_FAST) ) && !defined(CPC_MODE1_MONO)
  extern uint8_t test_sprite_load1_m1_pixels[];
  #define LOAD_PIX   test_sprite_load1_m1_pixels    // Mode-1 two-nibble-plane ball
  #define SPR_COLS   4
#else   /* CPC_MODE2 / CPC_MODE2_FAST / CPC_MODE1_MONO: plain 1bpp */
  extern uint8_t test_sprite_load1_pixels[];
  #define LOAD_PIX   test_sprite_load1_pixels       // 1bpp (Mode-2 format) ball
  #define SPR_COLS   2
#endif

#define NUM_SPRITES 3

DEFINE_SPRITE( s0, 2, SPR_COLS, LOAD_PIX, 0, 0, JSP_TYPE_LOAD1 );
DEFINE_SPRITE( s1, 2, SPR_COLS, LOAD_PIX, 0, 0, JSP_TYPE_LOAD1 );
DEFINE_SPRITE( s2, 2, SPR_COLS, LOAD_PIX, 0, 0, JSP_TYPE_LOAD1 );

static struct jsp_sprite_s *spr[ NUM_SPRITES ] = { &s0, &s1, &s2 };

// Lit background tile: a whole cell of set pixels (read as JSP_CELL_BYTES; 32 is
// the largest cell — pixel-cell Mode 0 — and covers every mode/model).
static uint8_t lit_tile[ 32 ];

// RMR per mode (mode bits + both ROMs off, 0x8C/0x8D/0x8E); pen0 = black,
// pens 1..15 = white, so lit bg (high pens) is white and an erased cell (pen0)
// is a black gap — maximum contrast for the artifact.
#if defined(CPC_MODE0) || defined(CPC_MODE0_FAST)
  #define RMR_BYTE 0x8c
#elif defined(CPC_MODE1) || defined(CPC_MODE1_FAST) || defined(CPC_MODE1_MONO)
  #define RMR_BYTE 0x8d
#else
  #define RMR_BYTE 0x8e
#endif

static uint8_t rmr_byte = RMR_BYTE;

static void cpc_setup( void ) {
    __asm
    di
    ld bc,0x7f00
    ld e,0                  ; pen index 0..15
pal_loop:
    out (c),e
    ld a,0x54               ; default = black (pen 0)
    ld d,a
    ld a,e
    or a
    jr z,pal_set            ; pen 0 -> black
    ld d,0x4b               ; pens 1..15 -> bright white
pal_set:
    ld a,d
    out (c),a
    inc e
    ld a,e
    cp 16
    jr nz,pal_loop
    ld bc,0x7f00
    ld a,(_rmr_byte)
    out (c),a
    __endasm;
}

void main( void ) {
    uint8_t r, c;

    cpc_setup();

    for ( r = 0; r < 32; r++ )
        lit_tile[ r ] = 0xFF;

    jsp_init( lit_tile, 0 );

    // fully-lit background
    for ( r = 0; r < JSP_GRID_ROWS; r++ )
        for ( c = 0; c < JSP_GRID_COLS; c++ )
            jsp_draw_background_tile( r, c, lit_tile );

    // park LOAD sprites cell-aligned vertically (ypos % 8 == 0) at distinct rows,
    // with a clear gap below each so the cell-row beneath is visible background.
    for ( r = 0; r < NUM_SPRITES; r++ )
        jsp_draw_sprite( spr[ r ], (uint16_t)( 16 + r * 56 ), (uint8_t)( 16 + r * 32 ) );

    jsp_redraw();

    for ( ;; ) ;
}
