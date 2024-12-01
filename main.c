#include <stdio.h>
#include <stdint.h>
#include <spectrum.h>

#include "jsp.h"

void main( void ) {
    uint8_t i;

    jsp_init();

    zx_cls();

    for ( i = 0; i < 24; i++ ) {
        jsp_dtt_mark_dirty( i, i );
        jsp_dtt_mark_dirty( i, 31 );
    }

    uint8_t *ptr = (uint8_t *)0xEB8B;	// DTT in 48K mode
    for ( i=0; i < 96; i++ ) {
        printf( "%02X ", *ptr++ );
        if ( i % 16 == 15 ) putchar('\n');
    }
}
