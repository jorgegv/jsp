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

// Maximum number of sprites the redraw loop will composite.  All sprites
// drawn/moved are registered here so jsp_redraw() can recomposite them.
// Override with -DJSP_SPRITE_REGISTRY_SIZE=N at build time if needed.
#ifndef JSP_SPRITE_REGISTRY_SIZE
#define JSP_SPRITE_REGISTRY_SIZE 16
#endif

/////////////////////////////////////////
// Engine functions
/////////////////////////////////////////

// initialize engine, set default background tile and default attribute
void jsp_init( uint8_t *default_bg_tile, uint8_t default_attr );
// redraw dirty parts of screen (three-pass recompositing)
void jsp_redraw( void );

/////////////////////////////////////////
// Background tile functions
/////////////////////////////////////////

// draw 8x8 tile to BTT (clears foreground flag, marks cell dirty)
void jsp_draw_background_tile( uint8_t row, uint8_t col, uint8_t *pix );
// restores default background (clears foreground flag, marks cell dirty)
void jsp_delete_background_tile( uint8_t row, uint8_t col );
// draw 8x8 foreground tile: updates BTT, sets foreground flag, marks cell dirty.
// Foreground cells are painted from BTT by jsp_redraw and never composited over
// by sprites (sprites pass behind them).
void jsp_draw_foreground_tile( uint8_t row, uint8_t col, uint8_t *pix );

/////////////////////////////////////////
// Sprite functions and data structures
/////////////////////////////////////////

// rectangular region (cell coordinates)
struct jsp_rect {
    uint8_t row;
    uint8_t col;
    uint8_t width;
    uint8_t height;
};

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
        int initialized:1;  // bit 0 - slot is in use
        int active:1;       // bit 1 - sprite is composited each redraw
        int registered:1;   // bit 2 - sprite is present in the redraw registry
    } flags;		// ofs: +4

    // pointer to pixel data - can be changed at any moment (animation, etc.)
    uint8_t *pixels;	// ofs: +5

    // sprite type (16 bits) - pointer to table of drawing functions,
    // handled automatically by the jsp_*_mask2 / jsp_*_load1 wrappers
    uint8_t *type_ptr;	// ofs: +7

    // sprite colour attribute applied each frame (0 = no colour management)
    uint8_t color;		// ofs: +9
    // colour mask: 0xF8 = preserve PAPER/BRIGHT, replace INK only; 0x00 = full replace
    uint8_t color_mask;	// ofs: +10

    // clip rectangle (cell coords); NULL = no clipping.  Sprite cells outside
    // this rect are not composited (per-cell clipping, matches SP1).
    struct jsp_rect *clip;	// ofs: +11
};

void jsp_init_sprite( struct jsp_sprite_s *sp ) __z88dk_fastcall;

// Deferred sprite operations: they update sprite state and mark cells dirty;
// the actual compositing happens in the next jsp_redraw().
void jsp_move_sprite( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos );
void jsp_draw_sprite( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos );

// C-level wrappers: set sprite type, then defer draw/move
void jsp_draw_sprite_mask2( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos );
void jsp_move_sprite_mask2( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos );
void jsp_draw_sprite_load1( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos );
void jsp_move_sprite_load1( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos );

// Safe off-screen parking: mark cells dirty and flag sprite as inactive
void jsp_sprite_park( struct jsp_sprite_s *sp );

// Frame-based movement (sets pixels, then defers move)
void jsp_move_sprite_mask2_frame( struct jsp_sprite_s *sp, uint8_t *frame,
                                  uint8_t xpos, uint8_t ypos );
void jsp_move_sprite_load1_frame( struct jsp_sprite_s *sp, uint8_t *frame,
                                  uint8_t xpos, uint8_t ypos );
void jsp_move_sprite_frame( struct jsp_sprite_s *sp, uint8_t *frame,
                            uint8_t xpos, uint8_t ypos );

// Bounding-box check: 1 if sprite at (xpos,ypos) is fully inside rect, else 0
uint8_t jsp_sprite_in_rect( struct jsp_sprite_s *sp,
                            struct jsp_rect *rect,
                            uint8_t xpos, uint8_t ypos );

// Set the per-cell clip rectangle for a sprite (NULL = no clipping)
void jsp_sprite_set_clip( struct jsp_sprite_s *sp, struct jsp_rect *clip );

// Dynamic sprite pool — caller supplies storage, JSP manages slot allocation.
// No per-sprite drawing buffers are needed any more (recompositing model).
void jsp_sprite_pool_init( struct jsp_sprite_s *pool, uint8_t pool_size );
struct jsp_sprite_s *jsp_sprite_alloc( uint8_t rows, uint8_t cols );
void jsp_sprite_free( struct jsp_sprite_s *sp );

// Set the colour applied to all sprite cells each frame.
void jsp_sprite_set_color( struct jsp_sprite_s *sp, uint8_t color, uint8_t color_mask );
// Write colour to attribute memory for the sprite's current cell positions.
void jsp_apply_sprite_color( struct jsp_sprite_s *sp );

// Text print context
struct jsp_print_ctx {
    struct jsp_rect *clip;  // clipping area (NULL = full screen)
    uint8_t          attr;  // text colour attribute byte
    uint8_t          row;   // current print row (cell coordinate)
    uint8_t          col;   // current print col (cell coordinate)
};

// Static initialiser: JSP_PRINT_CTX_INIT(area, attr)
#define JSP_PRINT_CTX_INIT(rect,at)  { &(rect), (at), 0, 0 }

