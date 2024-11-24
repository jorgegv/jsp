#include <stdint.h>
#include <string.h>

// #define SPECTRUM_128 to use the 128K mode memory layout.  If not
// #defined, 48K layout will be used by default

/////////////////////////////////////////////////////////////////////
// JSP data structures at fixed addresses, according to memory map
/////////////////////////////////////////////////////////////////////

#ifdef SPECTRUM_128
    #define ROTTBL_ADDR		0xB200
    #define BTT_ADDR		0xAF00
    #define DRT_ADDR		0xAC00
    #define DTT_ADDR		0xAB4B
#else
    #define ROTTBL_ADDR		0xF200
    #define BTT_ADDR		0xEF00
    #define DRT_ADDR		0xEC00
    #define DTT_ADDR		0xEB8B
#endif

// rotation tables
__at( ROTTBL_ADDR ) uint16_t jsp_rottbl[ 7 * 256 ];

// Background Tiles Table: array of pointers to uint8_t
__at( BTT_ADDR ) uint8_t *jsp_btt[ 768 ];

// Drawing Records Table: array of pointers to uint8_t
__at( DRT_ADDR ) uint8_t *jsp_drt[ 768 ];

// Dirty Tiles Table: byte array
__at( DTT_ADDR ) uint8_t jsp_dtt[ 768 / 8 ];

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
