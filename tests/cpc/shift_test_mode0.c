// JSP-CPC Phase 7 — Mode 0 shift/mask UNIT TEST (host-side, plan §4/§8/§10).
//
// Mode 0 is 2 px/byte with the 4 bit-planes interleaved: pixel 0 (left) occupies
// the odd bit positions {7,5,3,1}, pixel 1 (right) the even positions {6,4,2,0}.
// There is a single 1-pixel shift phase (xrot 1; xrot 0 = aligned).  The
// rotation table (jsp_rottbl, built by jsp_init_rottbl() from the shared
// include/jsp_rottbl_formula.h) holds an in-byte and a carry half per source
// byte, and the compositor combines THIS column's in-byte with the LEFT
// column's carry:
//
//     out_byte = rottbl_in[ this ] | rottbl_carry[ left ]
//
// We verify, with an INDEPENDENT pixel-array reference, that this equals a true
// 1-px shift of the (left|this) 2-pixel window, exhaustively over all byte pairs.
//
// Build/run:  make cpc-shift-test-mode0
// (usage:  shift_test_mode0 [path/to/mode0_mask2_asset.asm])

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "jsp_rottbl_formula.h"          // CPC_MODE0 selects the Mode-0 split

#define PHASES 1                          // Mode 0: single shift phase (xrot 1)

static uint8_t rottbl_in[PHASES][256];
static uint8_t rottbl_carry[PHASES][256];
static void build_rottbl(void) {
    for (int i = 1; i <= PHASES; i++)
        for (int v = 0; v <= 255; v++) {
            rottbl_in[i-1][v]    = (uint8_t)JSP_ROTTBL_IN(v, i);
            rottbl_carry[i-1][v] = (uint8_t)JSP_ROTTBL_CARRY(v, i);
        }
}

// ---- independent Mode-0 pixel codec ----------------------------------------
// pixel 0 bits {7,5,3,1}, pixel 1 bits {6,4,2,0}; gather into a 4-bit value
// (the plane order is arbitrary but consistent — the shift only moves whole
// pixels, so any fixed packing validates it).
static int m0_get(uint8_t b, int p) {
    int s = (p == 0) ? 1 : 0;             // base shift: odd bits for px0, even for px1
    return (((b >> (s + 6)) & 1) << 3) | (((b >> (s + 4)) & 1) << 2) |
           (((b >> (s + 2)) & 1) << 1) | (((b >> (s + 0)) & 1));
}
static uint8_t m0_set(uint8_t b, int p, int v) {
    int s = (p == 0) ? 1 : 0;
    if (v & 8) b |= (uint8_t)(1 << (s + 6));
    if (v & 4) b |= (uint8_t)(1 << (s + 4));
    if (v & 2) b |= (uint8_t)(1 << (s + 2));
    if (v & 1) b |= (uint8_t)(1 << (s + 0));
    return b;
}

// in/carry of a byte shifted right 1 px in isolation (next byte = 0):
//   window [px0,px1 | 0,0] >> 1 -> in = px at {0,1}, carry = px at {2,3}
static void ref_in_carry(uint8_t v, uint8_t *in, uint8_t *carry) {
    int W[4] = { m0_get(v,0), m0_get(v,1), 0, 0 };
    int S[4]; for (int k = 0; k < 4; k++) S[k] = (k >= 1) ? W[k-1] : 0;
    uint8_t bi = 0, bc = 0;
    bi = m0_set(bi, 0, S[0]); bi = m0_set(bi, 1, S[1]);
    bc = m0_set(bc, 0, S[2]); bc = m0_set(bc, 1, S[3]);
    *in = bi; *carry = bc;
}