void jsp_print_set_pos( struct jsp_print_ctx *ctx, uint8_t row, uint8_t col );
void jsp_print_string( struct jsp_print_ctx *ctx, const char *str );

// Rectangle-operation flags (mirror SP1 values for easy aliasing)
#define JSP_RFLAG_TILE   0x01
#define JSP_RFLAG_COLOUR 0x02

// Clear a rectangular region (tile and/or colour, controlled by flags)
void jsp_clear_rect( struct jsp_rect *rect, uint8_t attr,
                     uint8_t ch, uint8_t flags );
// Mark all cells in rect as dirty (redrawn on next jsp_redraw)
void jsp_invalidate_rect( struct jsp_rect *rect );

// Tile table (256 entries; 32-127 pre-filled with ROM font by jsp_init)
extern uint8_t *jsp_tile_table[256];
// Register 8-byte tile graphic at 1-byte index (equivalent to sp1_TileEntry)
void jsp_tile_register( uint8_t idx, uint8_t *gfx_ptr );
// Draw tile at (row,col) with colour attribute; tile<256 = table lookup, else direct pointer
void jsp_tile_put( uint8_t row, uint8_t col, uint8_t attr, uint16_t tile );

// Define a standalone sprite (not pool-allocated).  No drawing buffer is
// needed any more — sprites composite straight to the screen during redraw.
#define DEFINE_SPRITE(_name,_rows,_cols,_pixels,_xpos,_ypos,_type) \
    struct jsp_sprite_s _name = { .rows = (_rows), .cols = (_cols), \
        .xpos = (_xpos), .ypos = (_ypos), .flags.initialized = 1, \
        .pixels = (_pixels), .type_ptr = (_type) }

//////////////////////////////////////////////////////
// Internal JSP Library functions and library data
//////////////////////////////////////////////////////

extern uint8_t	jsp_rottbl[];
extern uint8_t	*jsp_btt[];
extern uint8_t	jsp_dtt[];
extern uint8_t	jsp_ftt[];
extern uint8_t	jsp_bat[];
extern uint8_t	*jsp_default_bg_tile;
extern uint8_t  jsp_current_rottbl_msb;

extern uint8_t JSP_TYPE_LOAD1[];
extern uint8_t JSP_TYPE_MASK2[];

// Sprite registry — walked by jsp_redraw to recomposite all active sprites.
extern struct jsp_sprite_s *jsp_sprite_registry[ JSP_SPRITE_REGISTRY_SIZE ];
extern uint8_t              jsp_sprite_registry_count;
void jsp_register_sprite( struct jsp_sprite_s *sp );
void jsp_unregister_sprite( struct jsp_sprite_s *sp );
void jsp_registry_reset( void );

// Per-sprite per-frame precomputed compositing data.  jsp_redraw_begin()
// fills one entry for each active sprite once per frame, so the per-cell
// composite path does not recompute per-sprite constants.  Field offsets
// are fixed (the asm redraw reads r0/c0/r1/c1 at +0..+3).
struct jsp_sprite_frame {
    uint8_t  r0, c0;            // ofs +0,+1  footprint origin cell
    uint8_t  r1, c1;            // ofs +2,+3  last drawn row/col (inclusive)
    uint8_t  cs;                // ofs +4     cell graphic size (8 or 16)
    uint8_t  ismask2;           // ofs +5
    uint8_t  rottbl_msb;        // ofs +6
    uint8_t  cols;              // ofs +7
    uint8_t  color;             // ofs +8
    uint8_t  color_mask;        // ofs +9
    uint8_t *base;              // ofs +10    pixel base (pixels - yrot*cs/8)
    uint16_t rowstride;         // ofs +12    (rows+1)*cs
    struct jsp_rect *clip;      // ofs +14
};

extern struct jsp_sprite_frame jsp_frame_sprites[ JSP_SPRITE_REGISTRY_SIZE ];
extern uint8_t                 jsp_frame_count;

// Precompute jsp_frame_sprites[] / jsp_frame_count for every active
// registered sprite. Called once per frame at the start of jsp_redraw.
void jsp_redraw_begin( void );

// Composite one frame-sprite's contribution to cell (row,col) into an
// 8-byte scratch buffer. The caller must have verified the cell is inside
// the frame-sprite's [r0,r1]x[c0,c1] rectangle. *attr gets the colour.
void jsp_composite_frame_cell( struct jsp_sprite_frame *fs,
                               uint8_t row, uint8_t col,
                               uint8_t *scratch, uint8_t *attr );

// Render one sprite-covered cell (composite + draw). Called by the asm
// jsp_redraw; rowcol = (row << 8) | col.
void jsp_redraw_covered_cell( uint16_t rowcol ) __z88dk_fastcall;

// 1 if cell (row,col) is inside rect (cell coordinates), else 0
uint8_t jsp_cell_in_rect( uint8_t row, uint8_t col, struct jsp_rect *rect );

// mark/unmark one cell for redraw
void jsp_dtt_mark_dirty( uint8_t row, uint8_t col ) __smallc __z88dk_callee;
void jsp_dtt_mark_clean( uint8_t row, uint8_t col ) __smallc __z88dk_callee;
uint8_t jsp_dtt_is_dirty( uint8_t row, uint8_t col ) __smallc __z88dk_callee;

// mark/unmark one cell as foreground
void jsp_ftt_mark_fg( uint8_t row, uint8_t col ) __smallc __z88dk_callee;
void jsp_ftt_mark_bg( uint8_t row, uint8_t col ) __smallc __z88dk_callee;
uint8_t jsp_ftt_is_fg( uint8_t row, uint8_t col ) __smallc __z88dk_callee;

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
