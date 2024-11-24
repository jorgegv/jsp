#ifndef _JSP_H
#define _JSP_H

// #define SPECTRUM_128 to use the 128K mode memory layout.  If not
// defined, 48K layout will be used by default

extern uint8_t jsp_rottbl[];
extern uint16_t *jsp_btt[];
extern uint16_t *jsp_drt[];
extern uint8_t jsp_dtt[];

// engine functions
void jsp_init( void );
void jsp_redraw( void );
void jsp_dtt_mark_dirty( uint8_t row, uint8_t col );
void jsp_draw_tile( uint8_t row, uint8_t col, uint8_t *pix );
void jsp_draw_tile_attr( uint8_t row, uint8_t col, uint8_t *pix, uint8_t attr );

#endif // _JSP_H
