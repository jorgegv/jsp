#include <stdint.h>

#include "jsp.h"

///////////////////////////////////////////////////////////
// jsp_redraw — flicker-free single-pass recompositing
//
// For each DIRTY cell the final image is built in an 8-byte scratch
// buffer and then written to the screen with a SINGLE store:
//
//   1. copy the background tile (BTT) into the scratch
//   2. composite every active sprite that covers the cell, in z-order
//      (registration order = back-to-front)
//   3. store the scratch to the screen cell, and the attribute
//
// A cell is therefore written exactly once per frame, straight to its
// final content — the screen never shows an intermediate "background
// only" state, so sprites do not flicker.  Foreground cells (FTT) are
// left as the plain background tile, so sprites pass behind them.
//
// The displayed image is recomputed from BTT + live sprite state every
// redraw; nothing is baked.  This is a correct, readable C
// implementation; it can be optimised to assembly later if needed.
///////////////////////////////////////////////////////////

void jsp_redraw( void ) {
    uint8_t g, b, i, k;

    // walk the DTT byte by byte (8 cells per byte); skip clean bytes
    for ( g = 0; g < 96; g++ ) {
        uint8_t bits = jsp_dtt[ g ];
        if ( !bits )
            continue;
        for ( b = 0; b < 8; b++ ) {
            uint16_t cell;
            uint8_t  row, col, attr;
            uint8_t  scratch[ 8 ];
            uint8_t *bg;

            if ( !( bits & ( 1 << b ) ) )
                continue;

            cell = ( (uint16_t)g << 3 ) + b;
            row  = cell >> 5;
            col  = cell & 31;

            // 1. start from the background tile
            bg = jsp_btt[ cell ];
            for ( k = 0; k < 8; k++ )
                scratch[ k ] = bg[ k ];
            attr = jsp_bat[ cell ];

            // 2. composite every active sprite covering this cell, in
            //    z-order; foreground cells keep the plain background so
            //    sprites pass behind them
            if ( !jsp_ftt_is_fg( row, col ) ) {
                for ( i = 0; i < jsp_sprite_registry_count; i++ ) {
                    struct jsp_sprite_s *sp = jsp_sprite_registry[ i ];
                    if ( sp->flags.initialized && sp->flags.active )
                        jsp_composite_sprite_cell( sp, row, col, scratch, &attr );
                }
            }

            // 3. single store of the final cell content — no flicker
            jsp_draw_screen_tile( row, col, scratch );
            *( (volatile uint8_t *)( 0x5800 + cell ) ) = attr;
        }
    }

    // clear all dirty bits
    jsp_memzero( jsp_dtt, 96 );
}
