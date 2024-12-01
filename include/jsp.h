#ifndef _JSP_H
#define _JSP_H

#include <stdint.h>

// #define SPECTRUM_128 to use the 128K mode memory layout.  If not
// defined, 48K layout will be used by default

extern uint8_t jsp_rottbl[];
extern uint16_t *jsp_btt[];
extern uint16_t *jsp_drt[];
extern uint8_t jsp_dtt[];

// some utility functions
void jsp_memzero( void *dst, uint16_t numbytes ) __smallc __z88dk_callee;

//////////////////////////
// engine functions
//////////////////////////

// initialize engine
void jsp_init( void );
// redraw dirty parts of screen
void jsp_redraw( void );
// draw 8x8 tile to BTT
void jsp_draw_background_tile( uint8_t row, uint8_t col, uint8_t *pix ) __smallc __z88dk_callee;

// mark/unmark one cell for redraw
void jsp_dtt_mark_dirty( uint8_t row, uint8_t col ) __smallc __z88dk_callee;
void jsp_dtt_mark_clean( uint8_t row, uint8_t col ) __smallc __z88dk_callee;
uint8_t jsp_dtt_is_dirty( uint8_t row, uint8_t col ) __smallc __z88dk_callee;

// draw 8x8 tile to screen
void jsp_draw_screen_tile( uint8_t row, uint8_t col, uint8_t *pix ) __smallc __z88dk_callee;

// draw 8x8 tile to screen with attribute
void jsp_draw_screen_tile_attr( uint8_t row, uint8_t col, uint8_t *pix, uint8_t attr ) __smallc __z88dk_callee;

#endif // _JSP_H
