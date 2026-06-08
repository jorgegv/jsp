// JSP-CPC _IMASK regression test — implicit-mask sprites over a non-black
// background, at every sub-byte X phase.
//
// The implicit-mask modes (CPC_MODE0_IMASK / CPC_MODE1_IMASK) store graph bytes
// only; pen 0 is transparent and the mask is derived from jsp_imask_tbl at
// composite time.  This test draws the 2-colour ball (pen 0 transparent, pen 1
// foreground) at consecutive X positions so every sub-byte xrot phase is
// exercised — the no-rotate, mid, left- and right-border kernels.
//
// It is deliberately STATIC (one jsp_redraw, then halt) and built from the SAME
// source as the plain-mode reference: building with CPC_MODE1 (instead of
// CPC_MODE1_IMASK) selects the MASK2 asset+type, so the two screenshots MUST be
// pixel-identical — that equivalence is the correctness oracle.
//
// The background is a SOLID pen-2 fill, so transparent ball pixels show pen 2 and
// opaque ones show pen 1: a black background could not distinguish transparency
// from an opaque-black draw.

#include <stdint.h>
#include "jsp.h"

// ---- per-mode asset + type + screen mode + background fill -----------------
#if   defined( CPC_MODE1_IMASK )
  extern uint8_t test_sprite_imask_m1_pixels[];
  #define BALL      test_sprite_imask_m1_pixels
  #define BALLTYPE  JSP_TYPE_IMASK
  #define BG_BYTE   0x0f             // pen 2 (plane1 across 4 px)
#elif defined( CPC_MODE1 )          // reference build (MASK2, same art)
  extern uint8_t test_sprite_mask2_m1_pixels[];
  #define BALL      test_sprite_mask2_m1_pixels
  #define BALLTYPE  JSP_TYPE_MASK2
  #define BG_BYTE   0x0f
#elif defined( CPC_MODE0_IMASK )
  extern uint8_t test_sprite_imask_m0_pixels[];
  #define BALL      test_sprite_imask_m0_pixels
  #define BALLTYPE  JSP_TYPE_IMASK
  #define BG_BYTE   0x30             // pen 2 (plane1 across 2 px = bits 5,4)
#elif defined( CPC_MODE0 )          // reference build (MASK2, same art)
  extern uint8_t test_sprite_mask2_m0_pixels[];
  #define BALL      test_sprite_mask2_m0_pixels
  #define BALLTYPE  JSP_TYPE_MASK2
  #define BG_BYTE   0x30
#else
  #error "test_cpc_sprite_imask: build with CPC_MODE0/1 or CPC_MODE0/1_IMASK"
#endif

#if defined( CPC_MODE0_IMASK ) || defined( CPC_MODE0 )
  #define RMR_MODE 0                 // mode 0, both ROMs off -> RMR 0x8e
#else
  #define RMR_MODE 1                 // mode 1, both ROMs off -> RMR 0x8d
#endif

// Oracle build: -DBG_BLACK forces a black (pen 0) background.  Against black the
// pen-0-opaque (MASK2) vs pen-0-transparent (IMASK) difference is invisible, so
// the IMASK and MASK2 renders of the same art MUST be pixel-identical — proving
// the kernel draws opaque (pen 1) pixels exactly like MASK2.  The default cyan
// background instead makes the transparency visible (they differ only in pen 0).
#ifdef BG_BLACK
  #undef  BG_BYTE
  #define BG_BYTE 0x00
#endif

static uint8_t tile_bg[ JSP_CELL_BYTES ];

// Gate-Array ink bytes (0x40 | hw_ink): pen0=black, pen1=bright white,
// pen2=bright cyan.  Programmed straight to the GA (ROMs off).
static const uint8_t pal[3] = { 0x54, 0x4b, 0x53 };

// 16x16 ball, drawn at 8 consecutive X (covers every xrot phase) on two rows.
DEFINE_SPRITE( b0, 16, 16, BALL, 0, 0, BALLTYPE );
DEFINE_SPRITE( b1, 16, 16, BALL, 0, 0, BALLTYPE );
DEFINE_SPRITE( b2, 16, 16, BALL, 0, 0, BALLTYPE );
DEFINE_SPRITE( b3, 16, 16, BALL, 0, 0, BALLTYPE );
DEFINE_SPRITE( b4, 16, 16, BALL, 0, 0, BALLTYPE );
DEFINE_SPRITE( b5, 16, 16, BALL, 0, 0, BALLTYPE );
DEFINE_SPRITE( b6, 16, 16, BALL, 0, 0, BALLTYPE );
DEFINE_SPRITE( b7, 16, 16, BALL, 0, 0, BALLTYPE );

static struct jsp_sprite_s *balls[8] = { &b0,&b1,&b2,&b3,&b4,&b5,&b6,&b7 };

// Program pens 0..2 from pal[], the rest black, then set the mode register.
static void cpc_setup( void ) {
#if RMR_MODE == 0
    #define PEN_COUNT 16
    #define RMR_BYTE  0x8e
#else
    #define PEN_COUNT 4
    #define RMR_BYTE  0x8d
#endif
    __asm
    di
    ld hl,_pal
    ld e,0
pal_lp:
    ld bc,0x7f00
    out (c),e               ; select pen E
    ld a,e
    cp 3
    jr nc,pal_blk
    ld a,(hl)
    inc hl
    jr pal_set
pal_blk:
    ld a,0x54               ; unused pens -> black
pal_set:
    out (c),a
    inc e
    ld a,e
    cp PEN_COUNT
    jr nz,pal_lp
    ld bc,0x7f00
    ld a,RMR_BYTE
    out (c),a
    __endasm;
}

void main( void ) {
    uint8_t i, r, c;
    uint16_t x;

    cpc_setup();

    for ( i = 0; i < JSP_CELL_BYTES; i++ ) tile_bg[ i ] = BG_BYTE;
    jsp_init( tile_bg, 0 );

    for ( r = 0; r < JSP_GRID_ROWS; r++ )
        for ( c = 0; c < JSP_GRID_COLS; c++ )
            jsp_draw_background_tile( r, c, tile_bg );

#ifndef NBALLS
#define NBALLS 8
#endif
#ifndef BALLX0
#define BALLX0 20
#endif
#ifndef BALLSTEP
#define BALLSTEP 25                          // odd step -> walks all xrot phases
#endif
    // Non-overlapping row of balls at successive X so every sub-byte xrot phase
    // is exercised (the NR / mid / lb / rb kernels) without inter-sprite overlap
    // muddying the picture.  Two rows for M0 (more, narrower cells).
    for ( i = 0; i < NBALLS; i++ ) {
        x = BALLX0 + i * BALLSTEP;
#if defined( CPC_MODE0_IMASK ) || defined( CPC_MODE1_IMASK )
        jsp_draw_sprite_imask( balls[i], x, 50 + ( i & 1 ) * 60 );  // wrapper API
#else
        jsp_draw_sprite( balls[i], x, 50 + ( i & 1 ) * 60 );
#endif
    }

    jsp_redraw();

    for ( ;; ) ;
}
