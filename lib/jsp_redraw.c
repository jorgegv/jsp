#include <stdint.h>

#include "jsp.h"

///////////////////////////////////////////////////////////
// jsp_redraw — flicker-free single-pass recompositing
//
// jsp_redraw_begin() first precomputes per-sprite constants for every
// active sprite into jsp_frame_sprites[].  Then, for each DIRTY cell,
// exactly one final image is written to the screen:
//
//   * background-only cell  -> draw its BTT tile directly (no copy)
//   * sprite-covered cell   -> seed an 8-byte scratch with the BTT tile,
//                              composite every covering sprite in z-order,
//                              draw the scratch
//
// A cell is written exactly once per frame, straight to its final
// content — no intermediate "background only" state, so no flicker.
// Foreground cells (FTT) keep the plain background tile, so sprites pass
// behind them.
//
// Correct, readable C; can be optimised to assembly later if needed.
///////////////////////////////////////////////////////////

void jsp_redraw( void ) {
    uint8_t g, b, i;
    uint8_t nframes = jsp_redraw_begin();   // precompute per-sprite data

    // walk the DTT byte by byte (8 cells per byte); skip clean bytes
    for ( g = 0; g < 96; g++ ) {
        uint8_t  dbits = jsp_dtt[ g ];
        uint8_t  fbits, row, colbase, mask;
        uint16_t cellbase;

        if ( !dbits )
            continue;

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
                for ( i = 0; i < nframes; i++ ) {
                    struct jsp_sprite_frame *fs = &jsp_frame_sprites[ i ];
                    if ( row < fs->r0 || row > fs->r1 ||
                         col < fs->c0 || col > fs->c1 )
                        continue;
                    if ( fs->clip && !jsp_cell_in_rect( row, col, fs->clip ) )
                        continue;
                    if ( !covered ) {
                        jsp_memcpy( scratch, jsp_btt[ cell ], 8 );
                        covered = 1;
                    }
                    jsp_composite_frame_cell( fs, row, col, scratch, &attr );
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
