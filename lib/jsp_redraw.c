#include <stdint.h>

#include "jsp.h"

///////////////////////////////////////////////////////////
// jsp_redraw — deferred recompositing screen refresh
//
// PASS 1 — background
//   For each dirty cell: paint its BTT tile and its BAT attribute.
//   Foreground cells are painted here too (their BTT holds the
//   foreground tile graphic) and are then protected from Pass 2.
//
// PASS 2 — sprites
//   For each registered active sprite (registration order = back-to-front
//   z-order): recomposite it onto the screen.  jsp_composite_sprite only
//   touches dirty, in-clip, non-foreground cells, so it reads the live
//   background painted by Pass 1 (and any lower-z sprite already drawn)
//   and produces the correct stacked image.
//
// FINALLY — clear the Dirty Tiles Table.
//
// The displayed image is recomputed from BTT + live sprite state every
// redraw; nothing is baked.  This matches SP1's slist semantics.
//
// Correct, readable C implementation — optimise to assembly later only
// if profiling requires it.
///////////////////////////////////////////////////////////

void jsp_redraw( void ) {
    uint8_t  g, b, i;

    // PASS 1 — background: walk the DTT byte by byte (8 cells per byte)
    for ( g = 0; g < 96; g++ ) {
        uint8_t bits = jsp_dtt[ g ];
        if ( !bits )
            continue;
        for ( b = 0; b < 8; b++ ) {
            if ( bits & ( 1 << b ) ) {
                uint16_t cell = ( (uint16_t)g << 3 ) + b;
                uint8_t  row  = cell >> 5;
                uint8_t  col  = cell & 31;
                jsp_draw_screen_tile( row, col, jsp_btt[ cell ] );
                *( (volatile uint8_t *)( 0x5800 + cell ) ) = jsp_bat[ cell ];
            }
        }
    }

    // PASS 2 — sprites: recomposite every active registered sprite
    for ( i = 0; i < jsp_sprite_registry_count; i++ ) {
        struct jsp_sprite_s *sp = jsp_sprite_registry[ i ];
        if ( sp->flags.initialized && sp->flags.active )
            jsp_composite_sprite( sp );
    }

    // clear all dirty bits
    jsp_memzero( jsp_dtt, 96 );
}
