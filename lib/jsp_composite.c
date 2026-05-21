#include <stdint.h>

#include "jsp.h"

///////////////////////////////////////////////////////////
// Per-cell sprite compositing
//
// jsp_composite_sprite_cell() composites one cell's slice of one sprite
// into an 8-byte scratch buffer that already holds the background (and
// any lower-z sprite already composited).  jsp_redraw() calls it for
// every active sprite, for every dirty cell, so the final cell content
// is assembled in the scratch and written to the screen with a single
// store — see jsp_redraw.c.
//
// If the sprite does not cover (row,col) the call is a cheap no-op.
//
// Correct, readable C implementation; optimise to assembly later only
// if profiling requires it.
///////////////////////////////////////////////////////////

// Composite sprite sp's contribution to cell (row,col) into scratch[8].
// If sp covers the cell and has a colour, *attr is updated too.
void jsp_composite_sprite_cell( struct jsp_sprite_s *sp,
                                uint8_t row, uint8_t col,
                                uint8_t *scratch, uint8_t *attr ) {
    uint8_t  r0, c0, i, j, xrot, yrot, cs, ismask2, lastcol, pdc;
    uint8_t *base, *graph, *gleft;
    uint16_t rowstride;

    r0 = sp->ypos >> 3;
    c0 = sp->xpos >> 3;

    // reject cells outside the sprite's footprint
    if ( row < r0 || col < c0 )
        return;
    i = row - r0;
    j = col - c0;
    if ( i > sp->rows || j > sp->cols )
        return;

    xrot = sp->xpos & 0x07;
    // footprint is cols+1 wide when pixel-shifted, cols wide when aligned
    lastcol = xrot ? sp->cols : (uint8_t)( sp->cols - 1 );
    if ( j > lastcol )
        return;     // aligned sprite: trailing column is empty

    if ( sp->clip && !jsp_cell_in_rect( row, col, sp->clip ) )
        return;     // per-cell clipping

    yrot    = sp->ypos & 0x07;
    ismask2 = ( sp->type_ptr == JSP_TYPE_MASK2 );
    cs      = ismask2 ? 16 : 8;     // cell graphic size in bytes

    // horizontal rotation table selector
    jsp_current_rottbl_msb =
        (uint8_t)( ( (uint16_t)jsp_rottbl >> 8 ) + 2 * xrot - 2 );

    base      = sp->pixels - (uint16_t)yrot * ( cs >> 3 );
    rowstride = (uint16_t)( sp->rows + 1 ) * cs;

    // data column feeding this footprint column:
    //   left border  (j==0)     -> column 0
    //   middle       (0<j<cols) -> column j
    //   right border (j>=cols)  -> column cols-1
    pdc = ( j == 0 )        ? 0
        : ( j >= sp->cols ) ? (uint8_t)( sp->cols - 1 )
        :                     j;

    graph = base + (uint16_t)pdc * rowstride + (uint16_t)i * cs;

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

    if ( sp->color )
        *attr = ( *attr & sp->color_mask ) | ( sp->color & ~sp->color_mask );
}
