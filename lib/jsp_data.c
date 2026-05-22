#include <stdint.h>

/////////////////////////////////////////////////////////////////////
// JSP data structures at fixed addresses, according to memory map
//
// The recompositing redesign removed the DRT (Drawing Records Table):
// there is no longer a "current composite" pointer per cell — the screen
// is recomputed from BTT + live sprite state on every jsp_redraw().
//
// The five JSP tables are packed into one contiguous block at the top of
// RAM (ROTTBL + BTT + DTT + FTT + BAT, 6080 bytes); the space formerly
// taken by the DRT is now plain free RAM contiguous with the program
// area, below that block.  ROTTBL stays 256-aligned (jsp_current_rottbl_msb
// is derived from its high byte).
//
//   48K : block 0xE840-0xFFFF, free RAM below 0xE840
//   128K: block 0xA840-0xBFFF, free RAM below 0xA840 (C000-FFFF stays
//         clear for banking)
/////////////////////////////////////////////////////////////////////

#ifdef SPECTRUM_128
    #define ROTTBL_ADDR		0xB200
    #define BTT_ADDR		0xAC00
    #define DTT_ADDR		0xABA0
    #define FTT_ADDR		0xAB40
    #define BAT_ADDR		0xA840
#else
    #define ROTTBL_ADDR		0xF200
    #define BTT_ADDR		0xEC00
    #define DTT_ADDR		0xEBA0
    #define FTT_ADDR		0xEB40
    #define BAT_ADDR		0xE840
#endif

// rotation tables
__at( ROTTBL_ADDR ) uint8_t jsp_rottbl[ 7 * 2 * 256 ];

// Background Tiles Table: array of pointers to tile graphics
__at( BTT_ADDR ) uint8_t *jsp_btt[ 768 ];

// Dirty Tiles Table: byte array
__at( DTT_ADDR ) uint8_t jsp_dtt[ 768 / 8 ];

// Foreground Tiles Table: byte array
__at( FTT_ADDR ) uint8_t jsp_ftt[ 768 / 8 ];

// Background Attribute Table: one attribute byte per screen cell
__at( BAT_ADDR ) uint8_t jsp_bat[ 768 ];

// rottbl parameter does not change while drawing a full sprite, so better
// to set it up in a global once at the beginning instead of passing it
// around as a parameter
uint8_t jsp_current_rottbl_msb;

// Sprite type tags.  In the recompositing model the compositing code is C
// and selects the draw primitives directly, so a type is just a distinct
// identity whose single byte holds the cell graphic size:
//   MASK2 = (mask,graph) pairs, 16 bytes/cell
//   LOAD1 = graphics only,       8 bytes/cell
uint8_t JSP_TYPE_MASK2[ 1 ] = { 16 };
uint8_t JSP_TYPE_LOAD1[ 1 ] = { 8 };
