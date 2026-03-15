#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <spectrum.h>
#include <arch/z80.h>
#include <intrinsic.h>

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

extern uint8_t test_sprite_mask2_pixels[];
extern uint8_t test_sprite_load1_pixels[];
extern uint8_t test_bg1tile_pixels[];

DEFINE_SPRITE(test_sprite,2,2,test_sprite_mask2_pixels,0,0,JSP_TYPE_MASK2);

void test_sprite_draw( void ) {
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
    jsp_draw_sprite( &test_sprite, 219, 12 );	// ASM version

    // check the sprite's pdbuf after drawing
    for ( i = 0; i < 3; i++ )
        for ( j = 0; j < 3; j++ )
            jsp_draw_screen_tile_attr( 19 + i, 2 + j, &test_sprite.pdbuf[ 8 * ( 3 * i + j ) ], PAPER_YELLOW | BRIGHT );

    // update screen
    jsp_redraw();

}

#define NUM_SPRITES 5

DEFINE_SPRITE(sprite0,2,2,test_sprite_mask2_pixels,0,0,JSP_TYPE_MASK2);
DEFINE_SPRITE(sprite1,2,2,test_sprite_mask2_pixels,0,0,JSP_TYPE_MASK2);
//DEFINE_SPRITE(sprite2,2,2,test_sprite_mask2_pixels,0,0,JSP_TYPE_MASK2);
//DEFINE_SPRITE(sprite3,2,2,test_sprite_mask2_pixels,0,0,JSP_TYPE_MASK2);
//DEFINE_SPRITE(sprite4,2,2,test_sprite_mask2_pixels,0,0,JSP_TYPE_MASK2);

//DEFINE_SPRITE(sprite0,2,2,test_sprite_load1_pixels,0,0,JSP_TYPE_LOAD1);
//DEFINE_SPRITE(sprite1,2,2,test_sprite_load1_pixels,0,0,JSP_TYPE_LOAD1);
DEFINE_SPRITE(sprite2,2,2,test_sprite_load1_pixels,0,0,JSP_TYPE_LOAD1);
DEFINE_SPRITE(sprite3,2,2,test_sprite_load1_pixels,0,0,JSP_TYPE_LOAD1);
DEFINE_SPRITE(sprite4,2,2,test_sprite_load1_pixels,0,0,JSP_TYPE_LOAD1);

struct { 
    uint8_t x,y;
    int8_t dx,dy;
    struct jsp_sprite_s *sp;
    } test_sprites[ NUM_SPRITES ] = {
        { .sp = &sprite0 },
        { .sp = &sprite1 },
        { .sp = &sprite2 },
        { .sp = &sprite3 },
        { .sp = &sprite4 },
};

void test_sprite_move( void ) {
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
            jsp_move_sprite( test_sprites[ i ].sp, test_sprites[ i ].x, test_sprites[ i ].y );

            if ( ( test_sprites[ i ].x + test_sprites[ i ].dx > 240 ) || ( test_sprites[ i ].x + test_sprites[ i ].dx < 4 ) ){
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

///////////////////////////////////////////////////////////
// Phase 1 new API tests
///////////////////////////////////////////////////////////

// Pool storage for test_pool_and_colour
#define TEST_POOL_SIZE  3
#define TEST_MAX_ROWS   2
#define TEST_MAX_COLS   2
#define TEST_PDB_SIZE   ((TEST_MAX_ROWS+1)*(TEST_MAX_COLS+1)*8)
static struct jsp_sprite_s test_pool[ TEST_POOL_SIZE ];
static uint8_t test_pdb_0[ TEST_PDB_SIZE ];
static uint8_t test_pdb_1[ TEST_PDB_SIZE ];
static uint8_t test_pdb_2[ TEST_PDB_SIZE ];
static uint8_t *test_pdbs[ TEST_POOL_SIZE ];

// Test: pool alloc, frame-based movement, colour, park
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

// Test: tile_put, clear_rect, invalidate_rect, print_string
void test_tiles_and_print( void ) {
    struct jsp_rect game_area = { 0, 0, 32, 22 };
    struct jsp_print_ctx ctx = JSP_PRINT_CTX_INIT( game_area, PAPER_BLACK | INK_WHITE );

    // clear full screen with white paper
    jsp_clear_rect( &game_area, PAPER_WHITE | INK_BLACK, ' ', JSP_RFLAG_TILE | JSP_RFLAG_COLOUR );

    // print a string
    jsp_print_set_pos( &ctx, 2, 4 );
    jsp_print_string( &ctx, "HELLO JSP!" );

    // draw a coloured tile at a specific position
    jsp_tile_put( 10, 15, PAPER_RED | INK_WHITE | BRIGHT, ' ' );

    jsp_redraw();
    z80_delay_ms( 2000 );
}

void main( void ) {
    zx_cls();
    jsp_init( NULL, 0x38 );	// 0x38 = PAPER_WHITE | INK_BLACK

    // only one of the tests below can be run, they interfere with each
    // other

//    test_dtt();
//    test_btt_contents();
//    test_btt_redraw();
//    test_sprite_draw();
//    test_sprite_move();
    test_pool_and_colour();
//    test_tiles_and_print();
    while ( 1 );
}
