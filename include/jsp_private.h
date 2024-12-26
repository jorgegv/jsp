#ifndef _JSP_PRIVATE_H
#define _JSP_PRIVATE_H

//////////////////////////////////////////////////////
// Internal JSP Library functions and library data
//////////////////////////////////////////////////////

extern uint8_t	jsp_rottbl[];
extern uint16_t	*jsp_btt[];
extern uint16_t	*jsp_drt[];
extern uint8_t	jsp_dtt[];
extern uint8_t	*jsp_default_bg_tile;

// mark/unmark one cell for redraw
void jsp_dtt_mark_dirty( uint8_t row, uint8_t col ) __smallc __z88dk_callee;
void jsp_dtt_mark_clean( uint8_t row, uint8_t col ) __smallc __z88dk_callee;
uint8_t jsp_dtt_is_dirty( uint8_t row, uint8_t col ) __smallc __z88dk_callee;

// draw 8x8 tile to screen
void jsp_draw_screen_tile( uint8_t row, uint8_t col, uint8_t *pix ) __smallc __z88dk_callee;

// draw 8x8 tile to screen with attribute
void jsp_draw_screen_tile_attr( uint8_t row, uint8_t col, uint8_t *pix, uint8_t attr ) __smallc __z88dk_callee;

// some utility functions
void jsp_memzero( void *dst, uint16_t numbytes ) __smallc __z88dk_callee;
void jsp_memcpy( void *dst, void *src, uint16_t numbytes ) __smallc __z88dk_callee;

// drawing wrappers for hijacked SP1 functions (thanks Alvin ;-) )
void sp1_draw_mask2( uint8_t *dst, uint8_t *graph, uint8_t *graph_left ) __smallc __z88dk_callee;
void sp1_draw_mask2nr( uint8_t *dst, uint8_t *graph ) __smallc __z88dk_callee;
void sp1_draw_mask2lb( uint8_t *dst, uint8_t *graph ) __smallc __z88dk_callee;
void sp1_draw_mask2rb( uint8_t *dst, uint8_t *graph ) __smallc __z88dk_callee;

void sp1_draw_load1( uint8_t *dst, uint8_t *graph, uint8_t *graph_left ) __smallc __z88dk_callee;
void sp1_draw_load1nr( uint8_t *dst, uint8_t *graph ) __smallc __z88dk_callee;
void sp1_draw_load1lb( uint8_t *dst, uint8_t *graph ) __smallc __z88dk_callee;
void sp1_draw_load1rb( uint8_t *dst, uint8_t *graph ) __smallc __z88dk_callee;

#endif	// _JSP_PRIVATE_H
