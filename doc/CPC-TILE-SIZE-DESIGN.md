# JSP-CPC — Cell/Tile-Size Model: Design, Implementation & Decision

**Status: DECIDED — pixel-cell (Model B) is the default; byte-cell (Model A)
stays available.** Settled by measurement (2026-06-04). This document is the
single record of the byte-cell vs pixel-cell question: the analysis, the
implementation of both models, the performance comparison, and the decision.
(It supersedes the former `CPC-TILE-SIZE-ANALYSIS.md`, `CPC-TILE-SIZE-PERF.md`
and `CPC-TILE-SIZE-MODELB-PLAN.md`.)

Select the model at build time:

```
make ... JSP_CELL_MODEL=pixel   # default (Model B)
make ... JSP_CELL_MODEL=byte    # Model A
```

which passes `-DJSP_CELL_MODEL_PIXEL` / `-DJSP_CELL_MODEL_BYTE` to C and asm.
`include/jsp_config.h` errors if both are set and defaults to pixel if neither.
ZX always uses its native 8×8 layout and ignores these.

---

## 1. The two models

CPC framebuffer is always **80 bytes/line × 200 lines = 16000 bytes** at
`0xC000`, in every mode; the mode only changes pixels-per-byte
(`ppb` = 2/4/8 for M0/M1/M2).

| | **Model A — "byte-cell"** | **Model B — "pixel-cell"** |
|---|---|---|
| Cell | 8 lines × **1 byte** = 8 bytes (always) | **8×8 pixels** (always) |
| Cell byte size | 8 B (all modes) | M0 = 32 B, M1 = 16 B, M2 = 8 B |
| Cell pixel width | M0 = 2, M1 = 4, M2 = 8 px | 8 px (all modes) |
| Grid | **80×25 = 2000** (all modes) | M0 **20×25=500**, M1 **40×25=1000**, M2 **80×25=2000** |
| `cols` unit | bytes (2-px units in M0) | 8-px tiles (== ZX) |

Two facts frame the whole decision:

1. **Mode 2 is identical in both models** — 8 px = 8 bytes = a 1-byte cell,
   80×25, either way. The choice only affects **Mode 0 and Mode 1**.
2. **Total pixel work is constant** — the screen is always 16000 bytes and each
   dirty pixel is written once. So this is *not* a "cheap walk vs expensive
   blit" trade; the blit pixel-work is equal. What varies is **per-cell
   overhead** (cell addressing, coverage test, clip test, scratch seed) — paid
   per *cell*, not per *pixel*.

Consequence: Model B's Mode 0 has **4× fewer cells** (Mode 1 = 2×) for the same
pixels, so it pays per-cell overhead 4×/2× less — likely *faster* in M0/M1, the
opposite of the naive "coarser cell = pricier blit" intuition.

### Where each model wins

- **Model B (pixel-cell):** tilemap/text/sprite-footprint fidelity (1 cell = 1
  char = 1 tile = 8×8 px in every mode, like ZX); less per-cell overhead and
  less table RAM in M0/M1.
- **Model A (byte-cell):** simplest ZX-like compositor (cell = byte-column =
  sprite-column); clean grid math (80 is a multiple of 8 → flat byte-packed
  DTT); uniform geometry. Mode 0's 20 columns is *not* a multiple of 8, the one
  real wrinkle for Model B (resolved with a row-aligned DTT, §3).

### History

Phase 7 of the CPC port chose Model A *provisionally*, because by the time
Mode 0 was reached Modes 1+2 were already verified in Model A and there was no
CPC profiler to justify reopening verified code ("measure, not argue" could not
be executed). This study built the measurement harness, implemented Model B as
a guarded alternative, measured both, and reversed the default to pixel-cell.

---

## 2. Implementation (Model B as a guarded alternative)

