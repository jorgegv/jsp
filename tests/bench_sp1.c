// bench_sp1 — SP1 redraw speed benchmark (for JSP-vs-SP1 comparison)
//
// Standalone SP1 program mirroring tests/test_redraw_bench.c on the same
// workload, so the two libraries can be compared directly.  Timing uses
// the 48K ROM FRAMES counter (sysvar 0x5C78); results print as ASCII
// "label=frames" lines to the JNEXT magic port.  Phases:
//
//   A0 : invalidate whole screen        x BENCH_FULL_REDRAWS   (calibration)
//   A  : invalidate + sp1_UpdateNow      x BENCH_FULL_REDRAWS
//   B  : move 5 sprites + sp1_UpdateNow  x BENCH_SPRITE_FRAMES
//
// Build and run with `make bench-sp1`.
//
// Built with the z88dk new C library (-clib=sdcc_iy): sdcc then uses IY
// (not IX) as its frame pointer, so SP1's hand-written asm — which trashes
// IX — no longer corrupts C frames.  The library setup follows the z88dk
// newlib SP1 example (demo_sp1/demo2): REGISTER_SP, CLIB_MALLOC_HEAP_SIZE.

#include <arch/zx/sp1.h>
#include <z80.h>
#include <intrinsic.h>

#pragma output REGISTER_SP           = 0xd000   // stack just below SP1's
                                                // fixed update array
#pragma output CLIB_MALLOC_HEAP_SIZE = 3000     // heap for SP1 sprite structs
#pragma output CRT_ORG_CODE          = 32768    // org 0x8000
#pragma output CLIB_EXIT_STACK_SIZE  = 0
#pragma output CLIB_STDIO_HEAP_SIZE  = 0
#pragma output CLIB_FOPEN_MAX        = -1

#define MAGIC_PORT          0x00FF
#define FRAMES_ADDR         0x5C78

#define BENCH_FULL_REDRAWS  200     // Phase A / A0 iterations
#define BENCH_SPRITE_FRAMES 1000    // Phase B iterations (matches test_redraw_bench)
#define NUM_SPRITES         5

// 16x16 masked sprite graphic — the "window" from SP1 example ex2g.
// 16-byte UDG header then 2 columns x 48 bytes of (mask,graph) pairs;
// gr_window points past the header at the column data.
static uint8_t window_data[] = {
    0xff,0x00,0xff,0x00,0xff,0x00,0xff,0x00,0xff,0x00,0xff,0x00,0xff,0x00,0xff,0x00,
    128,127,  0,192,  0,191, 30,161,
     30,161, 30,161, 30,161,  0,191,
      0,191, 30,161, 30,161, 30,161,
     30,161,  0,191,  0,192,128,127,
    255,  0,255,  0,255,  0,255,  0,
    255,  0,255,  0,255,  0,255,  0,
      1,254,  0,  3,  0,253,120,133,
    120,133,120,133,120,133,  0,253,
      0,253,120,133,120,133,120,133,
    120,133,  0,253,  0,  3,  1,254,
    255,  0,255,  0,255,  0,255,  0,
    255,  0,255,  0,255,  0,255,  0
};
static uint8_t *gr_window = &window_data[ 16 ];

// background tile graphic for the default ' ' cell
static uint8_t tile_gfx[ 8 ] = { 0x55,0xAA,0x55,0xAA,0x55,0xAA,0x55,0xAA };

struct sp1_Rect full_screen = { 0, 0, 32, 24 };

// sprite motion state — file scope
struct sp1bench_sprite {
    int8_t         dx, dy;          // tile-relative pixel speed
    uint8_t        masked;          // 1 = MASK2 sprite, 0 = LOAD2 sprite
    uint8_t        row, col;        // initial tile position
    struct sp1_ss *s;
};

struct sp1bench_sprite bench_sprites[ NUM_SPRITES ] = {
    {  3,  2, 1,  4,  4, 0 },
    { -2,  3, 1,  8, 16, 0 },
    {  2, -3, 0, 14, 24, 0 },
    { -3, -2, 0, 18,  8, 0 },
    {  3,  1, 0,  6, 26, 0 },
};

