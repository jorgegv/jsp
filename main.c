#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <spectrum.h>
#include <arch/z80.h>

#include "jsp.h"

void test_dtt( void ) {
    uint8_t i;
    uint8_t *ptr = jsp_dtt;

    // mark some cells dirty
    for ( i = 0; i < 24; i++ ) {
        jsp_dtt_mark_dirty( i, i );
        jsp_dtt_mark_dirty( i, 31 );
    }

    // dump DTT contents
    ptr = jsp_dtt;
    for ( i = 0; i < 96; i++ ) {
        printf( "%02X ", *ptr++ );
        if ( i % 16 == 15 ) putchar('\n');
    }

    puts("");

    // mark the same cells clean
    for ( i = 0; i < 24; i++ ) {
        jsp_dtt_mark_clean( i, i );
        jsp_dtt_mark_clean( i, 31 );
    }

    // dump DTT contents - should be zeroes
    ptr = jsp_dtt;
    for ( i = 0; i < 96; i++ ) {
        printf( "%02X ", *ptr++ );
        if ( i % 16 == 15 ) putchar('\n');
    }

}

uint8_t tile_ball[] = { 60, 126, 255, 255, 255, 255, 126, 60 };

void test_btt_contents( void ) {

    // draw couple of tiles
    jsp_draw_background_tile( 20, 16, tile_ball );
    jsp_draw_background_tile( 21, 18, tile_ball );

    // check BTT and DTT is updated correctly
    printf( "ball: $%04X\n", tile_ball );
    printf( "btt 20 16: $%04X\n", jsp_btt[ 20 * 32 + 16 ] );
    printf( "btt 21 18: $%04X\n", jsp_btt[ 21 * 32 + 18 ] );
    printf( "dtt 20 16: $%02X D:%s\n", jsp_dtt[ ( 20 * 32 + 16 ) / 8 ], jsp_dtt_is_dirty( 20,16 ) ? "yes" : "no" );
    printf( "dtt 21 18: $%02X D:%s\n", jsp_dtt[ ( 21 * 32 + 18 ) / 8 ], jsp_dtt_is_dirty( 21,18 ) ? "yes" : "no" );

    // ditto
    jsp_redraw();

    // since we have redrawn, now the DTT bits should be cleared
    printf( "btt 20 16: $%04X\n", jsp_btt[ 20 * 32 + 16 ] );
    printf( "btt 21 18: $%04X\n", jsp_btt[ 21 * 32 + 18 ] );
    printf( "dtt 20 16: $%02X D:%s\n", jsp_dtt[ ( 20 * 32 + 16 ) / 8 ], jsp_dtt_is_dirty( 20,16 ) ? "yes" : "no" );
    printf( "dtt 21 18: $%02X D:%s\n", jsp_dtt[ ( 21 * 32 + 18 ) / 8 ], jsp_dtt_is_dirty( 21,18 ) ? "yes" : "no" );
}

void test_btt_redraw( void ) {
    uint8_t i,j;

    // draw some tiles
    for ( i = 0; i < 11; i++ ) {
        for ( j = 0; j < 16; j++ ) {
            jsp_draw_background_tile( i*2, j*2, tile_ball );
            jsp_draw_background_tile( i*2+1, j*2+1, tile_ball );
        }
    }
    // update screen
    jsp_redraw();

    z80_delay_ms( 1000 );

    // undraw some tiles
    for ( i = 0; i < 11; i++ ) {
        for ( j = 0; j < 16; j++ ) {
            jsp_delete_background_tile( i*2, j*2 );
        }
    }
    // update screen
    jsp_redraw();
}

struct jsp_sprite_s test_sprite;
extern uint8_t test_sprite_pixels[];
extern uint8_t test_bg1tile_pixels[];
void test_sprite_draw( void ) {
    uint8_t i,j;

/*
    // draw some tiles
    for ( i = 0; i < 17; i++ ) {
        for ( j = 0; j < 32; j++ ) {
            if ( ( i + j ) % 2 )
                jsp_draw_background_tile( i, j, test_bg1tile_pixels );
            else
                jsp_draw_background_tile( i, j, tile_ball );
        }
    }
    // update screen
    jsp_redraw();
*/

    uint16_t character = 0x3d80;
    // draw some tiles
    for ( i = 0; i < 17; i++ ) {
        for ( j = 0; j < 32; j++ ) {
                jsp_draw_background_tile( i, j, (void *)character );
                character += 8;
                if ( character == 0x3dd0 )
                    character = 0x3d80;
        }
    }
    // update screen
    jsp_redraw();

//    jsp_draw_background_tile( 0, 0, (void *)0x3d80 );
//    jsp_draw_background_tile( 0, 1, (void *)0x3d88 );
//    jsp_draw_background_tile( 0, 2, (void *)0x3d90 );
//    jsp_draw_background_tile( 1, 0, (void *)0x3d98 );
//    jsp_draw_background_tile( 1, 1, (void *)0x3da0 );
//    jsp_draw_background_tile( 1, 2, (void *)0x3da8 );
//    jsp_draw_background_tile( 2, 0, (void *)0x3db0 );
//    jsp_draw_background_tile( 2, 1, (void *)0x3db8 );
//    jsp_draw_background_tile( 2, 2, (void *)0x3dc0 );
//    jsp_redraw();

    // play with sprite
    jsp_init_sprite( &test_sprite, test_sprite_pixels );

    jsp_draw_sprite( &test_sprite, 4, 4 );

    jsp_draw_screen_tile( 19, 2, &test_sprite.pdbuf[0] );
    jsp_draw_screen_tile( 19, 3, &test_sprite.pdbuf[8] );
    jsp_draw_screen_tile( 19, 4, &test_sprite.pdbuf[16] );
    jsp_draw_screen_tile( 20, 2, &test_sprite.pdbuf[24] );
    jsp_draw_screen_tile( 20, 3, &test_sprite.pdbuf[32] );
    jsp_draw_screen_tile( 20, 4, &test_sprite.pdbuf[40] );
    jsp_draw_screen_tile( 21, 2, &test_sprite.pdbuf[48] );
    jsp_draw_screen_tile( 21, 3, &test_sprite.pdbuf[56] );
    jsp_draw_screen_tile( 21, 4, &test_sprite.pdbuf[64] );

//    jsp_redraw();
}

void main( void ) {
    zx_cls();
    jsp_init( NULL );
    // only one of the tests below can be run, they interfere with each
    // other

//    test_dtt();
//    test_btt_contents();
//    test_btt_redraw();
    test_sprite_draw();
    while ( 1 );
}
