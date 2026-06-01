// JSP-CPC Phase 6.1 — Mode 1 MONO expansion + shift UNIT TEST (host-side).
//
// MONO renders plain 1bpp (Mode-2/SP1 format) assets on a Mode-1 screen: the
// 1bpp->Mode-1 conversion happens in the blitter, nothing is stored expanded
// (doc/CPC-ASSETS-FORMAT.md §3.1).  A 1bpp source byte is 8 px = TWO Mode-1
// screen cells (4 px each); screen cell j maps to source byte j>>1, nibble j&1
// (0 = source px 7..4, 1 = source px 3..0).  The blitter expands the selected
// nibble's 4 source pixels into a Mode-1 byte (pen 0 = clear, pen 1 = set):
//
//     graph_hi = g & 0xF0          graph_lo = (g & 0x0F) << 4
//     mask_hi  = (m&0xF0)|((m&0xF0)>>4)   mask_lo = ((m&0x0F)<<4)|(m&0x0F)
//
// then shifts it with the Mode-1 nibble rotation table (jsp_rottbl, 3 phases)
// and composites — i.e. the same table + middle kernels full Mode 1 uses.
//
// This test proves the NEW piece — the expansion — is a faithful 1:1
// monochrome->Mode-1-pen0/1 mapping; the shift itself is already proved
// exhaustively by shift_test_mode1 (the Mode-1 table is reused unchanged).
//
// Build/run:  make cpc-shift-test-mode1-mono
// (usage:  shift_test_mode1_mono [path/to/1bpp_mask2_asset.asm])

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

// CPC_MODE1_MONO selects the Mode-1 IN/CARRY split (same as CPC_MODE1).
#include "jsp_rottbl_formula.h"

#define PHASES 3

static uint8_t rottbl_in[PHASES][256];
static uint8_t rottbl_carry[PHASES][256];
static void build_rottbl(void) {
    for (int i = 1; i <= PHASES; i++)
        for (int v = 0; v <= 255; v++) {
            rottbl_in[i-1][v]    = (uint8_t)JSP_ROTTBL_IN(v, i);
            rottbl_carry[i-1][v] = (uint8_t)JSP_ROTTBL_CARRY(v, i);
        }
}

// ---- the blitter's per-nibble expansion (1bpp -> Mode-1 pen0/1) ------------
static uint8_t expand_graph(uint8_t g, int parity) {
    return parity == 0 ? (uint8_t)(g & 0xF0) : (uint8_t)((g & 0x0F) << 4);
}
static uint8_t expand_mask(uint8_t m, int parity) {
    if (parity == 0) { uint8_t h = m & 0xF0; return (uint8_t)(h | (h >> 4)); }
    else             { uint8_t l = m & 0x0F; return (uint8_t)((l << 4) | l); }
}

// ---- independent Mode-1 pixel decode (pixel p plane0@7-p, plane1@3-p) ------
static int m1_get(uint8_t b, int p) {
    return (((b >> (7 - p)) & 1)) | ((((b >> (3 - p)) & 1)) << 1);
}

static int fail_count = 0;
#define CHECK(cond, ...) do { if (!(cond)) { \
    if (fail_count < 20) { printf("  FAIL: "); printf(__VA_ARGS__); printf("\n"); } \
    fail_count++; } } while (0)

// [1] expansion is a faithful 1:1 monochrome -> Mode-1 pen mapping.
//     graph: source bit -> pen (1 if set, 0 if clear).
//     mask : source bit -> 3 (both planes, "keep bg") if set, else 0 ("opaque").
static void test_expansion(void) {
    int checks = 0;
    for (int v = 0; v <= 255; v++) {
        for (int parity = 0; parity <= 1; parity++) {
            uint8_t eg = expand_graph((uint8_t)v, parity);
            uint8_t em = expand_mask((uint8_t)v, parity);
            for (int k = 0; k < 4; k++) {
                int srcbit = parity == 0 ? ((v >> (7 - k)) & 1)
                                         : ((v >> (3 - k)) & 1);
                CHECK(m1_get(eg, k) == srcbit,
                      "graph v=%02X par=%d px%d pen=%d want %d", v, parity, k, m1_get(eg,k), srcbit);
                CHECK(m1_get(em, k) == (srcbit ? 3 : 0),
                      "mask v=%02X par=%d px%d pen=%d want %d", v, parity, k, m1_get(em,k), srcbit?3:0);
                checks += 2;
            }
        }
    }
    printf("[1] expansion 1bpp->Mode-1 pen0/1 (256x2 bytes): %d checks\n", checks);
}

