#ifndef _JSP_H
#define _JSP_H

///////////////////////////////////////////////////////
//
// JSP SPRITE LIBRARY PUBLIC API
// Copyright 2024 ZXjogv <zx@jogv.es>
// Based on SP1 Sprite Library by Alvin Albrecht
//
///////////////////////////////////////////////////////

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

// sprite data structure
struct jsp_sprite_s {
    // sprite size in chars
    uint8_t rows;	// ofs: +0
    uint8_t cols;	// ofs: +1

    // sprite current position
    uint8_t xpos;	// ofs: +2
    uint8_t ypos;	// ofs: +3

    // sprite flags
    struct {
        int initialized:1;
    } flags;		// ofs: +4

    // pointer to pixel data - they can be changed at any moment, for
    // animations, etc.
    uint8_t *pixels;	// ofs: +5

    // pointer to Private Drawing Buffer of (m+1)x(n+1) chars
    uint8_t *pdbuf;	// ofs: +7

    // sprite type (16 bits) - pointer to table of drawing functions,
    // but it's handled automatically by macros
    uint8_t *type_ptr;	// ofs: +9
};

void jsp_init_sprite( struct jsp_sprite_s *sp ) __z88dk_fastcall;
void jsp_draw_sprite_mask2( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) __smallc __z88dk_callee;
void jsp_move_sprite_mask2( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) __smallc __z88dk_callee;
void jsp_draw_sprite_load1( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) __smallc __z88dk_callee;
void jsp_move_sprite_load1( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) __smallc __z88dk_callee;

void jsp_move_sprite( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) __smallc __z88dk_callee;
void jsp_draw_sprite( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) __smallc __z88dk_callee;

#define DEFINE_SPRITE(_name,_rows,_cols,_pixels,_xpos,_ypos,_type) uint8_t _name##_pdbuf[ ( (_rows) + 1 ) * ( (_cols) + 1 ) * 8 ]; struct jsp_sprite_s _name = { .rows = (_rows), .cols = (_cols), .xpos = (_xpos), .ypos = (_ypos), .flags.initialized = 1, .pixels = (_pixels), .pdbuf = _name##_pdbuf, .type_ptr = _type }

//////////////////////////////////////////////////////
// Internal JSP Library functions and library data
//////////////////////////////////////////////////////

extern uint8_t	jsp_rottbl[];
extern uint16_t	*jsp_btt[];
extern uint16_t	*jsp_drt[];
extern uint8_t	jsp_dtt[];
extern uint8_t	*jsp_default_bg_tile;
extern uint8_t jsp_current_rottbl_msb;

extern uint8_t JSP_TYPE_LOAD1[];
extern uint8_t JSP_TYPE_MASK2[];


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

#endif // _JSP_H
