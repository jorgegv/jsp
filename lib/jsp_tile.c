#include <stdint.h>

#include "jsp.h"

///////////////////////////////////////////////////////////
// Background / foreground tile placement
//
// Recompositing model: tile functions only update the BTT (Background
// Tiles Table), the FTT (Foreground Tiles Table) flag and mark the cell
// dirty.  The actual screen drawing is deferred to jsp_redraw():
//   - background cells: painted from BTT, then composited by sprites
//   - foreground cells: painted from BTT, never composited over
///////////////////////////////////////////////////////////

// draw 8x8 tile to BTT (clears foreground flag, marks cell dirty)
void jsp_draw_background_tile( uint8_t row, uint8_t col, uint8_t *pix ) {
    jsp_btt[ (uint16_t)row * 32 + col ] = pix;
    jsp_ftt_mark_bg( row, col );
    jsp_dtt_mark_dirty( row, col );
}

// restores default background (clears foreground flag, marks cell dirty)
void jsp_delete_background_tile( uint8_t row, uint8_t col ) {
    jsp_draw_background_tile( row, col, jsp_default_bg_tile );
}

// draw 8x8 foreground tile: updates BTT, sets foreground flag, marks cell dirty.
// Foreground cells are painted from BTT by jsp_redraw and never composited
// over by sprites — sprites pass behind them.
void jsp_draw_foreground_tile( uint8_t row, uint8_t col, uint8_t *pix ) {
    jsp_btt[ (uint16_t)row * 32 + col ] = pix;
    jsp_ftt_mark_fg( row, col );
    jsp_dtt_mark_dirty( row, col );
}