// [2] full MONO combine == true monochrome shift: lay two adjacent 1bpp source
//     bytes as a 16-px monochrome window, render to Mode-1 screen cells through
//     the blitter (expand each screen cell's nibble + Mode-1 rottbl combine with
//     its left neighbour), and compare to the monochrome pixels shifted right by
//     xrot.  Screen cells j=0..3 cover the two source bytes (px 0..15).
static void test_mono_shift(void) {
    int checks = 0;
    for (int i = 1; i <= PHASES; i++) {           // xrot 1..3
        for (int b0 = 0; b0 <= 255; b0++) {
            for (int b1 = 0; b1 <= 255; b1++) {
                // monochrome source pixels px[0..15], px0 = b0 bit7 (leftmost)
                int px[16];
                for (int k = 0; k < 8; k++) px[k]     = (b0 >> (7 - k)) & 1;
                for (int k = 0; k < 8; k++) px[8 + k] = (b1 >> (7 - k)) & 1;
                uint8_t src[2] = { (uint8_t)b0, (uint8_t)b1 };
                // 4 Mode-1 screen cells, cell j -> src byte j>>1 nibble j&1
                for (int j = 0; j < 4; j++) {
                    uint8_t this_g = expand_graph(src[j >> 1], j & 1);
                    uint8_t left_g = (j == 0) ? 0
                                   : expand_graph(src[(j - 1) >> 1], (j - 1) & 1);
                    uint8_t engine = (uint8_t)(rottbl_in[i-1][this_g] | rottbl_carry[i-1][left_g]);
                    // reference: this cell's 4 screen pixels (4j..4j+3) show the
                    // source pixel (screen_px - xrot); pen 1 if set, else 0.
                    uint8_t ref = 0;
                    for (int k = 0; k < 4; k++) {
                        int sp = 4 * j + k - i;     // source pixel index
                        int on = (sp >= 0 && sp < 16) ? px[sp] : 0;
                        if (on) ref |= (uint8_t)(1 << (7 - k));   // pen1 = plane0 bit
                    }
                    CHECK(engine == ref,
                          "i=%d b0=%02X b1=%02X j=%d -> %02X ref %02X", i, b0, b1, j, engine, ref);
                    checks++;
                }
            }
        }
    }
    printf("[2] MONO combine vs monochrome shift (256x256x%d cells): %d checks\n", PHASES, checks);
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

// [3] sanity: render the real 1bpp asset bytes through the blitter and confirm
//     the monochrome-shift identity holds over the actual emitted values.
static void test_emitted(const uint8_t *b, int n) {
    int checks = 0;
    for (int i = 1; i <= PHASES; i++)
        for (int k = 0; k + 1 < n; k++) {
            int px[16];
            for (int t = 0; t < 8; t++) px[t]     = (b[k]   >> (7 - t)) & 1;
            for (int t = 0; t < 8; t++) px[8 + t] = (b[k+1] >> (7 - t)) & 1;
            uint8_t src[2] = { b[k], b[k+1] };
            for (int j = 0; j < 4; j++) {
                uint8_t tg = expand_graph(src[j >> 1], j & 1);
                uint8_t lg = (j == 0) ? 0 : expand_graph(src[(j-1) >> 1], (j-1) & 1);
                uint8_t engine = (uint8_t)(rottbl_in[i-1][tg] | rottbl_carry[i-1][lg]);
                uint8_t ref = 0;
                for (int t = 0; t < 4; t++) { int sp = 4*j + t - i; if (sp>=0 && sp<16 && px[sp]) ref |= (uint8_t)(1<<(7-t)); }
                CHECK(engine == ref, "emitted i=%d k=%d j=%d", i, k, j);
                checks++;
            }
        }
    printf("[3] emitted 1bpp bytes through MONO blitter (%d bytes): %d checks\n", n, checks);
}

int main(int argc, char **argv) {
    printf("JSP-CPC Mode 1 MONO expansion/shift unit test\n");
    build_rottbl();
    test_expansion();
    test_mono_shift();
    if (argc > 1) {
        static uint8_t bytes[8192];
        int n = load_asm_bytes(argv[1], bytes, sizeof bytes);
        if (n < 2) { printf("[3] FAIL — read %d bytes from %s\n", n, argv[1]); printf("RESULT: FAIL\n"); return 1; }
        test_emitted(bytes, n);
    } else printf("[3] emitted bytes: skipped (no asset path given)\n");

    if (fail_count == 0) { printf("RESULT: PASS\n"); return 0; }
    printf("RESULT: FAIL (%d mismatches)\n", fail_count);
    return 1;
}
