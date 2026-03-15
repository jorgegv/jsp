#include <stdio.h>
#include <stdint.h>
#include <spectrum.h>
#include <arch/z80.h>
#include <intrinsic.h>

#include "jsp.h"

extern uint8_t test_sprite_mask2_pixels[];

DEFINE_SPRITE(test_sprite,2,2,test_sprite_mask2_pixels,0,0,JSP_TYPE_MASK2);

void test_sprite_draw( void ) {
    uint8_t i, j;

    uint16_t character = 0x3d80;	// '0' at ROM

    // draw some background tiles
    for ( i = 0; i < 18; i++ ) {
        for ( j = 0; j < 32; j++ ) {
            jsp_draw_background_tile( i, j, (void *)character );
            character += 8;
            if ( character == 0x3dd0 )
                character = 0x3d80;
        }
    }
    jsp_redraw();

    jsp_init_sprite( &test_sprite );

    // draw a sprite
    jsp_draw_sprite( &test_sprite, 219, 12 );	// ASM version

    // check the sprite's pdbuf after drawing
    for ( i = 0; i < 3; i++ )
        for ( j = 0; j < 3; j++ )
            jsp_draw_screen_tile_attr( 19 + i, 2 + j, &test_sprite.pdbuf[ 8 * ( 3 * i + j ) ], PAPER_YELLOW | BRIGHT );

    // update screen
    jsp_redraw();
}

void main( void ) {
    zx_cls();
    jsp_init( NULL, 0x38 );
    test_sprite_draw();
    while ( 1 );
}
