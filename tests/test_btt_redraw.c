#include <stdio.h>
#include <stdint.h>
#include <spectrum.h>
#include <arch/z80.h>
#include <intrinsic.h>

#include "jsp.h"

uint8_t tile_ball[] = { 60, 126, 255, 255, 255, 255, 126, 60 };

void test_btt_redraw( void ) {
    uint8_t i, j;

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

void main( void ) {
    zx_cls();
    jsp_init( NULL, 0x38 );
    test_btt_redraw();
    while ( 1 );
}
