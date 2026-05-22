#include <stdint.h>

#include "jsp.h"

///////////////////////////////////////////////////////////
// Sprite registry
//
// In the recompositing model jsp_redraw() must recomposite every active
// sprite each frame.  Sprites register themselves here the first time
// they are drawn or moved; jsp_redraw() walks the registry in order
// (registration order = back-to-front z-order).
///////////////////////////////////////////////////////////

struct jsp_sprite_s *jsp_sprite_registry[ JSP_SPRITE_REGISTRY_SIZE ];
uint8_t              jsp_sprite_registry_count;

void jsp_registry_reset( void ) {
    uint8_t i;
    for ( i = 0; i < jsp_sprite_registry_count; i++ )
        jsp_sprite_registry[ i ]->flags.registered = 0;
    jsp_sprite_registry_count = 0;
}

void jsp_register_sprite( struct jsp_sprite_s *sp ) __z88dk_fastcall {
    if ( sp->flags.registered )
        return;
    if ( jsp_sprite_registry_count >= JSP_SPRITE_REGISTRY_SIZE )
        return;     // registry full — sprite will not be composited
    sp->flags.registered = 1;
    jsp_sprite_registry[ jsp_sprite_registry_count++ ] = sp;
}

void jsp_unregister_sprite( struct jsp_sprite_s *sp ) __z88dk_fastcall {
    uint8_t i, j;
    if ( !sp->flags.registered )
        return;
    for ( i = 0; i < jsp_sprite_registry_count; i++ ) {
        if ( jsp_sprite_registry[ i ] == sp ) {
            for ( j = i; j + 1 < jsp_sprite_registry_count; j++ )
                jsp_sprite_registry[ j ] = jsp_sprite_registry[ j + 1 ];
            jsp_sprite_registry_count--;
            break;
        }
    }
    sp->flags.registered = 0;
}

///////////////////////////////////////////////////////////
// Helpers
///////////////////////////////////////////////////////////

// 1 if cell (row,col) is inside rect (cell coordinates), else 0
uint8_t jsp_cell_in_rect( uint8_t row, uint8_t col, struct jsp_rect *rect ) {
    if ( col < rect->col || row < rect->row )                   return 0;
    if ( col >= (uint8_t)( rect->col + rect->width ) )          return 0;
    if ( row >= (uint8_t)( rect->row + rect->height ) )         return 0;
    return 1;
}

// Mark every cell of the inclusive rectangle [r0..r1] x [c0..c1] dirty.
// Walks the DTT bitmap directly with a rotating mask and running byte
// index — no per-cell function call, no per-cell cell-index recompute.
// r1/c1 are clamped to the 24x32 screen, so an off-screen footprint
// marks only its on-screen part instead of writing past the DTT.
void jsp_dtt_mark_rect( uint8_t r0, uint8_t c0, uint8_t r1, uint8_t c1 ) {
    uint8_t  r, c, mask;
    uint16_t cell, byte;

    if ( r1 > 23 ) r1 = 23;
    if ( c1 > 31 ) c1 = 31;
    for ( r = r0; r <= r1; r++ ) {
        cell = (uint16_t)r * 32 + c0;
        byte = cell >> 3;
        mask = 1 << ( cell & 7 );        // one variable shift per row
        for ( c = c0; c <= c1; c++ ) {
            jsp_dtt[ byte ] |= mask;
            mask <<= 1;
            if ( mask == 0 ) { mask = 1; byte++; }
        }
    }
}

// Mark the sprite's (rows+1)x(cols+1) footprint dirty.  If clip != NULL,
// the footprint is intersected with the clip rectangle first (rectangle
// ∩ rectangle is a rectangle), so a single jsp_dtt_mark_rect call covers
// it — no per-cell clip test.
static void mark_footprint_dirty( struct jsp_sprite_s *sp, struct jsp_rect *clip ) {
    uint8_t r0 = sp->ypos >> 3;
    uint8_t c0 = sp->xpos >> 3;
    uint8_t r1 = r0 + sp->rows;
    uint8_t c1 = c0 + sp->cols;

    if ( clip ) {
        uint8_t cr1 = clip->row + clip->height - 1;
        uint8_t cc1 = clip->col + clip->width  - 1;
        if ( r0 < clip->row ) r0 = clip->row;
        if ( c0 < clip->col ) c0 = clip->col;
        if ( r1 > cr1 )       r1 = cr1;
        if ( c1 > cc1 )       c1 = cc1;
        if ( r0 > r1 || c0 > c1 )
            return;                      // footprint fully outside the clip
    }
    jsp_dtt_mark_rect( r0, c0, r1, c1 );
}

