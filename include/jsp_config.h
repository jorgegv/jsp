#ifndef _JSP_CONFIG_H
#define _JSP_CONFIG_H

#include <stdint.h>

///////////////////////////////////////////////////////
//
// JSP COMPILE-TIME GEOMETRY / MODE CONFIG
//
// Single source of truth for the per-target/per-mode geometry constants the
// engine reads (grid dimensions, cell size, pixels-per-byte, shift phases,
// colour model).  Selected from the JSP_TARGET_* / CPC_MODE* guards
// (see include/jsp_target.h and doc/CPC-TARGET-PLAN.md §8).
//
// ZX is the default (no JSP_TARGET_CPC): the constants below reproduce the
// historical hard-coded ZX values exactly, so a ZX build is byte-for-byte
// unchanged.
//
// NOTE on the CPC grid: the cell/tile-size model (byte-cell vs pixel-cell) is
// DECIDED — pixel-cell (Model B) is the measured-faster default; byte-cell
// (Model A) stays available (doc/CPC-TILE-SIZE-DESIGN.md).  Both are selectable
// here; everything reads these macros, so the grid/cell size follow the chosen
// model with no engine-wide edit.  Mode 2 is identical in both models.
//
///////////////////////////////////////////////////////

#include "jsp_target.h"

// -------------------------------------------------------------------------
// CPC mode selection must be exactly one of the supported modes.
// -------------------------------------------------------------------------
#ifdef JSP_TARGET_CPC
  #if ( defined( CPC_MODE0 ) + defined( CPC_MODE1 ) + defined( CPC_MODE2 ) + \
        defined( CPC_MODE1_MONO ) + defined( CPC_MODE0_FAST ) + \
        defined( CPC_MODE1_FAST ) + defined( CPC_MODE2_FAST ) ) != 1
    #error "JSP CPC build: define exactly ONE CPC mode (CPC_MODE0, CPC_MODE1, CPC_MODE2, CPC_MODE1_MONO, CPC_MODE0_FAST, CPC_MODE1_FAST or CPC_MODE2_FAST)"
  #endif

  // ---- CPC cell model: byte-cell (Model A) vs pixel-cell (Model B) ----
  // Select with -DJSP_CELL_MODEL_BYTE or -DJSP_CELL_MODEL_PIXEL.  The DEFAULT is
  // PIXEL-cell: the measured-faster model for Modes 0/1 (Mode 2 is identical in
  // both).  Full rationale + the performance comparison: doc/CPC-TILE-SIZE-DESIGN.md.
  // (ZX always uses its native 8x8 layout and ignores these defines.)
  #if defined( JSP_CELL_MODEL_BYTE ) && defined( JSP_CELL_MODEL_PIXEL )
    #error "JSP: define at most ONE of JSP_CELL_MODEL_BYTE / JSP_CELL_MODEL_PIXEL"
  #endif
  #if !defined( JSP_CELL_MODEL_BYTE ) && !defined( JSP_CELL_MODEL_PIXEL )
    #define JSP_CELL_MODEL_PIXEL          // default
  #endif
#endif

// -------------------------------------------------------------------------
// ZX target (default) — the historical values, unchanged.
// -------------------------------------------------------------------------
#ifdef JSP_TARGET_ZX

  #define JSP_GRID_COLS    32     // cells per row
  #define JSP_GRID_ROWS    24     // cells per column
  #define JSP_CELL_BYTES   8      // bytes of pixel data per cell (8x8, 1 bpp)
  #define JSP_PPB          8      // screen pixels per byte (1 bpp linear)
  #define JSP_SHIFT_PHASES 7      // sub-cell horizontal shift phases (1..7)
  #define JSP_HAS_ATTR     1      // ZX attribute RAM (BAT) is present

#endif // JSP_TARGET_ZX

