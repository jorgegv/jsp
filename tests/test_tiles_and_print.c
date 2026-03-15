#include <stdio.h>
#include <stdint.h>
#include <spectrum.h>
#include <arch/z80.h>
#include <intrinsic.h>

#include "jsp.h"

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
    jsp_init( NULL, 0x38 );
    test_tiles_and_print();
    while ( 1 );
}
