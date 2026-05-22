#include <stdint.h>

#include "jsp.h"

///////////////////////////////////////////////////////////
// Per-frame sprite precompute and per-cell compositing
//
// jsp_redraw_begin() runs once per frame: for every active sprite it
// computes the constants the per-cell compositor needs (footprint
// rectangle, pixel base, rotation selector, ...) into jsp_frame_sprites[].
//
// jsp_composite_frame_cell() then composites one cell using only those
// precomputed values — no per-cell recomputation of per-sprite constants.
//
// Correct, readable C; can be optimised to assembly later if needed.
///////////////////////////////////////////////////////////

struct jsp_sprite_frame jsp_frame_sprites[ JSP_SPRITE_REGISTRY_SIZE ];
uint8_t                 jsp_frame_count;

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
}

// Working storage for jsp_redraw_covered_cell, kept off the (small)
// Spectrum stack per the CLAUDE.md guideline.  The function is not
// re-entrant (one cell at a time), so file-scope buffers are safe and
// spare it an IX stack frame.
static uint8_t jsp_covered_scratch[ 8 ];
static uint8_t jsp_covered_attr;

// Render one cell that the asm redraw flagged as sprite-covered: seed an
// 8-byte scratch with the background tile, composite every covering frame
// sprite in z-order, and draw the result with a single store.  Called by
// jsp_redraw (asm) via __z88dk_fastcall; rowcol = (row << 8) | col.
void jsp_redraw_covered_cell( uint16_t rowcol ) __z88dk_fastcall {
    uint8_t  row = (uint8_t)( rowcol >> 8 );
    uint8_t  col = (uint8_t)rowcol;
    uint16_t cell = (uint16_t)row * 32 + col;
    uint8_t  covered = 0, i;

    jsp_covered_attr = jsp_bat[ cell ];

    for ( i = 0; i < jsp_frame_count; i++ ) {
        struct jsp_sprite_frame *fs = &jsp_frame_sprites[ i ];
        if ( row < fs->r0 || row > fs->r1 || col < fs->c0 || col > fs->c1 )
            continue;
        if ( fs->clip && !jsp_cell_in_rect( row, col, fs->clip ) )
            continue;
        if ( !covered ) {
            jsp_memcpy( jsp_covered_scratch, jsp_btt[ cell ], 8 );
            covered = 1;
        }
        jsp_composite_frame_cell( fs, row, col,
                                  jsp_covered_scratch, &jsp_covered_attr );
    }

    if ( covered )
        jsp_draw_screen_tile( row, col, jsp_covered_scratch );
    else
        jsp_draw_screen_tile( row, col, jsp_btt[ cell ] );
    *( (volatile uint8_t *)( 0x5800 + cell ) ) = jsp_covered_attr;
}

// Composite frame-sprite fs's slice of cell (row,col) into scratch[8]
// (which already holds the background and any lower-z sprite). The caller
// must have verified the cell is inside fs's [r0,r1]x[c0,c1] rectangle.
void jsp_composite_frame_cell( struct jsp_sprite_frame *fs,
                               uint8_t row, uint8_t col,
                               uint8_t *scratch, uint8_t *attr ) {
    uint8_t  i = row - fs->r0;
    uint8_t  j = col - fs->c0;
    uint8_t  pdc;
    uint8_t *graph, *gleft;

    jsp_current_rottbl_msb = fs->rottbl_msb;

    // data column feeding this footprint column:
    //   left border  (j==0)     -> column 0
    //   middle       (0<j<cols) -> column j
    //   right border (j>=cols)  -> column cols-1
    pdc = ( j == 0 )        ? 0
        : ( j >= fs->cols ) ? (uint8_t)( fs->cols - 1 )
        :                     j;

    graph = fs->base + (uint16_t)pdc * fs->rowstride + (uint16_t)i * fs->cs;

    if ( j == 0 ) {
        if ( fs->ismask2 ) sp1_draw_mask2lb( scratch, graph );
        else               sp1_draw_load1lb( scratch, graph );
    } else if ( j >= fs->cols ) {
        if ( fs->ismask2 ) sp1_draw_mask2rb( scratch, graph );
        else               sp1_draw_load1rb( scratch, graph );
    } else {
        gleft = graph - fs->rowstride;
        if ( fs->ismask2 ) sp1_draw_mask2( scratch, graph, gleft );
        else               sp1_draw_load1( scratch, graph, gleft );
    }

    if ( fs->color )
        *attr = ( *attr & fs->color_mask ) | ( fs->color & ~fs->color_mask );
}
