#include <stdint.h>

/////////////////////////////////////////////////////////////////////
// JSP data structures at fixed addresses, according to memory map
//
// JSP recomputes the screen from the BTT plus live sprite state on every
// jsp_redraw(); there is no per-cell "current composite" state to store.
//
// The five JSP tables are packed into one contiguous block (ROTTBL + BTT
// + DTT + FTT + BAT, 6080 bytes); the program area and free RAM sit
// contiguously below that block.  ROTTBL stays 256-aligned
// (jsp_current_rottbl_msb is derived from its high byte).
//
// The block's location is a compile-time choice; the names refer to the
// Z80's 16K memory slots.  Both layouts are valid in 48K and 128K mode
// without restriction — the flag only governs where the JSP data lives:
//
//   JSPDATA_SLOT3 (default) : block 0xE840-0xFFFF (slot 3, the top 16K)
//   JSPDATA_SLOT2           : block 0xA840-0xBFFF (slot 2), which keeps
//                             slot 3 (0xC000-0xFFFF) free of JSP data
//                             (useful for 128K bank switching)
/////////////////////////////////////////////////////////////////////

// SEAM (ZX-specific, doc/CPC-TARGET-PLAN.md §9): these __at addresses and table
// sizes are the ZX memory map (768 cells, block at the top of RAM).  The CPC
// target needs a different placement (tables sized for 2000 cells, block below
// the 0xC000 screen) under JSP_TARGET_CPC — added in Phase 2.  Until then a CPC
// build deliberately falls through to the ZX layout, which is wrong for CPC;
// Phase 2 introduces the JSP_TARGET_CPC branch here.
#ifdef JSPDATA_SLOT2
    #define ROTTBL_ADDR		0xB200
    #define BTT_ADDR		0xAC00
    #define DTT_ADDR		0xABA0
    #define FTT_ADDR		0xAB40
    #define BAT_ADDR		0xA840
#else	// JSPDATA_SLOT3 (default)
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