// loop counters / scratch — file scope
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

// Create sprite bench_sprites[bench_j]: a 16x16, 3-column software-rotated
// sprite, masked (MASK2) or load (LOAD2), then place it at its start cell.
static void bench_make_sprite( void ) {
    struct sp1_ss *s;
    if ( bench_sprites[ bench_j ].masked ) {
        s = sp1_CreateSpr( SP1_DRAW_MASK2LB, SP1_TYPE_2BYTE, 3, 0, bench_j );
        sp1_AddColSpr( s, SP1_DRAW_MASK2,   0, 48, bench_j );
        sp1_AddColSpr( s, SP1_DRAW_MASK2RB, 0,  0, bench_j );
    } else {
        s = sp1_CreateSpr( SP1_DRAW_LOAD2LB, SP1_TYPE_2BYTE, 3, 0, bench_j );
        sp1_AddColSpr( s, SP1_DRAW_LOAD2,   0, 48, bench_j );
        sp1_AddColSpr( s, SP1_DRAW_LOAD2RB, 0,  0, bench_j );
    }
    bench_sprites[ bench_j ].s = s;
    sp1_MoveSprAbs( s, &full_screen, gr_window,
                    bench_sprites[ bench_j ].row, bench_sprites[ bench_j ].col,
                    0, 0 );
}

// Move sprite bench_sprites[bench_j] one step (ex2g idiom: relative move
// then bounce when row/col leaves the visible 32x24 area).
static void bench_move_sprite( void ) {
    struct sp1_ss *s = bench_sprites[ bench_j ].s;
    sp1_MoveSprRel( s, &full_screen, 0, 0, 0,
                    bench_sprites[ bench_j ].dy, bench_sprites[ bench_j ].dx );
    if ( s->row > 21 )
        bench_sprites[ bench_j ].dy = -bench_sprites[ bench_j ].dy;
    if ( s->col > 29 )
        bench_sprites[ bench_j ].dx = -bench_sprites[ bench_j ].dx;
}

void main( void ) {
    sp1_Initialize( SP1_IFLAG_MAKE_ROTTBL | SP1_IFLAG_OVERWRITE_TILES
                        | SP1_IFLAG_OVERWRITE_DFILE,
                    0x38, ' ' );
    sp1_TileEntry( ' ', tile_gfx );

    sp1_Invalidate( &full_screen );
    sp1_UpdateNow();                    // initial paint

    // Each phase prints its result as soon as it finishes, so a run cut
    // short by --delayed-automatic-exit still yields partial data.

    // ---- A0: invalidate calibration (no redraw) ----
    bench_t0 = bench_frames();
    for ( bench_i = 0; bench_i < BENCH_FULL_REDRAWS; bench_i++ )
        sp1_Invalidate( &full_screen );
    bench_puts( "A0=" );
    bench_putnum( bench_frames() - bench_t0 );

    // ---- A: full-screen redraw ----
    bench_t0 = bench_frames();
    for ( bench_i = 0; bench_i < BENCH_FULL_REDRAWS; bench_i++ ) {
        sp1_Invalidate( &full_screen );
        sp1_UpdateNow();
    }
    bench_puts( "A=" );
    bench_putnum( bench_frames() - bench_t0 );

    // ---- B: sprite move + redraw ----
    for ( bench_j = 0; bench_j < NUM_SPRITES; bench_j++ )
        bench_make_sprite();
    sp1_UpdateNow();

    bench_t0 = bench_frames();
    for ( bench_k = 0; bench_k < BENCH_SPRITE_FRAMES; bench_k++ ) {
        for ( bench_j = 0; bench_j < NUM_SPRITES; bench_j++ )
            bench_move_sprite();
        sp1_UpdateNow();
    }
    bench_puts( "B=" );
    bench_putnum( bench_frames() - bench_t0 );
    bench_puts( "END\n" );

    while ( 1 )
        ;
}