// -------------------------------------------------------------------------
// CPC target — per mode.  CPC has no attribute RAM: JSP_HAS_ATTR = 0 (colour
// is in the pixels, §6).  ppb (pixels-per-byte) is defined FIRST because the
// pixel-cell grid below derives from it.
// -------------------------------------------------------------------------
#ifdef JSP_TARGET_CPC

  #define JSP_GRID_ROWS    25
  #define JSP_HAS_ATTR     0

  #if defined( CPC_MODE0 )
    #define JSP_PPB          2
    #define JSP_SHIFT_PHASES 1
  #elif defined( CPC_MODE0_FAST )
    #define JSP_PPB          2
    #define JSP_SHIFT_PHASES 0    // byte-aligned fast path (no shift table)
  #elif defined( CPC_MODE1 ) || defined( CPC_MODE1_MONO )
    #define JSP_PPB          4
    #define JSP_SHIFT_PHASES 3
  #elif defined( CPC_MODE1_FAST )
    #define JSP_PPB          4
    #define JSP_SHIFT_PHASES 0
  #elif defined( CPC_MODE2 )
    #define JSP_PPB          8
    #define JSP_SHIFT_PHASES 7
  #elif defined( CPC_MODE2_FAST )
    #define JSP_PPB          8
    #define JSP_SHIFT_PHASES 0    // 8-px byte-aligned fast path (no shift table)
  #endif

  // Cell model.  Model A (byte-cell, -DJSP_CELL_MODEL_BYTE): 8-line x 1-byte
  // cells, 80x25 grid in EVERY mode (cell pixel-width 2/4/8 px for M0/M1/M2).
  // Model B (pixel-cell, the DEFAULT): 8x8-PIXEL cells, so the grid and cell
  // byte-size derive from ppb: GRID_COLS = 10*ppb (20/40/80) and CELL_BYTES =
  // 64/ppb (32/16/8) for M0/M1/M2.  Mode 2 (ppb=8) yields 80 cols / 8 bytes in
  // BOTH models — identical, as required (M2 is the regression anchor).  The
  // switch is global: when defined it applies to whichever M0/M1 mode is built.
  #ifdef JSP_CELL_MODEL_PIXEL
    #define JSP_GRID_COLS    ( 10 * JSP_PPB )    // 20 / 40 / 80
    #define JSP_CELL_BYTES   ( 64 / JSP_PPB )    // 32 / 16 / 8
  #else
    #define JSP_GRID_COLS    80                  // Model A byte-cell, all modes
    #define JSP_CELL_BYTES   8
  #endif

#endif // JSP_TARGET_CPC

// -------------------------------------------------------------------------
// Derived geometry (target-independent expressions of the above).
// -------------------------------------------------------------------------
#define JSP_GRID_CELLS   ( JSP_GRID_COLS * JSP_GRID_ROWS )   // total cells
// DTT/FTT are ROW-ALIGNED: each cell row takes ceil(COLS/8) bytes. For COLS a
// multiple of 8 (ZX 32, Model A 80, Model-B M1 40 / M2 80) this equals the flat
// packing; for Model-B Mode 0 (COLS=20) it pads rows to 3 bytes so a row start
// stays byte-aligned (keeps the constant-mask-per-row dirty-mark optimisation).
#define JSP_DTT_ROWBYTES ( ( JSP_GRID_COLS + 7 ) / 8 )
#define JSP_DTT_BYTES    ( JSP_GRID_ROWS * JSP_DTT_ROWBYTES )
#define JSP_FTT_BYTES    JSP_DTT_BYTES

// Screen byte-columns spanned by one cell.  Model A: always 1 (cell == byte
// column).  Model B (pixel-cell): JSP_CELL_BYTES/8 = 1/2/4 for M2/M1/M0 — the
// central loop bound for the looped per-byte-column kernel + wide-cell blit.
#define JSP_CELL_COLBYTES ( JSP_CELL_BYTES / 8 )

// Linear cell index of (row,col).  Used by tile/sprite placement.
#define JSP_CELL_INDEX( row, col ) ( (uint16_t)( row ) * JSP_GRID_COLS + ( col ) )

// -------------------------------------------------------------------------
// Sprite coordinate width (descriptor X/Y).  Decision (plan §3): per-target
// field width.  ZX keeps 8-bit (cell-pixel range fits a byte).  CPC needs
// 16-bit X to address a Mode-2 screen (640 px = 80 cells) and to carry real
// pixel X across the byte_col/shift split.  Y stays 8-bit on both (200 lines
// / 25 cell-rows fit a byte).
//
// jsp_coord_t is the (always 8-bit) Y / generic coordinate; jsp_xcoord_t is
// the per-target X.  On ZX both are uint8_t, so the descriptor layout and the
// public draw/move signatures are byte-for-byte unchanged.  On CPC jsp_xcoord_t
// is 16-bit, which shifts the CPC descriptor offsets (xpos +2..+3, ypos +4,
// flags +5, ...) — the CPC asm (lib/cpc/jsp_frame.asm, jsp_sprite_defer.asm)
// and the guarded lib/jsp_sprite_init.asm use those offsets; the 8-bit ZX asm
// in lib/zx is untouched.  (Phase 3, plan §3.)
// -------------------------------------------------------------------------
typedef uint8_t jsp_coord_t;

#ifdef JSP_TARGET_CPC
typedef uint16_t jsp_xcoord_t;
#else
typedef uint8_t  jsp_xcoord_t;
#endif

#endif // _JSP_CONFIG_H
