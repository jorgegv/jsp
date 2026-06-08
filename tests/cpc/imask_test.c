// JSP-CPC _IMASK — implicit-mask LUT UNIT TEST (host-side).
//
// The _IMASK sprite modes (CPC_MODE0_IMASK / CPC_MODE1_IMASK) drop the explicit
// per-pixel mask: pen 0 is transparent and only graph bytes are stored.  The
// mask is derived at composite time from the graph byte via a 256-entry table
// (jsp_imask_tbl, built by jsp_init_imask_tbl() in lib/jsp_init.c from the
// JSP_IMASK() macro in include/jsp_rottbl_formula.h).
//
// This is the build-time gate for that macro: it builds the table from JSP_IMASK
// and checks every entry against an INDEPENDENT per-pixel reference (decode the
// byte's pixels -> mark pen-0 pixels transparent -> set all plane bits of the
// transparent pixels).  Pure host C (cc), no emulator.
//
// CPC_MODE0_IMASK or CPC_MODE1_IMASK is defined on the command line (Makefile).
//
// Build/run:  cc -DCPC_MODE1_IMASK -Iinclude -o imask_test tests/cpc/imask_test.c
//             ./imask_test

#include <stdio.h>
#include <stdint.h>

#include "jsp_rottbl_formula.h"

#if !defined( CPC_MODE0_IMASK ) && !defined( CPC_MODE1_IMASK )
#error "imask_test: define CPC_MODE0_IMASK or CPC_MODE1_IMASK"
#endif

// ---- Independent reference: graph byte -> mask byte -------------------------
// A pixel is transparent iff pen == 0 (all its plane bits are 0); the mask sets
// ALL plane bits of every transparent pixel and clears the rest.

#if defined( CPC_MODE1_IMASK )
// Mode 1: 4 px/byte; pixel p plane-0 bit at (7-p), plane-1 bit at (3-p).
static uint8_t ref_imask(uint8_t g) {
    uint8_t mask = 0;
    for (int p = 0; p < 4; p++) {
        int plane0 = (g >> (7 - p)) & 1;
        int plane1 = (g >> (3 - p)) & 1;
        if ((plane0 | plane1) == 0) {          // pen 0 -> transparent
            mask |= (uint8_t)(1 << (7 - p));   // set both plane bits
            mask |= (uint8_t)(1 << (3 - p));
        }
    }
    return mask;
}
#else
// Mode 0: 2 px/byte; pixel 0 (left) = bits {7,5,3,1} (0xAA), pixel 1 = {6,4,2,0}
// (0x55).  A pixel is transparent iff all 4 of its plane bits are 0.
static uint8_t ref_imask(uint8_t g) {
    uint8_t mask = 0;
    if ((g & 0xAA) == 0) mask |= 0xAA;         // pixel 0 transparent
    if ((g & 0x55) == 0) mask |= 0x55;         // pixel 1 transparent
    return mask;
}
#endif

int main(void) {
#if defined( CPC_MODE1_IMASK )
    printf("JSP-CPC Mode 1 _IMASK LUT unit test\n");
#else
    printf("JSP-CPC Mode 0 _IMASK LUT unit test\n");
#endif

    int fails = 0;
    for (int g = 0; g <= 255; g++) {
        uint8_t got = JSP_IMASK((uint8_t)g);
        uint8_t exp = ref_imask((uint8_t)g);
        if (got != exp) {
            if (fails < 20)
                printf("  FAIL: imask[%02X] = %02X, expected %02X\n", g, got, exp);
            fails++;
        }
    }
    printf("[1] JSP_IMASK vs per-pixel reference: 256 entries\n");

    if (fails == 0) { printf("RESULT: PASS\n"); return 0; }
    printf("RESULT: FAIL (%d mismatches)\n", fails);
    return 1;
}
