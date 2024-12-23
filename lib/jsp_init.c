#include <stdint.h>
#include <string.h>

#include "jsp_private.h"

///////////////////////////
// Private data
///////////////////////////

// blank tile
uint8_t jsp_blank_tile[ 8 ] = { 0,0,0,0,0,0,0,0 };

// default background tile after initialization
uint8_t *jsp_default_bg_tile;

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
        for ( val = 0; val <= 255; val++ ) {
            jsp_rottbl[ 512 * ( i - 1 ) + val ] = ( ( 256 * val ) >> i ) / 256;
            jsp_rottbl[ 512 * ( i - 1 ) + val +256 ] = ( ( 256 * val ) >> i ) % 256;
        }
    }
}

void jsp_init_background( uint8_t *default_bg_tile ) {
    uint16_t i;
    for ( i = 0; i < 768; i++ )
        jsp_btt[ i ] = jsp_drt[ i ] = default_bg_tile;
    jsp_default_bg_tile = default_bg_tile;
}

// run all jsp initializations
void jsp_init( uint8_t *bgtile ) {
    jsp_init_rottbl();
    jsp_init_btt();
    jsp_init_drt();
    jsp_init_dtt();
    jsp_init_background( bgtile != NULL ? bgtile : jsp_blank_tile );
}
