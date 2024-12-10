#include <stdint.h>
#include <spectrum.h>
#include <stdio.h>

#include "jsp.h"

void jsp_init_sprite( struct jsp_sprite_s *sp, uint8_t *pixels ) __smallc __z88dk_callee {
    sp->pixels = pixels;
    sp->xpos = sp-> ypos = 255;
    sp->flags.initialized = 1;
}

void jsp_draw_sprite( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) __smallc __z88dk_callee {
    uint8_t i,j,start_row,start_col;
    uint8_t *bg_ptr,*pix_ptr,*pix_ptr_left,*rottbl;

    start_row = ypos / 8;
    start_col = xpos / 8;

    rottbl = &jsp_rottbl[ 512 * ( ( xpos % 8 ) - 1 ) ];

    // fill the sprite PDB with the current background
    // cell by cell
    for ( i = 0; i < JSP_SPRITE_HEIGHT_CHARS + 1; i++ )
        for ( j = 0; j < JSP_SPRITE_WIDTH_CHARS + 1; j++ )
            jsp_memcpy( &sp->pdbuf[ ( i * ( JSP_SPRITE_WIDTH_CHARS + 1 ) + j ) * 8 ], jsp_drt[ ( start_row + i ) * 32  + ( start_col + j ) ], 8 );
    
    // initialize pointers for drawing
    pix_ptr = pix_ptr_left = sp->pixels - ( ypos % 8 );

    // draw left column
    bg_ptr = &sp->pdbuf[ 0 ];
    for ( i = 0; i < JSP_SPRITE_HEIGHT_CHARS + 1; i++ ) {
        sp1_draw_mask2lb( bg_ptr, pix_ptr, rottbl );
        bg_ptr += ( JSP_SPRITE_WIDTH_CHARS + 1 ) * 8;
        pix_ptr += 16;
    }
            
    // draw middle columns if they exist
    #if JSP_SPRITE_WIDTH_CHARS > 1
    bg_ptr = &sp->pdbuf[ 8 ];
    for ( i = 0; i < JSP_SPRITE_HEIGHT_CHARS + 1; i++ ) {
        sp1_draw_mask2( bg_ptr, pix_ptr, pix_ptr_left, rottbl );
        bg_ptr += ( JSP_SPRITE_WIDTH_CHARS + 1 ) * 8;
        pix_ptr += 16;
        pix_ptr_left += 16;
    }
    #endif

    // draw right column
    bg_ptr = &sp->pdbuf[ JSP_SPRITE_WIDTH_CHARS * 8 ];
    // the right column is the same as the last middle one, i.e. the last pix_ptr_left
    pix_ptr = pix_ptr_left;
    for ( i = 0; i < JSP_SPRITE_HEIGHT_CHARS + 1; i++ ) {
        sp1_draw_mask2rb( bg_ptr, pix_ptr, rottbl );
        bg_ptr += ( JSP_SPRITE_WIDTH_CHARS + 1 ) * 8;
        pix_ptr += 16;
    }

}

void jsp_move_sprite( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) __smallc __z88dk_callee {
}
