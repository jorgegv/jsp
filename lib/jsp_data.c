#include <stdint.h>

#include "jsp_config.h"

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

// Table base addresses, per target (doc/CPC-TARGET-PLAN.md §9).
#ifdef JSP_TARGET_CPC
    // CPC: 2000-cell tables packed just below the 0xC000 screen (full RAM,
    // both ROMs off).  Sizes: ROTTBL 3584 (M2, 256-aligned), BTT 4000, DTT 250,
    // FTT 250, BAT 2000.  Block 0x9800-0xBFFF; program + stack live below.
    //   ROTTBL 0xB200-0xBFFF  BTT 0xA200-0xB19F  DTT 0xA100-0xA1F9
    //   FTT 0xA000-0xA0F9     BAT 0x9800-0x9FCF
    // BAT stays allocated for now (sprite colour is dropped on CPC, §6, but the
    // array keeps the shared code compiling; it can be removed later).
    #define ROTTBL_ADDR		0xB200
    #define BTT_ADDR		0xA200
    #define DTT_ADDR		0xA100
    #define FTT_ADDR		0xA000
    #define BAT_ADDR		0x9800
#elif defined( JSPDATA_SLOT2 )
    #define ROTTBL_ADDR		0xB200
    #define BTT_ADDR		0xAC00
    #define DTT_ADDR		0xABA0
    #define FTT_ADDR		0xAB40
    #define BAT_ADDR		0xA840
#else	// ZX JSPDATA_SLOT3 (default)
    #define ROTTBL_ADDR		0xF200
    #define BTT_ADDR		0xEC00
    #define DTT_ADDR		0xEBA0
    #define FTT_ADDR		0xEB40
    #define BAT_ADDR		0xE840
#endif

// rotation tables (one (in-byte,carry) page-pair per shift phase)
__at( ROTTBL_ADDR ) uint8_t jsp_rottbl[ JSP_SHIFT_PHASES * 2 * 256 ];

// Implicit-mask LUT (CPC _IMASK modes): graph byte -> derived mask byte (see
// jsp_init_imask_tbl / JSP_IMASK).  Placed 256-aligned in the tail of the
// reserved rottbl block (M2 sizes it to 3584 B): rottbl uses SHIFT_PHASES*512
// from ROTTBL_ADDR, so the table sits just above it, still below the 0xC000
// screen (M1: 0xB800, M0: 0xB400).
#if defined( CPC_MODE0_IMASK ) || defined( CPC_MODE1_IMASK )
  #define IMASK_TBL_ADDR ( ROTTBL_ADDR + JSP_SHIFT_PHASES * 2 * 256 )
__at( IMASK_TBL_ADDR ) uint8_t jsp_imask_tbl[ 256 ];
#endif

// Background Tiles Table: array of pointers to tile graphics
__at( BTT_ADDR ) uint8_t *jsp_btt[ JSP_GRID_CELLS ];

// Dirty Tiles Table: byte array
__at( DTT_ADDR ) uint8_t jsp_dtt[ JSP_DTT_BYTES ];

// Foreground Tiles Table: byte array
__at( FTT_ADDR ) uint8_t jsp_ftt[ JSP_FTT_BYTES ];

// Background Attribute Table: one attribute byte per screen cell
__at( BAT_ADDR ) uint8_t jsp_bat[ JSP_GRID_CELLS ];

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
