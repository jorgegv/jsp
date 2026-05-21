#include <stdint.h>

/////////////////////////////////////////////////////////////////////
// JSP data structures at fixed addresses, according to memory map
//
// The recompositing redesign removed the DRT (Drawing Records Table):
// there is no longer a "current composite" pointer per cell — the screen
// is recomputed from BTT + live sprite state on every jsp_redraw().
// The 1.5 KB region formerly used by DRT is now free.
/////////////////////////////////////////////////////////////////////

#ifdef SPECTRUM_128
    #define ROTTBL_ADDR		0xB200
    #define BTT_ADDR		0xAC00
    // 0xA600-0xABFF (1.5 KB) free — was DRT
    #define DTT_ADDR		0xA5A0
    #define FTT_ADDR		0xA540
    #define BAT_ADDR		0xA240
#else
    #define ROTTBL_ADDR		0xF200
    #define BTT_ADDR		0xEC00
    // 0xE600-0xEBFF (1.5 KB) free — was DRT
    #define DTT_ADDR		0xE5A0
    #define FTT_ADDR		0xE540
    #define BAT_ADDR		0xE240
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
