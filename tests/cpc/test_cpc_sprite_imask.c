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
// pen2=background.  -DBG_RED makes the background bright red (else bright cyan).
// Programmed straight to the GA (ROMs off).
#ifdef BG_RED
#define PEN2_INK 0x4c                /* bright red */
#else
#define PEN2_INK 0x53                /* bright cyan */
#endif
static const uint8_t pal[3] = { 0x54, 0x4b, PEN2_INK };

// Ball sprites (16x16) — count is NBALLS (default 8); a clustered HEAVY layout
// (-DHEAVY) stacks them so each covered cell composites many sprites, making the
// covered-cell kernel dominate the frame (upper-bound kernel benchmark).
#ifndef NBALLS
#define NBALLS 8
#endif
static struct jsp_sprite_s balls[ NBALLS ];

// xorshift-16 PRNG for the demo's random START conditions (position + velocity).
// Seeded from the Z80 R (refresh) register at startup so each run differs.
static uint16_t rng = 0xA5C3;
static uint16_t rnd( void ) {
    rng ^= rng << 7;
    rng ^= rng >> 9;
    rng ^= rng << 8;
    return rng;
}

// Play-field bounds (pixels): screen is JSP_GRID_COLS*8 wide, 200 tall; keep the
// 16x16 sprite fully on-screen.
#define XMAX ( JSP_GRID_COLS * 8 - 16 )
#define YMAX ( 200 - 16 )

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

// The transparent draw call differs only by the type wrapper; in a _IMASK build
// it's the imask wrapper, otherwise the generic (type set via the descriptor).
#if defined( CPC_MODE0_IMASK ) || defined( CPC_MODE1_IMASK )
#define DRAW(sp,xx,yy) jsp_draw_sprite_imask( (sp), (xx), (yy) )
#else
#define DRAW(sp,xx,yy) jsp_draw_sprite( (sp), (xx), (yy) )
#endif

// Per-ball position.  HEAVY: a tight cluster (6 px apart) so the balls overlap
// heavily and each covered cell composites many sprites — kernel-dominated, the
// upper bound of the kernel speedup.  Default: a spread row/grid at successive X
// so every sub-byte xrot phase is exercised without inter-sprite overlap.
#ifdef HEAVY
#define BX(i) ( 40 + ( (i) & 3 ) * 6 )
#define BY(i) ( 40 + ( (i) >> 2 ) * 6 )
#else
#ifndef BALLX0
#define BALLX0 20
#endif
#ifndef BALLSTEP
#define BALLSTEP 25                          // odd step -> walks all xrot phases
#endif
#define BX(i) ( BALLX0 + (i) * BALLSTEP )
#define BY(i) ( 50 + ( (i) & 1 ) * 60 )
#endif

void main( void ) {
    uint8_t i, r, c;

    cpc_setup();

    for ( i = 0; i < JSP_CELL_BYTES; i++ ) tile_bg[ i ] = BG_BYTE;
    jsp_init( tile_bg, 0 );

    for ( r = 0; r < JSP_GRID_ROWS; r++ )
        for ( c = 0; c < JSP_GRID_COLS; c++ )
            jsp_draw_background_tile( r, c, tile_bg );

    for ( i = 0; i < NBALLS; i++ ) {            // init the ball descriptors
        balls[i].rows = JSP_SPRITE_ROWS( 16 );
        balls[i].cols = JSP_SPRITE_COLS( 16 );
        balls[i].pixels = BALL;
        balls[i].type_ptr = BALLTYPE;
        balls[i].flags.initialized = 1;
    }

#ifdef ANIMATE
    // Demo: each ball starts at a RANDOM position with a RANDOM velocity
    // (1..4 px/cycle on each axis, random sign), then bounces off the screen
    // edges.  Runs forever — run it live to watch the motion.
    {
        static int16_t bx[ NBALLS ], by[ NBALLS ], dx[ NBALLS ], dy[ NBALLS ];

        __asm                       ; seed the PRNG from the R (refresh) register
        ld a,r
        ld (_rng),a
        __endasm;

        for ( i = 0; i < NBALLS; i++ ) {
            bx[i] = rnd() % ( XMAX + 1 );
            by[i] = rnd() % ( YMAX + 1 );
            dx[i] = ( rnd() & 3 ) + 1;  if ( rnd() & 1 ) dx[i] = -dx[i];   // ±1..4
            dy[i] = ( rnd() & 3 ) + 1;  if ( rnd() & 1 ) dy[i] = -dy[i];
        }

        for ( ;; ) {
            for ( i = 0; i < NBALLS; i++ ) {
                jsp_move_sprite( &balls[i], (uint16_t) bx[i], (uint8_t) by[i] );
                bx[i] += dx[i];
                if ( bx[i] < 0 )    { bx[i] = 0;    dx[i] = -dx[i]; }
                else if ( bx[i] > XMAX ) { bx[i] = XMAX; dx[i] = -dx[i]; }
                by[i] += dy[i];
                if ( by[i] < 0 )    { by[i] = 0;    dy[i] = -dy[i]; }
                else if ( by[i] > YMAX ) { by[i] = YMAX; dy[i] = -dy[i]; }
            }
            jsp_redraw();
        }
    }
#elif defined( TIME_LIMITED )
    // Perf harness: re-draw all sprites (marks their cells dirty) and recomposite
    // for exactly TIME_LIMITED frames, then rst 0.  Same scene whether built as
    // _IMASK (imask kernel) or plain (MASK2 kernel) — a fair head-to-head.
    {
        uint16_t f;
        for ( f = 0; f < TIME_LIMITED; f++ ) {
            for ( i = 0; i < NBALLS; i++ )
                DRAW( &balls[i], BX(i), BY(i) );
            jsp_redraw();
        }
    }
    __asm
    di
    rst 0
    __endasm;
#else
    for ( i = 0; i < NBALLS; i++ )
        DRAW( &balls[i], BX(i), BY(i) );
    jsp_redraw();
    for ( ;; ) ;
#endif
}
