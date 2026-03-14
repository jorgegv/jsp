#include <stdint.h>

#include "jsp.h"

///////////////////////////////////////////////////////////
// P1-4: Safe off-screen parking
///////////////////////////////////////////////////////////

// Mark the sprite's current cells as dirty (so background is restored on
// next jsp_redraw) and flag it as parked.  The sprite will not be drawn
// until the next jsp_move_sprite_* call.
void jsp_sprite_park( struct jsp_sprite_s *sp ) {
    uint8_t r, c;
    uint8_t r0 = sp->ypos / 8;
    uint8_t c0 = sp->xpos / 8;
    for ( r = r0; r <= r0 + sp->rows; r++ )
        for ( c = c0; c <= c0 + sp->cols; c++ )
            jsp_dtt_mark_dirty( r, c );
    sp->flags.parked = 1;
}

///////////////////////////////////////////////////////////
// P1-3: C-level wrappers — parked-flag + colour handling
//
// These call the low-level asm _jsp_draw_sprite/_jsp_move_sprite
// (via their public C names jsp_draw_sprite/jsp_move_sprite) after
// setting the correct type_ptr and handling the parked flag.
///////////////////////////////////////////////////////////

// Internal helper: move or draw (respecting parked flag), then apply colour.
static void _do_move( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) {
    if ( sp->flags.parked ) {
        sp->flags.parked = 0;
        jsp_draw_sprite( sp, xpos, ypos );
    } else {
        jsp_move_sprite( sp, xpos, ypos );
    }
    if ( sp->color )
        jsp_apply_sprite_color( sp );
}

static void _do_draw( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) {
    sp->flags.parked = 0;
    jsp_draw_sprite( sp, xpos, ypos );
    if ( sp->color )
        jsp_apply_sprite_color( sp );
}

void jsp_move_sprite_mask2( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) {
    sp->type_ptr = JSP_TYPE_MASK2;
    _do_move( sp, xpos, ypos );
}

void jsp_draw_sprite_mask2( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) {
    sp->type_ptr = JSP_TYPE_MASK2;
    _do_draw( sp, xpos, ypos );
}

void jsp_move_sprite_load1( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) {
    sp->type_ptr = JSP_TYPE_LOAD1;
    _do_move( sp, xpos, ypos );
}

void jsp_draw_sprite_load1( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) {
    sp->type_ptr = JSP_TYPE_LOAD1;
    _do_draw( sp, xpos, ypos );
}
