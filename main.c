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

    uint16_t character = 0x3d80;	// '0' at ROM
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

    // play with sprite
    jsp_init_sprite( &test_sprite, test_sprite_pixels );

    for ( i = 0; i < 160; i++ ) {
        jsp_draw_sprite( &test_sprite, i, i );
        jsp_redraw();
        z80_delay_ms( 10 );
    }
//        jsp_draw_screen_tile( 19, 2, &test_sprite.pdbuf[0] ); *zx_cxy2aaddr( 2, 19 ) = PAPER_YELLOW | BRIGHT;
//        jsp_draw_screen_tile( 19, 3, &test_sprite.pdbuf[8] ); *zx_cxy2aaddr( 3, 19 ) = PAPER_YELLOW | BRIGHT;
//        jsp_draw_screen_tile( 19, 4, &test_sprite.pdbuf[16] ); *zx_cxy2aaddr( 4, 19 ) = PAPER_YELLOW | BRIGHT;
//        jsp_draw_screen_tile( 20, 2, &test_sprite.pdbuf[24] ); *zx_cxy2aaddr( 2, 20 ) = PAPER_YELLOW | BRIGHT;
//        jsp_draw_screen_tile( 20, 3, &test_sprite.pdbuf[32] ); *zx_cxy2aaddr( 3, 20 ) = PAPER_YELLOW | BRIGHT;
//        jsp_draw_screen_tile( 20, 4, &test_sprite.pdbuf[40] ); *zx_cxy2aaddr( 4, 20 ) = PAPER_YELLOW | BRIGHT;
//        jsp_draw_screen_tile( 21, 2, &test_sprite.pdbuf[48] ); *zx_cxy2aaddr( 2, 21 ) = PAPER_YELLOW | BRIGHT;
//        jsp_draw_screen_tile( 21, 3, &test_sprite.pdbuf[56] ); *zx_cxy2aaddr( 3, 21 ) = PAPER_YELLOW | BRIGHT;
//        jsp_draw_screen_tile( 21, 4, &test_sprite.pdbuf[64] ); *zx_cxy2aaddr( 4, 21 ) = PAPER_YELLOW | BRIGHT;
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
