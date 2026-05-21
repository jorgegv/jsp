#include <stdint.h>

#include "jsp.h"

///////////////////////////////////////////////////////////
// Per-cell sprite coverage and compositing
//
// jsp_redraw() first calls jsp_sprite_covers_cell() to decide whether a
// sprite touches a given dirty cell; if so it seeds an 8-byte scratch
// with the background tile and calls jsp_composite_sprite_cell() for
// each covering sprite, in z-order.  The final cell content is then
// written to the screen with a single store — see jsp_redraw.c.
//
// Correct, readable C; can be optimised to assembly later if needed.
///////////////////////////////////////////////////////////

// 1 if sprite sp's footprint covers cell (row,col) and that cell is
// actually drawn (in-clip, not the empty trailing column of an aligned
// sprite); 0 otherwise.
uint8_t jsp_sprite_covers_cell( struct jsp_sprite_s *sp,
                                uint8_t row, uint8_t col ) {
    uint8_t r0 = sp->ypos >> 3;
    uint8_t c0 = sp->xpos >> 3;
    uint8_t i, j, lastcol;

    if ( row < r0 || col < c0 )
        return 0;
    i = row - r0;
    j = col - c0;
    if ( i > sp->rows || j > sp->cols )
        return 0;

    // footprint is cols+1 wide when pixel-shifted, cols wide when aligned
    lastcol = ( sp->xpos & 0x07 ) ? sp->cols : (uint8_t)( sp->cols - 1 );
    if ( j > lastcol )
        return 0;

    if ( sp->clip && !jsp_cell_in_rect( row, col, sp->clip ) )
        return 0;

    return 1;
}

// Composite sprite sp's slice of cell (row,col) into scratch[8] (which
// already holds the background and any lower-z sprite).  The caller MUST
// have verified jsp_sprite_covers_cell() first.  *attr is updated if the
// sprite has a colour.
void jsp_composite_sprite_cell( struct jsp_sprite_s *sp,
                                uint8_t row, uint8_t col,
                                uint8_t *scratch, uint8_t *attr ) {
    uint8_t  i = row - ( sp->ypos >> 3 );
    uint8_t  j = col - ( sp->xpos >> 3 );
    uint8_t  xrot = sp->xpos & 0x07;
    uint8_t  yrot = sp->ypos & 0x07;
    uint8_t  ismask2 = ( sp->type_ptr == JSP_TYPE_MASK2 );
    uint8_t  cs = ismask2 ? 16 : 8;     // cell graphic size in bytes
    uint8_t  pdc;
    uint8_t *base, *graph, *gleft;
    uint16_t rowstride;

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
