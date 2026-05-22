#include <stdint.h>

#include "jsp.h"

///////////////////////////////////////////////////////////
// Per-frame sprite precompute
//
// jsp_redraw_begin() runs once per frame: for every active sprite it
// computes the constants the per-cell compositor needs (footprint
// rectangle, pixel base, rotation selector, ...) into jsp_frame_sprites[].
//
// The per-covered-cell compositor itself lives in jsp_composite.asm
// (jsp_redraw_covered_cell) — Task 3.3 folded the former C
// jsp_redraw_covered_cell + jsp_composite_frame_cell into one asm routine.
///////////////////////////////////////////////////////////

struct jsp_sprite_frame jsp_frame_sprites[ JSP_SPRITE_REGISTRY_SIZE ];
uint8_t                 jsp_frame_count;

// Row-sweep state, owned by jsp_composite.asm: the row for which
// cc_row_active[] currently holds the covering frame sprites.  Reset to
// 0xFF here so the first covered cell of the frame rebuilds the set.
extern uint8_t jsp_cc_row_active_row;

// Fill jsp_frame_sprites[] for each active registered sprite; set count.
void jsp_redraw_begin( void ) {
    uint8_t i, n = 0;

    for ( i = 0; i < jsp_sprite_registry_count; i++ ) {
        struct jsp_sprite_s     *sp = jsp_sprite_registry[ i ];
        struct jsp_sprite_frame *fs;
        uint8_t xrot, yrot, cs;

        if ( !sp->flags.initialized || !sp->flags.active )
            continue;

        fs = &jsp_frame_sprites[ n++ ];

        fs->r0 = sp->ypos >> 3;
        fs->c0 = sp->xpos >> 3;
        fs->r1 = fs->r0 + sp->rows;

        xrot = sp->xpos & 0x07;
        yrot = sp->ypos & 0x07;
        // footprint is cols+1 wide when pixel-shifted, cols wide when aligned
        fs->c1 = fs->c0 + ( xrot ? sp->cols : (uint8_t)( sp->cols - 1 ) );

        fs->ismask2 = ( sp->type_ptr == JSP_TYPE_MASK2 );
        cs          = fs->ismask2 ? 16 : 8;
        fs->cs      = cs;
        fs->cols    = sp->cols;

        fs->rottbl_msb =
            (uint8_t)( ( (uint16_t)jsp_rottbl >> 8 ) + 2 * xrot - 2 );
        fs->base      = sp->pixels - (uint16_t)yrot * ( cs >> 3 );
        fs->rowstride = (uint16_t)( sp->rows + 1 ) * cs;

        fs->color      = sp->color;
        fs->color_mask = sp->color_mask;
        fs->clip       = sp->clip;
    }
    jsp_frame_count = n;

    // invalidate the row-sweep set so the first covered cell rebuilds it
    jsp_cc_row_active_row = 0xFF;
}
