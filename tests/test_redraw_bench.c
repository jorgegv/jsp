// test_redraw_bench — JSP redraw speed benchmark
//
// Headless, host-CPU-independent benchmark for jsp_redraw().  Time is
// measured with the 48K ROM FRAMES counter (sysvar at 0x5C78, bumped by
// the 50 Hz interrupt), so the result is in emulated frames and identical
// run to run regardless of host speed.
//
// Three measurements are printed to the JNEXT magic port as ASCII text
// (one "label=frames" line each):
//
//   A0 : BENCH_FULL_REDRAWS x { mark whole screen dirty }       (calibration)
//   A  : BENCH_FULL_REDRAWS x { mark whole screen dirty; redraw }
//   B  : BENCH_SPRITE_FRAMES x { move 5 sprites; redraw }
//
// Full-screen redraw cost  ~= A - A0  (background-cell path, asm DTT walk).
// Sprite frame cost        ~= B / BENCH_SPRITE_FRAMES (deferred move +
//                             covered-cell compositing).
//
// Run (or just `make bench`):
//   make tests/test_redraw_bench.tap
//   jnext --headless --machine 48k --sd-card <img> \
//         --load tests/test_redraw_bench.tap \
//         --magic-port 0x00FF --magic-port-mode ascii \
//         --delayed-automatic-exit 300

#include <stdint.h>
#include <spectrum.h>
#include <arch/z80.h>
#include <intrinsic.h>

#include "jsp.h"

extern uint8_t test_sprite_mask2_pixels[];
extern uint8_t test_sprite_load1_pixels[];

#define MAGIC_PORT          0x00FF
#define FRAMES_ADDR         0x5C78

#define BENCH_FULL_REDRAWS  200     // Phase A / A0 iterations
#define BENCH_SPRITE_FRAMES 1000    // Phase B iterations
#define NUM_SPRITES         5

DEFINE_SPRITE( bspr0, 2, 2, test_sprite_mask2_pixels, 0, 0, JSP_TYPE_MASK2 );
DEFINE_SPRITE( bspr1, 2, 2, test_sprite_mask2_pixels, 0, 0, JSP_TYPE_MASK2 );
DEFINE_SPRITE( bspr2, 2, 2, test_sprite_load1_pixels, 0, 0, JSP_TYPE_LOAD1 );
DEFINE_SPRITE( bspr3, 2, 2, test_sprite_load1_pixels, 0, 0, JSP_TYPE_LOAD1 );
DEFINE_SPRITE( bspr4, 2, 2, test_sprite_load1_pixels, 0, 0, JSP_TYPE_LOAD1 );

// sprite motion state — file scope, kept off the small Spectrum stack
struct bench_sprite_s {
    uint8_t  x, y;
    int8_t   dx, dy;
    struct jsp_sprite_s *sp;
};

struct bench_sprite_s bench_sprites[ NUM_SPRITES ] = {
    {  20,  24,  3,  2, &bspr0 },
    { 120,  40, -2,  3, &bspr1 },
    { 180,  90,  2, -3, &bspr2 },
    {  70, 130, -3, -2, &bspr3 },
    { 200,  70,  2,  2, &bspr4 },
};

// loop counters / scratch — file scope per the CLAUDE.md guideline
uint16_t bench_i, bench_k;
uint8_t  bench_j;
uint16_t bench_t0;
uint8_t  bench_digits[ 5 ];

// Read the low 16 bits of the ROM FRAMES counter atomically.
static uint16_t bench_frames( void ) {
    uint16_t f;
    intrinsic_di();
    f = *( volatile uint16_t * )FRAMES_ADDR;
    intrinsic_ei();
    return f;
}

// Print a NUL-terminated string to the magic port.
static void bench_puts( const char *s ) {
    while ( *s )
        z80_outp( MAGIC_PORT, (uint8_t)*s++ );
}

// Print a 16-bit value to the magic port as decimal ASCII, then newline.
static void bench_putnum( uint16_t v ) {
    uint8_t n = 0;
    if ( v == 0 )
        z80_outp( MAGIC_PORT, '0' );
    while ( v ) {
        bench_digits[ n++ ] = '0' + (uint8_t)( v % 10 );
        v /= 10;
    }
    while ( n )
        z80_outp( MAGIC_PORT, bench_digits[ --n ] );
    z80_outp( MAGIC_PORT, '\n' );
}

// Mark every screen cell dirty by setting the whole DTT bitmap.
static void bench_mark_all_dirty( void ) {
    for ( bench_j = 0; bench_j < 96; bench_j++ )
        jsp_dtt[ bench_j ] = 0xFF;
}

// Advance one sprite one step, bouncing inside the visible area.
static void bench_step_sprite( struct bench_sprite_s *s ) {
    if ( s->x + s->dx > 224 || s->x + s->dx < 4 )   s->dx = -s->dx;
    s->x += s->dx;
    if ( s->y + s->dy > 160 || s->y + s->dy < 4 )   s->dy = -s->dy;
    s->y += s->dy;
    jsp_move_sprite( s->sp, s->x, s->y );
}

void main( void ) {
    zx_cls();
    jsp_init( NULL, 0x38 );

    // Each phase prints its result as soon as it finishes, so a run cut
    // short by --delayed-automatic-exit still yields partial data.

    // ---- A0: mark-dirty calibration (no redraw) ----
    bench_t0 = bench_frames();
    for ( bench_i = 0; bench_i < BENCH_FULL_REDRAWS; bench_i++ )
        bench_mark_all_dirty();
    bench_puts( "A0=" );
    bench_putnum( bench_frames() - bench_t0 );

    // ---- A: full-screen redraw ----
    bench_t0 = bench_frames();
    for ( bench_i = 0; bench_i < BENCH_FULL_REDRAWS; bench_i++ ) {
        bench_mark_all_dirty();
        jsp_redraw();
    }
    bench_puts( "A=" );
    bench_putnum( bench_frames() - bench_t0 );

    // ---- B: sprite move + redraw ----
    for ( bench_j = 0; bench_j < NUM_SPRITES; bench_j++ )
        jsp_draw_sprite( bench_sprites[ bench_j ].sp,
                         bench_sprites[ bench_j ].x,
                         bench_sprites[ bench_j ].y );
    jsp_redraw();

    bench_t0 = bench_frames();
    for ( bench_k = 0; bench_k < BENCH_SPRITE_FRAMES; bench_k++ ) {
        for ( bench_j = 0; bench_j < NUM_SPRITES; bench_j++ )
            bench_step_sprite( &bench_sprites[ bench_j ] );
        jsp_redraw();
    }
    bench_puts( "B=" );
    bench_putnum( bench_frames() - bench_t0 );
    bench_puts( "END\n" );

    while ( 1 )
        ;
}
