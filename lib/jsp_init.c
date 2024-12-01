#include <stdint.h>
#include <string.h>

#include "jsp.h"

/////////////////////////////////////////////////////////////////////
// Initialization functions
/////////////////////////////////////////////////////////////////////

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
// this could be done fast in asm, but we have the addresses of the rotation
// tables defined in C code and they are different for 48K and 128K modes.
// It's not worth to do all ASM/C integration to get some minimal speed
// increase and save some bytes for something that is used only once at the
// beginning of the program
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

