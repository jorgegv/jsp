#include <stdint.h>
#include <spectrum.h>

void jsp_draw_tile( uint8_t row, uint8_t col, uint8_t *pix ) {
    uint8_t *dst = zx_cxy2saddr( col, row );
    uint8_t i = 8;
    while ( i-- ) {
        *dst = *pix++;
        dst = zx_saddrpdown( dst );
    }
}

void jsp_draw_tile_attr( uint8_t row, uint8_t col, uint8_t *pix, uint8_t attr ) {
    jsp_draw_tile( row, col, pix );
    *zx_cxy2aaddr( col, row ) = attr;
}
