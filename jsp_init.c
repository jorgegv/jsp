#include <stdint.h>
#include <string.h>

#include "jsp.h"

/////////////////////////////////////////////////////////////////////
// Initialization functions
/////////////////////////////////////////////////////////////////////

// initialize all btt pointers to NULL
void jsp_init_btt( void ) {
    memset( jsp_btt, 0, 768 * 2 );
}

// initialize all drt pointers to NULL
void jsp_init_drt( void ) {
    memset( jsp_drt, 0, 768 * 2 );
}

// set all cells to clean
void jsp_init_dtt( void ) {
    memset( jsp_dtt, 0, 768 / 8 );
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

///////////////////////////////////
// DTT functions
///////////////////////////////////

void jsp_dtt_mark_dirty( uint8_t row, uint8_t col ) {
    jsp_dtt[ ( ( row * 32 ) + col ) / 8 ] |= ( 1 << ( col % 8 ) );
}
