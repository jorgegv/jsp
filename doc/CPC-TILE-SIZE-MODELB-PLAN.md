# JSP-CPC — Pixel-Cell (Model B) Implementation Plan

The model being built is the **8×8-pixel cell model (Model B)**: a cell is always
8×8 pixels, so the grid is **20×25 (M0), 40×25 (M1), 80×25 (M2)** and cell
byte-width is **32/16/8 B**. **Mode 2 is identical to the current byte-cell model
(Model A)** — Model B only changes Modes 0 and 1. Model B is added as a
**compile-time-selectable alternative** (`JSP_CELL_MODEL_PIXEL` guard), built and
measured alongside Model A, never replacing it — so the regression suite is never
rebaselined.

Companion docs: `CPC-TILE-SIZE-ANALYSIS.md` (qualitative analysis),
`CPC-TILE-SIZE-PERF.md` (harness + Model-A baseline).

## Locked decisions (user-confirmed)

- **Model selection:** a **single global switch** `-DJSP_CELL_MODEL_PIXEL` (NOT
  per-mode tokens). When defined, M0/M1 use pixel-cells; M2 is identical either
  way (guarded by `#error`).
- **M0 20-col DTT:** **row-aligned, 3 bytes/row** (60 B) — preserves the
  constant-mask-per-row optimization.
- **ROM font in M0/M1:** **reuse the MONO expand path** — keep the 8-byte 1bpp
  font and expand at blit; no pre-encoded 16/32-byte font tiles.
- **Order:** implement all phases end-to-end (no special ordering constraints).

## Decisive facts from code exploration

- **The engine is already parameterized.** `include/jsp_config.h:63-66` defines
  `JSP_GRID_COLS`, `JSP_GRID_ROWS`, `JSP_CELL_BYTES`; the comment at lines 19-25
  explicitly anticipates Model B ("would set 32/16/8 for M0/M1/M2"). All five
  tables (`lib/jsp_data.c:55-67`) size from `JSP_GRID_CELLS`/`JSP_CELL_BYTES`,
  and `JSP_DTT_BYTES`/`JSP_FTT_BYTES` derive from `JSP_GRID_CELLS`. Table RAM
  auto-shrinks for Model B with no edit beyond the macro block.
- **Mode 2 is byte-for-byte identical** → it is the regression anchor; a `#error`
  guard forces M2 Model-B constants to equal Model A so M2 can never diverge.
- **The MONO compositor (`lib/cpc/jsp_covered_mono.asm`) is a working prototype**
  of the exact "map one cell to a sub-portion of a wider unit, loop the existing
  per-byte-column kernel" mechanism Model B needs. This de-risks the hardest part.
- **The hard-coded grid math is concentrated** in a few CPC asm files
  (`jsp_rowcolindex.asm`, `jsp_sprite_defer.asm`, `jsp_redraw.asm`,
  `jsp_covered.asm`, `jsp_screen.asm`).
- **The one place verified code must be reopened:** the kernels write to absolute
  `cc_scratch+0..7` (`jsp_draw_load1.asm:78-146`); looping over a cell's byte
  columns needs a *movable* 8-byte write window. Handled additively (new guarded
  kernel variant; M2/Model-A kernels never edited).

## Phases (each builds + verifies independently; M2 invariance proven first)

0. **Model-selection plumbing** — `JSP_CELL_MODEL_PIXEL` guard; M0=20col/32B,
   M1=40col/16B, M2 asserted identical; derived `JSP_CELL_COLBYTES` (1/2/4);
   mirror geometry into `jsp_cpc_geom.inc`; new Makefile targets. *No behavior
   change.* Verify: Model-A matrix unchanged, Model-B compiles.
1. **Grid math & addressing** — cell→screen `0xC000 + row*80 + col*COLBYTES`;
   blit `COLBYTES` bytes/line; DTT group counts from `JSP_DTT_BYTES`. Verify:
   Model-B M1 background tiles land correctly; M2 unchanged.
2. **Looped per-byte-column kernel** (reopens verified code, additively) — a
   movable-`dst` kernel variant; `graph_left` carry spills column→column *inside*
   the cell. FAST (no-rotate) first. Verify: host `shift_test_*_pixcell`.
3. **Covered-cell compositor** (hardest) — fork `jsp_covered.asm` like the MONO
   fork; map each covering sprite to a subset of the cell's byte-columns, loop the
   Phase-2 kernel. FAST compositor first, then rotating (M1), then M0. Verify:
   sprite screenshots are **pixel-identical to the Model-A oracle** at the same
   position (same pixels, different decomposition) — zero new baselines.
4. **Mode-0 20-col DTT wrinkle** — 20 not a multiple of 8 breaks the
   constant-mask-per-row optimization. **Recommend row-aligned 3-byte/row DTT**
   (preserves the optimization; 60 B) with pad-to-24 as fallback. M0-only.
5. **Tile/text/sprite-cols semantics & assets** — in Model B a tile/char/sprite-
   col is one 8×8 cell again (ZX-like); restore `cols` to 8-px units; BTT tiles
   become 16/32 B; reuse the MONO expand path for the 8-byte ROM font; add a
   `--cell-model pixel` emit mode to `tools/cpcgfx.pl`; Model-B test files.
6. **Regression gate** — re-run `make cpc-matrix` + `cpc-perf-matrix CYCLES=1000`;
   confirm the Model-A baseline reproduces. Model-B uses Model-A screenshots as
   its oracle (same pixels) → no rebaseline.
7. **Measurement** — Model-B `cpc-perf-matrix` series; fill the comparison table
   in `CPC-TILE-SIZE-PERF.md`; the official-model choice is the user's.

## Key risks

- **Reopening the kernel `cc_scratch+N` write** (Phase 2) → additive guarded
  variant; M2/Model-A kernels untouched, so a regression is structurally
  impossible.
- **Intra-cell `graph_left` carry across a cell's left edge** (Phase 3) → the
  verified MONO fork is the template.
- **M0 20-col DTT** (Phase 4) → row-aligned DTT preserves the optimization.
- **Model-B tile/font width 16/32 B** (Phase 5) → reuse the MONO font-expand path.

## Critical files

- `include/jsp_config.h` — guard + grid/cell parameterization, `JSP_CELL_COLBYTES`.
- `lib/cpc/jsp_covered.asm` — compositor (modeled on `jsp_covered_mono.asm`).
- `lib/cpc/jsp_draw_load1.asm` / `jsp_draw_mask2.asm` (+ `*nr`) — looped kernel.
- `lib/cpc/jsp_sprite_defer.asm` — M0 DTT row-alignment.
- `tools/cpcgfx.pl` — pixel-cell asset emit (`cols` back to 8-px cells).
- Supporting: `jsp_redraw.asm`, `jsp_screen.asm`, `jsp_rowcolindex.asm`,
  `jsp_cpc_geom.inc`, `lib/jsp_sprite_c.c`.
