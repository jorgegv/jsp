#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <spectrum.h>
#include <arch/z80.h>
#include <intrinsic.h>

#include "jsp.h"

// this is included because of the tests below, it should not be included in
// a regular JSP program
#include "jsp_private.h"

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

extern uint8_t test_sprite_mask2_pixels[];
extern uint8_t test_sprite_load1_pixels[];
extern uint8_t test_bg1tile_pixels[];

DEFINE_SPRITE_MASK2(test_sprite,2,2,test_sprite_mask2_pixels,0,0);

void test_sprite_draw_mask2( void ) {
    uint8_t i,j;

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
    jsp_draw_sprite_mask2( &test_sprite, 219, 12 );	// ASM version

    // check the sprite's pdbuf after drawing
    for ( i = 0; i < 3; i++ )
        for ( j = 0; j < 3; j++ )
            jsp_draw_screen_tile_attr( 19 + i, 2 + j, &test_sprite.pdbuf[ 8 * ( 3 * i + j ) ], PAPER_YELLOW | BRIGHT );

    // update screen
    jsp_redraw();

}

#define NUM_SPRITES 3

//DEFINE_SPRITE_MASK2(sprite0,2,2,test_sprite_mask2_pixels,0,0);
//DEFINE_SPRITE_MASK2(sprite1,2,2,test_sprite_mask2_pixels,0,0);
//DEFINE_SPRITE_MASK2(sprite2,2,2,test_sprite_mask2_pixels,0,0);
//DEFINE_SPRITE_MASK2(sprite3,2,2,test_sprite_mask2_pixels,0,0);
//DEFINE_SPRITE_MASK2(sprite4,2,2,test_sprite_mask2_pixels,0,0);

DEFINE_SPRITE_LOAD1(sprite0,2,2,test_sprite_load1_pixels,0,0);
DEFINE_SPRITE_LOAD1(sprite1,2,2,test_sprite_load1_pixels,0,0);
DEFINE_SPRITE_LOAD1(sprite2,2,2,test_sprite_load1_pixels,0,0);
//DEFINE_SPRITE_LOAD1(sprite3,2,2,test_sprite_load1_pixels,0,0);
//DEFINE_SPRITE_LOAD1(sprite4,2,2,test_sprite_load1_pixels,0,0);

struct { 
    uint8_t x,y;
    int8_t dx,dy;
    struct jsp_sprite_s *sp;
    } test_sprites[ NUM_SPRITES ] = {
        { .sp = &sprite0 },
        { .sp = &sprite1 },
        { .sp = &sprite2 },
//        { .sp = &sprite3 },
//        { .sp = &sprite4 },
};

void test_sprite_move_mask2( void ) {
    uint8_t i,j;

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

    // play with sprites

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
            jsp_move_sprite_mask2( test_sprites[ i ].sp, test_sprites[ i ].x, test_sprites[ i ].y );

            if ( ( test_sprites[ i ].x + test_sprites[ i ].dx > 240 ) || ( test_sprites[ i ].x + test_sprites[ i ].dx < 4 ) ){
                test_sprites[ i ].dx = -test_sprites[ i ].dx;
            }
            test_sprites[ i ].x += test_sprites[ i ].dx;

            if ( ( test_sprites[ i ].y + test_sprites[ i ].dy > 170 ) || ( test_sprites[ i ].y + test_sprites[ i ].dy < 4 ) ) {
                test_sprites[ i ].dy = -test_sprites[ i ].dy;
            }
            test_sprites[ i ].y += test_sprites[ i ].dy;
        }

/*
        __asm
        halt
        __endasm;
*/
        jsp_redraw();

//        z80_delay_ms( 10 );
    }

}

void test_sprite_move_load1( void ) {
    uint8_t i;

    // play with sprites

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
            jsp_move_sprite_load1( test_sprites[ i ].sp, test_sprites[ i ].x, test_sprites[ i ].y );

            if ( ( test_sprites[ i ].x + test_sprites[ i ].dx > 240 ) || ( test_sprites[ i ].x + test_sprites[ i ].dx < 4 ) ){
                test_sprites[ i ].dx = -test_sprites[ i ].dx;
            }
            test_sprites[ i ].x += test_sprites[ i ].dx;

            if ( ( test_sprites[ i ].y + test_sprites[ i ].dy > 170 ) || ( test_sprites[ i ].y + test_sprites[ i ].dy < 4 ) ) {
                test_sprites[ i ].dy = -test_sprites[ i ].dy;
            }
            test_sprites[ i ].y += test_sprites[ i ].dy;
        }

/*
        __asm
        halt
        __endasm;
*/
        jsp_redraw();

//        z80_delay_ms( 10 );
    }

}

void main( void ) {
    zx_cls();
    jsp_init( NULL );

    // only one of the tests below can be run, they interfere with each
    // other

//    test_dtt();
//    test_btt_contents();
//    test_btt_redraw();
//    test_sprite_draw_mask2();
//    test_sprite_move_mask2();
    test_sprite_move_load1();
    while ( 1 );
}