///////////////////////////////////////////////////////////
// Deferred draw / move / park
//
// These never touch the screen: they update sprite state and mark cells
// dirty.  Compositing happens in the next jsp_redraw().
///////////////////////////////////////////////////////////

// first draw / unpark: place sprite, activate, mark new footprint dirty
void jsp_draw_sprite( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) {
    if ( !sp->flags.initialized )
        return;
    jsp_register_sprite( sp );
    sp->xpos = xpos;
    sp->ypos = ypos;
    sp->flags.active = 1;
    mark_footprint_dirty( sp, sp->clip );
}

// move: mark OLD footprint dirty (unclipped), reposition, mark NEW dirty (clipped)
void jsp_move_sprite( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) {
    if ( !sp->flags.initialized )
        return;
    jsp_register_sprite( sp );
    if ( sp->flags.active )
        mark_footprint_dirty( sp, 0 );      // old position
    sp->xpos = xpos;
    sp->ypos = ypos;
    sp->flags.active = 1;
    mark_footprint_dirty( sp, sp->clip );   // new position
}

// park: mark footprint dirty and deactivate (no longer composited)
void jsp_sprite_park( struct jsp_sprite_s *sp ) __z88dk_fastcall {
    if ( sp->flags.active )
        mark_footprint_dirty( sp, 0 );
    sp->flags.active = 0;
}

///////////////////////////////////////////////////////////
// C-level wrappers — set sprite type, then defer
///////////////////////////////////////////////////////////

void jsp_move_sprite_mask2( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) {
    sp->type_ptr = JSP_TYPE_MASK2;
    jsp_move_sprite( sp, xpos, ypos );
}

void jsp_draw_sprite_mask2( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) {
    sp->type_ptr = JSP_TYPE_MASK2;
    jsp_draw_sprite( sp, xpos, ypos );
}

void jsp_move_sprite_load1( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) {
    sp->type_ptr = JSP_TYPE_LOAD1;
    jsp_move_sprite( sp, xpos, ypos );
}

void jsp_draw_sprite_load1( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) {
    sp->type_ptr = JSP_TYPE_LOAD1;
    jsp_draw_sprite( sp, xpos, ypos );
}

///////////////////////////////////////////////////////////
// Frame-based movement
///////////////////////////////////////////////////////////

void jsp_move_sprite_mask2_frame( struct jsp_sprite_s *sp, uint8_t *frame,
                                  uint8_t xpos, uint8_t ypos ) {
    sp->pixels   = frame;
    sp->type_ptr = JSP_TYPE_MASK2;
    jsp_move_sprite( sp, xpos, ypos );
}

void jsp_move_sprite_load1_frame( struct jsp_sprite_s *sp, uint8_t *frame,
                                  uint8_t xpos, uint8_t ypos ) {
    sp->pixels   = frame;
    sp->type_ptr = JSP_TYPE_LOAD1;
    jsp_move_sprite( sp, xpos, ypos );
}

// Generic frame-based move: uses whatever type_ptr is already set in the sprite.
void jsp_move_sprite_frame( struct jsp_sprite_s *sp, uint8_t *frame,
                            uint8_t xpos, uint8_t ypos ) {
    sp->pixels = frame;
    jsp_move_sprite( sp, xpos, ypos );
}

///////////////////////////////////////////////////////////
// Clip rectangle
///////////////////////////////////////////////////////////

void jsp_sprite_set_clip( struct jsp_sprite_s *sp, struct jsp_rect *clip ) {
    sp->clip = clip;
}

// Returns 1 if the sprite's bounding box at (xpos, ypos) is fully within
// rect (cell coordinates); 0 if partially or fully outside.
uint8_t jsp_sprite_in_rect( struct jsp_sprite_s *sp,
                            struct jsp_rect *rect,
                            uint8_t xpos, uint8_t ypos ) {
    uint8_t sc = xpos / 8;
    uint8_t sr = ypos / 8;
    if ( sc < rect->col )                            return 0;
    if ( sr < rect->row )                            return 0;
    if ( sc + sp->cols > rect->col + rect->width )   return 0;
    if ( sr + sp->rows > rect->row + rect->height )  return 0;
    return 1;
}
