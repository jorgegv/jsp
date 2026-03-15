#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <spectrum.h>
#include <arch/z80.h>
#include <intrinsic.h>

#include "jsp.h"

extern uint8_t test_sprite_mask2_pixels[];

#define TEST_POOL_SIZE  3
#define TEST_MAX_ROWS   2
#define TEST_MAX_COLS   2
#define TEST_PDB_SIZE   ((TEST_MAX_ROWS+1)*(TEST_MAX_COLS+1)*8)
static struct jsp_sprite_s test_pool[ TEST_POOL_SIZE ];
static uint8_t test_pdb_0[ TEST_PDB_SIZE ];
static uint8_t test_pdb_1[ TEST_PDB_SIZE ];
static uint8_t test_pdb_2[ TEST_PDB_SIZE ];
static uint8_t *test_pdbs[ TEST_POOL_SIZE ];

void test_pool_and_colour( void ) {
    uint8_t i, j;
    uint8_t frame;
    struct jsp_sprite_s *sp[TEST_POOL_SIZE];
    uint8_t x[TEST_POOL_SIZE], y[TEST_POOL_SIZE];
    int8_t  dx[TEST_POOL_SIZE], dy[TEST_POOL_SIZE];

    // fill background with ROM font chars
    uint16_t character = 0x3d80;
    for ( i = 0; i < 24; i++ ) {
        for ( j = 0; j < 32; j++ ) {
            jsp_draw_background_tile( i, j, (void *)character );
            character += 8;
            if ( character == 0x3dd0 ) character = 0x3d80;
        }
    }
    jsp_redraw();

    // set up pool (runtime init required — z88dk/SDCC static pointer init is unreliable)
    test_pdbs[0] = test_pdb_0;
    test_pdbs[1] = test_pdb_1;
    test_pdbs[2] = test_pdb_2;
    jsp_sprite_pool_init( test_pool, test_pdbs, TEST_POOL_SIZE );

    // allocate sprites from pool, set colours, initial positions and velocities
    srand( 42 );
    for ( i = 0; i < TEST_POOL_SIZE; i++ ) {
        sp[i] = jsp_sprite_alloc( 2, 2 );
        if ( sp[i] )
            jsp_sprite_set_color( sp[i], (uint8_t)(INK_RED + i), 0xF8 );
        x[i]  = (uint8_t)(20 + i * 40);
        y[i]  = (uint8_t)(20 + i * 20);
        dx[i] = (int8_t)(( rand() % 4 ) + 1);
        dy[i] = (int8_t)(( rand() % 4 ) + 1);
    }

    // bouncing movement loop: ~200 frames
    for ( frame = 0; frame < 200; frame++ ) {
        for ( i = 0; i < TEST_POOL_SIZE; i++ ) {
            if ( !sp[i] ) continue;
            jsp_move_sprite_mask2_frame( sp[i], test_sprite_mask2_pixels, x[i], y[i] );

            if ( (int16_t)x[i] + dx[i] > 230 || (int16_t)x[i] + dx[i] < 4 )
                dx[i] = -dx[i];
            x[i] = (uint8_t)( x[i] + dx[i] );

            if ( (int16_t)y[i] + dy[i] > 170 || (int16_t)y[i] + dy[i] < 4 )
                dy[i] = -dy[i];
            y[i] = (uint8_t)( y[i] + dy[i] );
        }
        jsp_redraw();

        // at frame 100, park sprite 1 to demonstrate park
        if ( frame == 100 && sp[1] )
            jsp_sprite_park( sp[1] );
    }

    // free all sprites back to pool
    for ( i = 0; i < TEST_POOL_SIZE; i++ )
        if ( sp[i] ) jsp_sprite_free( sp[i] );
}

void main( void ) {
    zx_cls();
    jsp_init( NULL, 0x38 );
    test_pool_and_colour();
    while ( 1 );
}