Model B is **additive and compile-time-guarded** — every Model-A and ZX code
path is byte-identical when `JSP_CELL_MODEL_PIXEL` is not set, so the regression
suite was never rebaselined. The engine was already parameterised
(`jsp_config.h` anticipated this), so the grid derives from `ppb`:
`GRID_COLS = 10·ppb` (20/40/80) and `CELL_BYTES = 64/ppb` (32/16/8); M2 yields
80/8 in both models. The screen byte-offset of a cell is `COLBYTES · cell_index`
because `COLS·COLBYTES = 80` always (`COLBYTES = 8/ppb` = 1/2/4).

Key pieces (all guarded):

- **`include/jsp_config.h` / `lib/cpc/jsp_cpc_geom.inc`** — grid/cell/DTT
  geometry from `ppb`; `JSP_CELL_COLBYTES`, `JSP_GEOM_CELLSHIFT = log2(COLBYTES)`,
  row-aligned DTT size.
- **`jsp_rowcolindex.asm`** — cell index `row*COLS+col`; row-aligned DTT byte
  index `row*ROWBYTES + col/8`.
- **`jsp_screen.asm`** — wide-cell blit: the cell scratch/tile is **column-major**
  (col0's 8 bytes, then col1's…), blitted as one 8-line run per byte-column to
  `dst+k`. `COLBYTES==1` keeps the original tight Model-A loop.
- **`jsp_redraw.asm`** — screen address `cell << CELLSHIFT`; DTT counts from the
  geometry; for Mode 0 (row-padded DTT) the linear cell base is tracked
  incrementally (+8 within a row, +4 at the row wrap).
- **rotating kernels** (`jsp_draw_load1/lb`, `jsp_draw_mask2/lb`) — the SP1
  kernels hard-coded `cc_scratch+n`; `jsp_cc_store.inc`'s `CC_RD/CC_WR/CC_RD16`
  macros keep that absolute addressing for Model A / M2 (13T) and switch to a
  movable `(iy+n)` window (IY = the per-byte-column scratch slot) for Model B
  M1/M0. The `nr` (FAST) kernels already took `dst`.
- **`jsp_covered.asm`** — the covered-cell compositor loops the cell's COLBYTES
  byte-columns: for each screen byte-column the sprite covers, composite source
  byte-column `(bc-c0)` into wide-scratch slot `(bc-B0)·8` via the movable-dst
  kernel, reusing the Model-A graph/pdc math. Model A stays under `ELSE`.
- **`jsp_sprite_defer.asm`** — dirty-marks CELLS (`byte_col >> CELLSHIFT`); the
  Mode-0 DTT is **row-aligned at 3 bytes/row** (24 bits, 4 dead) so each row
  starts byte-aligned and the constant-mask-per-row mark optimisation survives;
  the dead bits are never marked, so the redraw never visits them.

### Not yet implemented (Model-B completeness)

Not exercised by the redraw-perf sprite tests, so they do not affect the
measurement below, but a Model B used for a text/tilemap game would need them:

- `jsp_print_string` 1-cell-per-glyph text (reuse the MONO 1bpp font-expand path).
- `tools/cpcgfx.pl` pixel-cell **tile** emit mode (sprite asset output is
  model-agnostic and already works; only generated background tiles differ).
- Model-B Mode-1 MONO compositor.

---

## 3. Performance measurement

### Method

- **Harness:** each sprite test built with `-DTIME_LIMITED=N` runs exactly N
  `jsp_redraw()` cycles then `di; rst 0` (N ≤ 65535, a uint16 counter; build-time
  `#error` guards larger).
- **Runner:** `tools/cap32-time.sh` runs the `.dsk` headless in cap32 at
  **unlimited speed** (`-O system.limit_speed=0`) with the autocmd
  `run"NAME.` → `CAP32_WAITBREAK` (Z80 breakpoint at addr 0) → `CAP32_EXIT`;
  cap32 stops itself at the `rst 0` and the script prints wall-clock seconds.
