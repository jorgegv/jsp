#include <stdint.h>
#include <string.h>

#include "jsp.h"

/////////////////////////////////////////////////////////////////////
// Initialization functions
/////////////////////////////////////////////////////////////////////

void jsp_memzero( void *dst, uint16_t numbytes ) __smallc __z88dk_callee;

// initialize all btt pointers to NULL
void jsp_init_btt( void ) {
    jsp_memzero( jsp_btt, 768 * 2 );
}

// initialize all drt pointers to NULL
void jsp_init_drt( void ) {
    jsp_memzero( jsp_drt, 768 * 2 );
}

// set all cells to clean
void jsp_init_dtt( void ) {
    jsp_memzero( jsp_dtt, 768 / 8 );
}

// initialize rotation tables
void jsp_init_rottbl( void ) {
    uint8_t i;
    uint16_t val;
    for ( i = 1; i <= 7; i++ ) {
        for ( val = 0; val <= 255; val++ )
            jsp_rottbl[ 256 * ( i - 1 ) + val ] = ( 256 * val ) >> i;
    }
}

// run all jsp initializations
void jsp_init( void ) {
    jsp_init_rottbl();
    jsp_init_btt();
    jsp_init_drt();
    jsp_init_dtt();
}

