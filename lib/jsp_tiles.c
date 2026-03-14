#include <stdint.h>

#include "jsp.h"

extern uint8_t jsp_bat[];

///////////////////////////////////////////////////////////
// P1-8: Tile table (256-entry pointer table)
///////////////////////////////////////////////////////////

// 256-entry tile table; entries 32-127 pre-filled with ROM font by jsp_init.
uint8_t *jsp_tile_table[256];

// Initialise tile table: entries 32-127 point to ZX Spectrum ROM font.
void jsp_init_tile_table( void ) {
    uint8_t ch;
    for ( ch = 32; ch < 128; ch++ )
        jsp_tile_table[ch] = (uint8_t *)( 0x3D00 + (uint16_t)(ch - 32) * 8 );
}

// Register 8-byte tile graphic at 1-byte index (equivalent to sp1_TileEntry).
void jsp_tile_register( uint8_t idx, uint8_t *gfx_ptr ) {
    jsp_tile_table[idx] = gfx_ptr;
}

// Draw tile at (row, col) with colour attribute.
//   tile < 256  : look up via jsp_tile_table
//   tile >= 256 : treat as direct 8-byte graphic pointer
// Writes attr to ZX Spectrum attribute memory and BAT.
void jsp_tile_put( uint8_t row, uint8_t col, uint8_t attr, uint16_t tile ) {
    uint8_t  *pix;
    uint16_t  idx = (uint16_t)row * 32 + col;

    if ( tile < 256 )
        pix = jsp_tile_table[(uint8_t)tile];
    else
        pix = (uint8_t *)tile;

    // Draw pixel data via BTT/DRT (marks cell dirty for next jsp_redraw)
    jsp_draw_background_tile( row, col, pix );

    // Set colour attribute directly and store in BAT
    *( (volatile uint8_t *)( 0x5800 + idx ) ) = attr;
    jsp_bat[idx] = attr;
}

///////////////////////////////////////////////////////////
// P1-9: Rectangle clear
///////////////////////////////////////////////////////////

void jsp_clear_rect( struct jsp_rect *rect, uint8_t attr,
                     uint8_t ch, uint8_t flags ) {
    uint8_t r, c;
    uint8_t *tile_ptr = 0;
    static const uint8_t blank[8] = { 0,0,0,0,0,0,0,0 };

    if ( flags & JSP_RFLAG_TILE ) {
        if ( ch == 0 || ch == ' ' )
            tile_ptr = (uint8_t *)blank;
        else
            tile_ptr = (uint8_t *)( 0x3D00 + (uint16_t)(ch - 32) * 8 );
    }

    for ( r = rect->row; r < rect->row + rect->height; r++ ) {
        for ( c = rect->col; c < rect->col + rect->width; c++ ) {
            uint16_t idx = (uint16_t)r * 32 + c;
            if ( flags & JSP_RFLAG_TILE )
                jsp_draw_background_tile( r, c, tile_ptr );
            if ( flags & JSP_RFLAG_COLOUR ) {
                *( (volatile uint8_t *)( 0x5800 + idx ) ) = attr;
                jsp_bat[idx] = attr;
            }
        }
    }
}

///////////////////////////////////////////////////////////
// P1-10: Rectangle invalidation
///////////////////////////////////////////////////////////

void jsp_invalidate_rect( struct jsp_rect *rect ) {
    uint8_t r, c;
    for ( r = rect->row; r < rect->row + rect->height; r++ )
        for ( c = rect->col; c < rect->col + rect->width; c++ )
            jsp_dtt_mark_dirty( r, c );
}
