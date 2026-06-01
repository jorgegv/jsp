#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <spectrum.h>
#include <arch/z80.h>
#include <intrinsic.h>

#include "jsp.h"

extern uint8_t test_sprite_mask2_pixels[];
extern uint8_t test_sprite_load1_pixels[];

#define NUM_SPRITES 5

DEFINE_SPRITE(sprite0,2,2,test_sprite_mask2_pixels,0,0,JSP_TYPE_MASK2);
DEFINE_SPRITE(sprite1,2,2,test_sprite_mask2_pixels,0,0,JSP_TYPE_MASK2);
DEFINE_SPRITE(sprite2,2,2,test_sprite_load1_pixels,0,0,JSP_TYPE_LOAD1);
DEFINE_SPRITE(sprite3,2,2,test_sprite_load1_pixels,0,0,JSP_TYPE_LOAD1);
DEFINE_SPRITE(sprite4,2,2,test_sprite_load1_pixels,0,0,JSP_TYPE_LOAD1);

struct {
    uint8_t x, y;
    int8_t dx, dy;
    struct jsp_sprite_s *sp;
} test_sprites[ NUM_SPRITES ] = {
    { .sp = &sprite0 },
    { .sp = &sprite1 },
    { .sp = &sprite2 },
    { .sp = &sprite3 },
    { .sp = &sprite4 },
};

void test_sprite_move( void ) {
    uint8_t i, j;

    uint16_t character = 0x3d80;	// '0' at ROM

    // draw some background tiles
    for ( i = 0; i < 24; i++ ) {
        for ( j = 0; j < 32; j++ ) {
            jsp_draw_background_tile( i, j, (void *)character );
            character += 8;
            if ( character == 0x3dd0 )
                character = 0x3d80;
        }
    }

    // position sprites randomly and assign some movement constants
    srand( 12345 );
    for ( i = 0; i < NUM_SPRITES; i++ ) {
        test_sprites[ i ].x = rand() % 240;
        test_sprites[ i ].y = rand() % 170;
        test_sprites[ i ].dx = ( rand() % 8 ) - 4;
        test_sprites[ i ].dy = ( rand() % 8 ) - 4;
    }

    while ( 1 ) {
        for ( i = 0; i < NUM_SPRITES; i++ ) {
            jsp_move_sprite( test_sprites[ i ].sp, test_sprites[ i ].x, test_sprites[ i ].y );

            if ( ( test_sprites[ i ].x + test_sprites[ i ].dx > 240 ) || ( test_sprites[ i ].x + test_sprites[ i ].dx < 4 ) ) {
                test_sprites[ i ].dx = -test_sprites[ i ].dx;
            }
            test_sprites[ i ].x += test_sprites[ i ].dx;

            if ( ( test_sprites[ i ].y + test_sprites[ i ].dy > 170 ) || ( test_sprites[ i ].y + test_sprites[ i ].dy < 4 ) ) {
                test_sprites[ i ].dy = -test_sprites[ i ].dy;
            }
            test_sprites[ i ].y += test_sprites[ i ].dy;
        }
        jsp_redraw();
    }
}

void main( void ) {
    zx_cls();
    jsp_init( NULL, 0x38 );
    test_sprite_move();
}
