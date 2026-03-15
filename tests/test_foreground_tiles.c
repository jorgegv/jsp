#include <stdio.h>
#include <stdint.h>
#include <spectrum.h>
#include <arch/z80.h>
#include <intrinsic.h>

#include "jsp.h"

extern uint8_t test_sprite_mask2_pixels[];

#define TEST_POOL_SIZE  2
#define TEST_MAX_ROWS   2
#define TEST_MAX_COLS   2
static struct jsp_sprite_s test_pool[ TEST_POOL_SIZE ];
static uint8_t test_pdbs[ TEST_POOL_SIZE * (TEST_MAX_ROWS+1) * (TEST_MAX_COLS+1) * 8 ];

// a closed box tile for the foreground band
static uint8_t tile_box[] = { 0xFF, 0xFF, 0xC3, 0xC3, 0xC3, 0xC3, 0xFF, 0xFF };

void test_foreground_tiles( void ) {
    uint8_t i, j;
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

    // draw foreground bars: one horizontal band and two vertical bars
    // sprites should pass behind these tiles
    for ( j = 0; j < 32; j++ ) {
        jsp_draw_foreground_tile( 11, j, tile_box );
        *( volatile uint8_t * )( 0x5800 + 11 * 32 + j ) = PAPER_YELLOW | INK_BLUE;
    }
    for ( i = 0; i < 24; i++ ) {
        jsp_draw_foreground_tile( i, 10, tile_box );
        *( volatile uint8_t * )( 0x5800 + (uint16_t)i * 32 + 10 ) = PAPER_YELLOW | INK_BLUE;
        jsp_draw_foreground_tile( i, 21, tile_box );
        *( volatile uint8_t * )( 0x5800 + (uint16_t)i * 32 + 21 ) = PAPER_YELLOW | INK_BLUE;
    }

    // set up pool and allocate sprites
    jsp_sprite_pool_init( test_pool, test_pdbs,
                          TEST_POOL_SIZE, TEST_MAX_ROWS, TEST_MAX_COLS );

    x[0] = 20;  y[0] = 20;  dx[0] = 2;  dy[0] = 3;
    x[1] = 180; y[1] = 140; dx[1] = -3; dy[1] = -2;

    for ( i = 0; i < TEST_POOL_SIZE; i++ ) {
        sp[i] = jsp_sprite_alloc( 2, 2 );
        if ( sp[i] )
            jsp_sprite_set_color( sp[i], (uint8_t)(INK_RED + i), 0xF8 );
    }

    // animate ~300 frames: sprites bounce around, crossing the foreground band
    while ( 1 ) {
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
    }

}

void main( void ) {
    zx_cls();
    jsp_init( NULL, 0x38 );
    test_foreground_tiles();
    while ( 1 );
}
