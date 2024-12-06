#include <stdint.h>

/////////////////////////////////////////////////////////////////////
// JSP data structures at fixed addresses, according to memory map
/////////////////////////////////////////////////////////////////////

#ifdef SPECTRUM_128
    #define ROTTBL_ADDR		0xB200
    #define BTT_ADDR		0xAC00
    #define DRT_ADDR		0xA600
    #define DTT_ADDR		0xA545
#else
    #define ROTTBL_ADDR		0xF200
    #define BTT_ADDR		0xEC00
    #define DRT_ADDR		0xE600
    #define DTT_ADDR		0xE585
#endif

// rotation tables
__at( ROTTBL_ADDR ) uint8_t jsp_rottbl[ 7 * 2 * 256 ];

// Background Tiles Table: array of pointers to uint8_t
__at( BTT_ADDR ) uint8_t *jsp_btt[ 768 ];

// Drawing Records Table: array of pointers to uint8_t
__at( DRT_ADDR ) uint8_t *jsp_drt[ 768 ];

// Dirty Tiles Table: byte array
__at( DTT_ADDR ) uint8_t jsp_dtt[ 768 / 8 ];

