#include <stdint.h>
#include <spectrum.h>

#include "jsp.h"

// BTT and DRT drawing functions
void jsp_draw_background_tile( uint8_t row, uint8_t col, uint8_t *pix ) __smallc __z88dk_callee {
    jsp_btt[ row * 32 + col ] = jsp_drt[ row * 32 + col ] = pix;
    jsp_dtt_mark_dirty( row, col );
}

void jsp_delete_background_tile( uint8_t row, uint8_t col ) __smallc __z88dk_callee {
    jsp_btt[ row * 32 + col ] = jsp_drt[ row * 32 + col ] = jsp_default_bg_tile;
    jsp_dtt_mark_dirty( row, col );
}
