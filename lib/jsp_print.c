#include <stdint.h>

#include "jsp.h"

///////////////////////////////////////////////////////////
// P1-11: Text printing (Option C: routes through tile table)
//
// Character codes 32-127 are pre-populated in jsp_tile_table by
// jsp_init, so calling jsp_tile_put(row, col, attr, ch) directly
// renders the ROM font character.  Custom font entries can be
// installed via jsp_tile_register(ch, ptr) at any time.
///////////////////////////////////////////////////////////

void jsp_print_set_pos( struct jsp_print_ctx *ctx,
                        uint8_t row, uint8_t col ) {
    ctx->row = row;
    ctx->col = col;
}

void jsp_print_string( struct jsp_print_ctx *ctx, const char *str ) {
    uint8_t ch;
    uint8_t clip_right  = ctx->clip ? ctx->clip->col + ctx->clip->width  : 32;
    uint8_t clip_bottom = ctx->clip ? ctx->clip->row + ctx->clip->height : 24;

    while ( (ch = (uint8_t)*str++) != 0 ) {
        if ( ch < 32 || ch > 127 )
            continue;   // skip non-printable

        // Wrap at right clip boundary
        if ( ctx->col >= clip_right ) {
            ctx->col = ctx->clip ? ctx->clip->col : 0;
            ctx->row++;
        }
        // Stop if past bottom clip boundary
        if ( ctx->row >= clip_bottom )
            return;

        jsp_tile_put( ctx->row, ctx->col, ctx->attr, (uint16_t)ch );
        ctx->col++;
    }
}
