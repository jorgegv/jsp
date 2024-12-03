#include <stdint.h>
#include <spectrum.h>

#include "jsp.h"

// screen drawing functions

void jsp_draw_screen_tile( uint8_t row, uint8_t col, uint8_t *pix ) __smallc __z88dk_callee {
    uint8_t *dst = zx_cxy2saddr( col, row );
    uint8_t i = 8;
    while ( i-- ) {
        *dst = *pix++;
        dst = zx_saddrpdown( dst );
    }
}

void jsp_draw_screen_tile_attr( uint8_t row, uint8_t col, uint8_t *pix, uint8_t attr ) __smallc __z88dk_callee {
    jsp_draw_screen_tile( row, col, pix );
    *zx_cxy2aaddr( col, row ) = attr;
}

// BTT and DRT drawing functions
void jsp_draw_background_tile( uint8_t row, uint8_t col, uint8_t *pix ) __smallc __z88dk_callee {
    jsp_btt[ row * 32 + col ] = jsp_drt[ row * 32 + col ] = pix;
    jsp_dtt_mark_dirty( row, col );
}

void jsp_delete_background_tile( uint8_t row, uint8_t col ) __smallc __z88dk_callee {
    jsp_btt[ row * 32 + col ] = jsp_drt[ row * 32 + col ] = jsp_default_bg_tile;
    jsp_dtt_mark_dirty( row, col );
}
