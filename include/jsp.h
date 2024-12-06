#ifndef _JSP_H
#define _JSP_H

#include <stdint.h>

// #define SPECTRUM_128 to use the 128K memory layout.  If not
// defined, 48K memory layout will be used by default

/////////////////////////////////////////
// Engine functions
/////////////////////////////////////////

// initialize engine, set default background tile
void jsp_init( uint8_t *default_bg_tile );
// redraw dirty parts of screen
void jsp_redraw( void );

/////////////////////////////////////////
// Background tile functions
/////////////////////////////////////////

// draw 8x8 tile to BTT
void jsp_draw_background_tile( uint8_t row, uint8_t col, uint8_t *pix ) __smallc __z88dk_callee;
// resotres default background
void jsp_delete_background_tile( uint8_t row, uint8_t col ) __smallc __z88dk_callee;

/////////////////////////////////////////
// Sprite functions and data structures
/////////////////////////////////////////

// All sprites in the game are the same size.  You can just change these
// values and recompile, the engine will reconfigure for the given sizes

#define JSP_SPRITE_WIDTH_CHARS	2
#define JSP_SPRITE_HEIGHT_CHARS	2

///////////////////////////////////////

// sprite data structure
struct jsp_sprite_s {
    // pointer to pixel data - they can be changed at any moment, for
    // animations, etc.
    uint8_t *pixels;

    // sprite size is not stored, it's fixed at compile time (see above)
    // sprite current position
    uint8_t xpos;
    uint8_t ypos;

    // sprite flags
    struct {
        int initialized:1;
    } flags;

    // Private Drawing Buffer of (m+1)x(n+1) chars
    // Last element in struct, so previous elements can be accessed with
    // short offsets (i.e.  ix+n, etc.)
    uint8_t pdbuf[ ( JSP_SPRITE_WIDTH_CHARS + 1 ) * ( JSP_SPRITE_HEIGHT_CHARS + 1 ) * 8 ];
};

void jsp_init_sprite( struct jsp_sprite_s *sp, uint8_t *pixels ) __smallc __z88dk_callee;
void jsp_draw_sprite( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) __smallc __z88dk_callee;
void jsp_move_sprite( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) __smallc __z88dk_callee;

/////////////////////////////////////////
// Internal functions and library data
/////////////////////////////////////////

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
void sp1_draw_mask2( uint8_t *dst, uint8_t *graph, uint8_t *graph_left, uint8_t *rottbl ) __smallc __z88dk_callee;
void sp1_draw_mask2nr( uint8_t *dst, uint8_t *graph ) __smallc __z88dk_callee;
void sp1_draw_mask2lb( uint8_t *dst, uint8_t *graph, uint8_t *rottbl ) __smallc __z88dk_callee;
void sp1_draw_mask2rb( uint8_t *dst, uint8_t *graph, uint8_t *graph_left, uint8_t *rottbl ) __smallc __z88dk_callee;

#endif // _JSP_H
