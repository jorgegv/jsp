#include <stdint.h>

#include "jsp.h"

///////////////////////////////////////////////////////////
// Sprite recompositing — Pass 2 of jsp_redraw()
//
// jsp_composite_sprite() composites one sprite straight onto the screen.
// For every dirty cell of the sprite's footprint it:
//   1. reads the current screen cell (background + lower-z sprites)
//   2. composites the sprite's graphic slice into an 8-byte scratch
//   3. writes the scratch back to the screen cell
//   4. applies the sprite colour to attribute memory
//
// Only DIRTY, in-clip, non-foreground cells are touched, so a stationary
// sprite whose cells are not invalidated keeps its pixels (differential
// update), and sprites pass behind foreground tiles.
//
// This is a correct, readable C implementation.  It can be optimised to
// assembly later if profiling shows it is needed.
///////////////////////////////////////////////////////////

// Read the 8 pixel rows of screen cell (row,col) into dst[0..7].
static void read_screen_cell( uint8_t row, uint8_t col, uint8_t *dst ) {
    uint8_t *s = (uint8_t *)( 0x4000
                              + ( (uint16_t)( row & 0x18 ) << 8 )
                              + ( (uint16_t)( row & 0x07 ) << 5 )
                              + col );
    uint8_t k;
    for ( k = 0; k < 8; k++ ) {
        dst[ k ] = *s;
        s += 256;
    }
}

void jsp_composite_sprite( struct jsp_sprite_s *sp ) {
    uint8_t  scratch[ 8 ];
    uint8_t  i, j;
    uint8_t  r0, c0, xrot, yrot, lastcol, cs, ismask2;
    uint8_t *base, *graph, *gleft;
    uint16_t rowstride;

    if ( !sp->flags.initialized || !sp->flags.active )
        return;

    r0   = sp->ypos >> 3;
    c0   = sp->xpos >> 3;
    xrot = sp->xpos & 0x07;
    yrot = sp->ypos & 0x07;

    ismask2 = ( sp->type_ptr == JSP_TYPE_MASK2 );
    cs      = ismask2 ? 16 : 8;     // cell graphic size in bytes

    // horizontal rotation table selector (same formula as the old asm draw)
    jsp_current_rottbl_msb =
        (uint8_t)( ( (uint16_t)jsp_rottbl >> 8 ) + 2 * xrot - 2 );

    // pixel data base, shifted up by the vertical sub-cell offset
    base      = sp->pixels - (uint16_t)yrot * ( cs >> 3 );
    rowstride = (uint16_t)( sp->rows + 1 ) * cs;

    // footprint is cols+1 wide when pixel-shifted, cols wide when aligned
    lastcol = xrot ? sp->cols : (uint8_t)( sp->cols - 1 );

    for ( j = 0; j <= lastcol; j++ ) {
        // data column feeding this footprint column:
        //   left border  (j==0)        -> column 0
        //   middle       (0<j<cols)    -> column j
        //   right border (j>=cols)     -> column cols-1
        uint8_t pdc = ( j == 0 )            ? 0
                    : ( j >= sp->cols )     ? (uint8_t)( sp->cols - 1 )
                    :                         j;

        for ( i = 0; i <= sp->rows; i++ ) {
            uint8_t r = r0 + i;
            uint8_t c = c0 + j;

            if ( !jsp_dtt_is_dirty( r, c ) )            continue;
            if ( jsp_ftt_is_fg( r, c ) )                continue;
            if ( sp->clip && !jsp_cell_in_rect( r, c, sp->clip ) ) continue;

            graph = base + (uint16_t)pdc * rowstride + (uint16_t)i * cs;

            read_screen_cell( r, c, scratch );

            if ( j == 0 ) {
                if ( ismask2 ) sp1_draw_mask2lb( scratch, graph );
                else           sp1_draw_load1lb( scratch, graph );
            } else if ( j >= sp->cols ) {
                if ( ismask2 ) sp1_draw_mask2rb( scratch, graph );
                else           sp1_draw_load1rb( scratch, graph );
            } else {
                gleft = graph - rowstride;
                if ( ismask2 ) sp1_draw_mask2( scratch, graph, gleft );
                else           sp1_draw_load1( scratch, graph, gleft );
            }

            jsp_draw_screen_tile( r, c, scratch );

            if ( sp->color ) {
                volatile uint8_t *a =
                    (volatile uint8_t *)( 0x5800 + (uint16_t)r * 32 + c );
                *a = ( *a & sp->color_mask ) | ( sp->color & ~sp->color_mask );
            }
        }
    }
}
