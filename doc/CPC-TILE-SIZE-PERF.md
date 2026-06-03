# JSP-CPC — Tile-Size Model Performance Study

Measured comparison of the **byte-cell** (Model A, current) vs **pixel-cell**
(Model B) cell models, to decide which JSP should use per mode. Companion to
`doc/CPC-TILE-SIZE-ANALYSIS.md` (the qualitative analysis, which deferred the
decision to "measure, not argue"). This file is the measurement record.

## Method

- **Harness:** each sprite test is built with `-DTIME_LIMITED=N` (Makefile
  `CPC_EXTRA_CFLAGS`), which runs exactly N `jsp_redraw()` cycles then `di; rst 0`.
- **Runner:** `tools/cap32-time.sh` runs the `.dsk` headless in cap32 at
  **unlimited speed** (`-O system.limit_speed=0`) with the autocmd sequence
  `run"NAME.` → `CAP32_WAITBREAK` (Z80 breakpoint at addr 0) → `CAP32_EXIT`.
  cap32 stops itself at the `rst 0`; the script reports wall-clock launch→exit
  seconds.
- **Driver:** `make cpc-perf-matrix CYCLES=N` rebuilds + times all 7 sprite
  configs in sequence.
- **Metric meaning:** elapsed = `~1.0s constant boot + k·N`. The constant boot
  overhead **cancels when comparing two models for the same config**, so the
  valid comparison is byte-cell-vs-pixel-cell within one config — *not* across
  configs (which differ in sprite count and motion range). Lower = faster.
- **Caveats:** wall-clock on a loaded host carries ~1–2% noise; timing runs are
  kept **serial** (parallel runs would contend for CPU and corrupt the numbers).
  The cycle counters are `uint16_t`, so `CYCLES` must be **≤ 65535** (a build-time
  `#error` guards this). `test_cpc_sprite_demo.c` also honours `TIME_LIMITED` for
  ad-hoc Mode-2 timing, but it is **not** part of `cpc-perf-matrix` — the 7 matrix
  configs are all built from the 4 bounded sprite tests via `CPC_MODE`.

## Baseline — Model A (byte-cell, current), 1000 cycles

Measured 2026-06-03, `make cpc-perf-matrix CYCLES=1000`.

| Config        | Disk      | Sprites | Elapsed (s) |
|---------------|-----------|--------:|------------:|
| Mode 2        | CPCSPR    | 5       | 7.767       |
| Mode 1        | CPCSPR1   | 5       | 11.236      |
| Mode 1 MONO   | CPCSPRM   | 5       | 16.120      |
| Mode 0        | CPCSPR0   | 4       | 14.294      |
| Mode 2 FAST   | CPCSPR2F  | 5       | 6.741       |
| Mode 0 FAST   | CPCSPR0F  | 4       | 12.866      |
| Mode 1 FAST   | CPCSPR1F  | 5       | 10.023      |

(Mode 0 uses 4 sprites vs 5 elsewhere — do not read across rows; each row is
its own model-vs-model baseline.)

## Model B (pixel-cell) — implemented + measured (2026-06-04)

Model B (8×8-pixel cells) was implemented as a compile-time alternative
(`-DJSP_CELL_MODEL_PIXEL`, Makefile `JSP_CELL_MODEL=pixel`), guarded so Model A
and ZX stay byte-identical. Phases: config (grid derives from ppb), wide-cell
addressing, movable-dst rotating kernels (IY), the byte-column covered-cell
compositor, and Mode-0's row-aligned DTT. All render-verified in cap32
(Model-B M1/M0 sprites composite cleanly; Model-A M2/M1/M0 unchanged).

## Comparison — byte-cell (A) vs pixel-cell (B)

To remove the constant CPC boot + one-time background-fill overhead, the redraw
cost is measured as **t(2000 cycles) − t(1000 cycles)** = wall-clock seconds for
exactly 1000 `jsp_redraw()` cycles, boot-free. Same sprite count, art and motion
in both models (Model-A test vs the `*_pixcell` twin); the only difference is the
cell model. Lower = faster. (Wall-clock-on-host proxy, not T-states — the **ratio**
is the meaningful figure; ~1–2% run-to-run noise.)

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

Model B (pixel-cell) is **faster in every Mode-0 and Mode-1 configuration**, and
the win **grows as the cell count drops**: Mode 1 (2× fewer cells than Model A)
≈ 7–12 %, Mode 0 (4× fewer cells) ≈ 18–23 %. FAST gains a bit more than rotating
because the cheaper per-byte kernel makes per-cell overhead a larger share — and
per-cell overhead (DTT walk, coverage test, cell→address, scratch seed) is exactly
what Model B pays less of. **Mode 2 is identical** in both models (8 px = 1 byte =
one cell either way), so it is a tie — keep it on the simpler byte-cell path.

This confirms the qualitative prediction in `CPC-TILE-SIZE-ANALYSIS.md`: pixel
work is constant, so the coarser pixel-cell grid wins purely by paying per-cell
overhead 2×/4× less in M1/M0.

## Decision — the user's call

Per-mode recommendation from the data: **Mode 0 → pixel-cell** (biggest win),
**Mode 1 → pixel-cell** (clear win), **Mode 2 → byte-cell** (tie; simplest).
Awaiting the user's decision on the official model before wiring it as default.

_(Completeness note: text/`jsp_print_string` 1-cell-per-glyph semantics, the
`tools/cpcgfx.pl` pixel-cell asset emit mode, and Model-B MONO remain unimplemented
— they are not exercised by the redraw-perf sprite tests and do not affect the
measurement above.)_
