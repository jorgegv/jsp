#include <stdint.h>

#include "jsp.h"

///////////////////////////////////////////////////////////
// jsp_redraw — flicker-free single-pass recompositing
//
// For each DIRTY cell exactly one final image is written to the screen:
//
//   * background-only cell  -> draw its BTT tile directly (no copy)
//   * sprite-covered cell   -> seed an 8-byte scratch with the BTT tile,
//                              composite every covering sprite in z-order,
//                              draw the scratch
//
// A cell is therefore written exactly once per frame, straight to its
// final content — the screen never shows an intermediate "background
// only" state, so sprites do not flicker.  Foreground cells (FTT) keep
// the plain background tile, so sprites pass behind them.
//
// The background-only fast path avoids the per-cell 8-byte copy, which
// matters because the vast majority of dirty cells (the whole initial
// full-screen redraw, and every sprite trail) are background-only.
//
// Correct, readable C; can be optimised to assembly later if needed.
///////////////////////////////////////////////////////////

void jsp_redraw( void ) {
    uint8_t g, b, i;

    // walk the DTT byte by byte (8 cells per byte); skip clean bytes
    for ( g = 0; g < 96; g++ ) {
        uint8_t  dbits = jsp_dtt[ g ];
        uint8_t  fbits, row, colbase, mask;
        uint16_t cellbase;

        if ( !dbits )
            continue;

        // per-byte constants (a DTT byte holds 8 cells of one row octet)
        fbits    = jsp_ftt[ g ];
        row      = g >> 2;
        colbase  = (uint8_t)( ( g & 3 ) << 3 );
        cellbase = (uint16_t)g << 3;

        for ( b = 0, mask = 1; b < 8; b++, mask <<= 1 ) {
            uint16_t cell;
            uint8_t  col, attr, covered;
            uint8_t  scratch[ 8 ];

            if ( !( dbits & mask ) )
                continue;

            cell    = cellbase + b;
            col     = colbase + b;
            attr    = jsp_bat[ cell ];
            covered = 0;

            // composite sprites onto non-foreground cells, in z-order
            if ( !( fbits & mask ) ) {
                for ( i = 0; i < jsp_sprite_registry_count; i++ ) {
                    struct jsp_sprite_s *sp = jsp_sprite_registry[ i ];
                    if ( !sp->flags.initialized || !sp->flags.active )
                        continue;
                    if ( !jsp_sprite_covers_cell( sp, row, col ) )
                        continue;
                    if ( !covered ) {
                        // first covering sprite: seed scratch with the bg
                        jsp_memcpy( scratch, jsp_btt[ cell ], 8 );
                        covered = 1;
                    }
                    jsp_composite_sprite_cell( sp, row, col, scratch, &attr );
                }
            }

            // single store of the final cell content — no flicker
            if ( covered )
                jsp_draw_screen_tile( row, col, scratch );
            else
                jsp_draw_screen_tile( row, col, jsp_btt[ cell ] );
            *( (volatile uint8_t *)( 0x5800 + cell ) ) = attr;
        }
    }

    // clear all dirty bits
    jsp_memzero( jsp_dtt, 96 );
}
