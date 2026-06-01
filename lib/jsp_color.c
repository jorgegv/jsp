#include <stdint.h>

#include "jsp.h"

// Set the colour applied to all sprite cells each frame.
void jsp_sprite_set_color( struct jsp_sprite_s *sp, uint8_t color, uint8_t color_mask ) {
    sp->color = color;
    sp->color_mask = color_mask;
}

// Write color to attribute memory for all cells at the sprite's current position.
// Called after each move/draw; also exposed for manual use.
//
// ZX-only platform layer (seam, doc/CPC-TARGET-PLAN.md §6): this writes the ZX
// attribute RAM at 0x5800.  The CPC has no attribute RAM (colour lives in the
// pixel bits), so on CPC this is a no-op — colour is baked into the sprite/tile
// pixel data instead.  The symbol stays defined so callers need no guard.
void jsp_apply_sprite_color( struct jsp_sprite_s *sp ) {
#ifdef JSP_TARGET_ZX
    uint8_t r, c;
    uint8_t r0, c0;
    volatile uint8_t *attr;

    if ( !sp->color )
        return;

    r0 = sp->ypos / 8;
    c0 = sp->xpos / 8;
    /* A pixel-shifted sprite overflows into the next cell on each edge;
     * use inclusive end computed from pixel extents to cover all painted cells. */
    for ( r = r0; r <= (uint8_t)( (sp->ypos + (uint8_t)(sp->rows * 8) - 1) / 8 ); r++ ) {
        for ( c = c0; c <= (uint8_t)( (sp->xpos + (uint8_t)(sp->cols * 8) - 1) / 8 ); c++ ) {
            if ( jsp_ftt_is_fg( r, c ) ) continue;
            attr = (volatile uint8_t *)( 0x5800 + (uint16_t)r * 32 + c );
            *attr = ( *attr & sp->color_mask ) | ( sp->color & ~sp->color_mask );
        }
    }
#else
    (void) sp;   // CPC: no attribute RAM — colour is in the pixels
#endif
}