// screen byte at THIS position when [left|this] window shifts right 1 px:
//   window [left.p0,left.p1,this.p0,this.p1] >> 1; this byte = positions {2,3}
static uint8_t ref_combine(uint8_t left, uint8_t cur) {
    int W[4] = { m0_get(left,0), m0_get(left,1), m0_get(cur,0), m0_get(cur,1) };
    uint8_t out = 0;
    out = m0_set(out, 0, W[1]);           // S[2] = W[2-1] = W[1]
    out = m0_set(out, 1, W[2]);           // S[3] = W[3-1] = W[2]
    return out;
}

static int fail_count = 0;
#define CHECK(cond, ...) do { if (!(cond)) { \
    if (fail_count < 20) { printf("  FAIL: "); printf(__VA_ARGS__); printf("\n"); } \
    fail_count++; } } while (0)

static void test_table_vs_reference(void) {
    int checks = 0;
    for (int v = 0; v <= 255; v++) {
        uint8_t exp_in, exp_carry;
        ref_in_carry((uint8_t)v, &exp_in, &exp_carry);
        CHECK(rottbl_in[0][v] == exp_in,    "in[%02X]=%02X exp %02X", v, rottbl_in[0][v], exp_in);
        CHECK(rottbl_carry[0][v] == exp_carry, "carry[%02X]=%02X exp %02X", v, rottbl_carry[0][v], exp_carry);
        checks += 2;
    }
    printf("[1] table vs per-pixel reference (256 bytes): %d checks\n", checks);
}

static void test_combine_exhaustive(void) {
    int checks = 0;
    for (int left = 0; left <= 255; left++)
        for (int cur = 0; cur <= 255; cur++) {
            uint8_t engine = (uint8_t)(rottbl_in[0][cur] | rottbl_carry[0][left]);
            uint8_t ref    = ref_combine((uint8_t)left, (uint8_t)cur);
            CHECK(engine == ref, "combine left=%02X cur=%02X -> %02X ref %02X", left, cur, engine, ref);
            checks++;
        }
    printf("[2] exhaustive combine vs 1-px window shift (256x256): %d checks\n", checks);
}

static void test_emitted_bytes(const uint8_t *b, int n) {
    int checks = 0;
    for (int k = 0; k < n; k++) {
        uint8_t left = (k == 0) ? 0 : b[k-1];
        uint8_t engine = (uint8_t)(rottbl_in[0][b[k]] | rottbl_carry[0][left]);
        uint8_t ref    = ref_combine(left, b[k]);
        CHECK(engine == ref, "emitted k=%d left=%02X cur=%02X", k, left, b[k]);
        checks++;
    }
    printf("[3] emitted asset bytes (%d bytes): %d checks\n", n, checks);
}

static int load_asm_bytes(const char *path, uint8_t *out, int max) {
    FILE *f = fopen(path, "r"); if (!f) return -1;
    char line[512]; int n = 0;
    while (fgets(line, sizeof line, f)) {
        char *semi = strchr(line, ';'); if (semi) *semi = 0;
        char *p = line; while (isspace((unsigned char)*p)) p++;
        if (strncmp(p, "db", 2) != 0) continue;
        for (char *q = p + 2; *q; q++)
            if (*q == '$') { unsigned v; if (sscanf(q+1, "%x", &v) == 1 && n < max) out[n++] = (uint8_t)v; }
    }
    fclose(f); return n;
}

int main(int argc, char **argv) {
    printf("JSP-CPC Mode 0 shift/mask unit test\n");
    build_rottbl();
    test_table_vs_reference();
    test_combine_exhaustive();
    if (argc > 1) {
        static uint8_t bytes[8192];
        int n = load_asm_bytes(argv[1], bytes, sizeof bytes);
        if (n < 2) { printf("[3] FAIL — read %d bytes from %s\n", n, argv[1]); printf("RESULT: FAIL\n"); return 1; }
        test_emitted_bytes(bytes, n);
    } else printf("[3] emitted asset bytes: skipped (no asset path given)\n");

    if (fail_count == 0) { printf("RESULT: PASS\n"); return 0; }
    printf("RESULT: FAIL (%d mismatches)\n", fail_count);
    return 1;
}
