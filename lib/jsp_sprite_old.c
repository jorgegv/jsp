#include <stdint.h>
#include <spectrum.h>
#include <stdio.h>

#include "jsp.h"

void jsp_init_sprite( struct jsp_sprite_s *sp ) __z88dk_fastcall {
    sp->xpos = sp->ypos = 0;
    sp->flags.initialized = 1;
}

// var definitions as global for optimized access
uint8_t i,j,start_row,start_col;
uint8_t *bg_ptr,*pix_ptr,*pix_ptr_left,*rottbl;

void _jsp_draw_sprite( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) __smallc __z88dk_callee {
    
    if ( ! sp->flags.initialized ) return;

    start_row = ypos / 8;
    start_col = xpos / 8;

    rottbl = &jsp_rottbl[ 512 * ( xpos % 8 ) ] - 512;

    // fill the sprite PDB with the current DRT records as background
    // cell by cell
    for ( i = 0; i < sp->rows + 1; i++ )
        for ( j = 0; j < sp->cols + 1; j++ )
            jsp_memcpy( &sp->pdbuf[ ( i * ( sp->cols + 1 ) + j ) * 8 ], jsp_drt[ ( start_row + i ) * 32  + ( start_col + j ) ], 8 );

    // initialize pointers for drawing
    pix_ptr = pix_ptr_left = sp->pixels - ( ypos % 8 ) * 2;

    // draw left column
    bg_ptr = &sp->pdbuf[ 0 ];
    for ( i = 0; i < sp->rows + 1; i++ ) {
        sp1_draw_mask2lb( bg_ptr, pix_ptr, rottbl );
        bg_ptr += ( sp->cols + 1 ) * 8;
        pix_ptr += 16;
    }
            
    // draw middle columns if they exist
    for ( j = 1; j < sp->cols; j++ ) {
        bg_ptr = &sp->pdbuf[ j * 8 ];
        for ( i = 0; i < sp->rows + 1; i++ ) {
            sp1_draw_mask2( bg_ptr, pix_ptr, pix_ptr_left, rottbl );
            bg_ptr += ( sp->cols + 1 ) * 8;
            pix_ptr += 16;
            pix_ptr_left += 16;
        }
    }
    
    // draw right column if needed
    if ( xpos % 8 ) {
        bg_ptr = &sp->pdbuf[ sp->cols * 8 ];
        // the right column uses the same data as the last middle one, i.e. pix_ptr_left
        pix_ptr = pix_ptr_left;
        for ( i = 0; i < sp->rows + 1; i++ ) {
            sp1_draw_mask2rb( bg_ptr, pix_ptr, rottbl );
            bg_ptr += ( sp->cols + 1 ) * 8;
            pix_ptr += 16;
        }
    }

    // update DRT pointers and mark cells as dirty
    for ( i = 0; i < sp->rows + 1; i++ )
        for ( j = 0; j < sp->cols + 1; j++ ) {
            jsp_drt[ ( start_row + i ) * 32  + ( start_col + j ) ] = &sp->pdbuf[ ( i * ( sp->cols + 1 ) + j ) * 8 ];
            jsp_dtt_mark_dirty( start_row + i, start_col + j );
        }

    // update sprite with new pos
    sp->xpos = xpos;
    sp->ypos = ypos;
}


void _jsp_move_sprite( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) __smallc __z88dk_callee {

    // mark old positions as dirty
    start_row = sp->ypos / 8;
    start_col = sp->xpos / 8;

    for ( i = 0; i < sp->rows + 1; i++ )
        for ( j = 0; j < sp->cols + 1; j++ )
            jsp_dtt_mark_dirty( start_row + i, start_col + j );

    // draw on new position
    jsp_draw_sprite( sp, xpos, ypos );
}
