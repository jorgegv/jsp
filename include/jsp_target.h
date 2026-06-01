#ifndef _JSP_TARGET_H
#define _JSP_TARGET_H

///////////////////////////////////////////////////////
//
// JSP TARGET SELECTION (compile-time)
//
// JSP keeps one platform-agnostic high-level engine and a thin platform
// layer that is swapped per machine/mode (see doc/CPC-TARGET-PLAN.md §1.2).
// The target is chosen at build time:
//
//   - ZX Spectrum (default): no target macro is defined.  This header then
//     derives the positive symbol JSP_TARGET_ZX so C code can read
//     `#ifdef JSP_TARGET_ZX`.  A plain ZX build passes NO extra flags, so its
//     output is byte-for-byte unchanged from before the seam was introduced.
//
//   - Amstrad CPC: the build defines JSP_TARGET_CPC plus exactly one CPC mode
//     macro (CPC_MODE0 / CPC_MODE1 / CPC_MODE2 / CPC_MODE1_MONO /
//     CPC_MODE0_FAST / CPC_MODE1_FAST).
//
// IMPORTANT — passing the target to assembly.  `zcc -DNAME` reaches only the
// C preprocessor, NOT the z80 assembler.  To define the same symbol for asm,
// forward it with zcc's assembler-option passthrough:
//
//     zcc ... -DJSP_TARGET_CPC -Ca-DJSP_TARGET_CPC ...
//
// ZX-only assembly is therefore guarded with `IFNDEF JSP_TARGET_CPC` (absence
// of the macro = the ZX target); CPC-only assembly with `IFDEF JSP_TARGET_CPC`.
// (z88dk asm uses IFDEF/IFNDEF, not `#ifdef`.)
//
///////////////////////////////////////////////////////

#if !defined( JSP_TARGET_CPC )
    #define JSP_TARGET_ZX
#endif

#endif // _JSP_TARGET_H
