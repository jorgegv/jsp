#include <stdint.h>
#include <spectrum.h>

#include "jsp.h"

void jsp_init_sprite( struct jsp_sprite_s *sp, uint8_t *pixels ) __smallc __z88dk_callee {
    sp->pixels = pixels;
    sp->xpos = sp-> ypos = 255;
    sp->flags.initialized = 1;
}

void jsp_draw_sprite( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) __smallc __z88dk_callee {
    uint8_t i,j,start_row,start_col;

    start_row = ypos / 8;
    start_col = xpos / 8;

    // fill the sprite PDB with the current background
    // cell by cell
    for ( i = 0; i < JSP_SPRITE_HEIGHT_CHARS + 1; i++ )
        for ( j = 0; j < JSP_SPRITE_WIDTH_CHARS + 1; j++ )
            jsp_memcpy( &sp->pdbuf[ ( i * ( JSP_SPRITE_WIDTH_CHARS + 1 ) + j ) * 8 ], jsp_drt[ ( start_row + i ) * 32  + ( start_col + j ) ], 8 );

    return;

    // draw left column
    for ( i = 0; i < JSP_SPRITE_HEIGHT_CHARS + 1; i++ )
        sp1_draw_mask2lb(
            &sp->pdbuf[ i * ( JSP_SPRITE_WIDTH_CHARS + 1 ) * 8 ],	// dst buf
            &sp->pixels[ i * 2 * 8 - ( ypos % 8 ) ],			// sprite data
            &jsp_rottbl[ 512 * ( ( xpos % 8 ) - 1 ) ]			// rot tbl
        );

    // draw middle columns if they exist
    #if JSP_SPRITE_WIDTH_CHARS > 2
    #endif

    // draw right column
}

void jsp_move_sprite( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) __smallc __z88dk_callee {
}