- **Boot-free metric:** redraw cost = **t(2000 cycles) − t(1000 cycles)** =
  wall-clock for exactly 1000 redraw cycles, cancelling the constant ~1 s CPC
  boot + one-time background-fill. Wall-clock-on-host proxy (not T-states) — the
  **ratio** is the meaningful figure; ~1–2 % run-to-run noise. Timing runs are
  kept serial (parallel runs contend for CPU and corrupt the numbers).
- **Driver:** `make cpc-perf-matrix [CYCLES=N] [JSP_CELL_MODEL=...]`.

### Model-A baseline (byte-cell), 1000 cycles, full matrix

| Config | Disk | Sprites | Elapsed (s) |
|--------|------|--------:|------------:|
| Mode 2 | CPCSPR | 5 | 7.77 |
| Mode 1 | CPCSPR1 | 5 | 11.24 |
| Mode 1 MONO | CPCSPRM | 5 | 16.12 |
| Mode 0 | CPCSPR0 | 4 | 14.29 |
| Mode 2 FAST | CPCSPR2F | 5 | 6.74 |
| Mode 0 FAST | CPCSPR0F | 4 | 12.87 |
| Mode 1 FAST | CPCSPR1F | 5 | 10.02 |

(Raw wall-clock incl. boot; each row is its own model-vs-model baseline — sprite
counts/motion differ, so do not read *across* rows.)

### Comparison — byte-cell (A) vs pixel-cell (B)

Boot-free redraw cost, same sprite count/art/motion in both models (the Model-A
test source built with `JSP_CELL_MODEL=byte` vs `=pixel`); only the cell model
differs. Lower = faster.

| Mode (5 sprites M1 / 4 M0) | Model A (byte) | Model B (pixel) | Model B speedup |
|----------------------------|---------------:|----------------:|:---------------:|
| **Mode 1** (rotating)      | 10.21 s        | 9.52 s          | **≈ 7 % faster** |
| **Mode 1 FAST** (aligned)  | 8.60 s         | 7.57 s          | **≈ 12 % faster** |
| **Mode 0** (rotating)      | 13.38 s        | 10.94 s         | **≈ 18 % faster** |
| **Mode 0 FAST** (aligned)  | 12.27 s        | 9.40 s          | **≈ 23 % faster** |
| **Mode 2** (any)           | —              | —               | **tie** (identical model) |

Raw wall-clock at 1000 cycles (incl. ~1 s boot), for reference: M1 A 11.24 / B
10.31; M0 A 14.19 / B 11.55; M1-FAST A 10.01 / B 8.99; M0-FAST A 12.88 / B 10.22.

### Reading the result

Model B is **faster in every Mode-0/Mode-1 configuration**, and the win **grows
as the cell count drops**: Mode 1 (2× fewer cells) ≈ 7–12 %, Mode 0 (4× fewer
cells) ≈ 18–23 %. FAST gains a bit more than rotating because the cheaper
per-byte kernel makes per-cell overhead a larger share — and per-cell overhead
(DTT walk, coverage test, cell→address, scratch seed) is exactly what Model B
pays less of. Mode 2 is identical (8 px = 1 byte = one cell), so it is a tie.
This confirms the §1 prediction: constant pixel work, so the coarser grid wins
purely by paying per-cell overhead 2×/4× less.

---

## 4. Decision

**Pixel-cell (Model B) is the default for all CPC modes.** It is faster in
Mode 0 (≈18–23 %) and Mode 1 (≈7–12 %), a tie in Mode 2, and more faithful to
the tilemap/text semantics (1 cell = 8×8 px = one tile/char, like ZX). Byte-cell
(Model A) remains available via `JSP_CELL_MODEL=byte` for comparison or fallback.
Mode 2's pixel-cell build uses the same 8-byte cell and (via the `COLBYTES==1`
guard) the same fast absolute kernels as byte-cell, so nothing is lost there.
