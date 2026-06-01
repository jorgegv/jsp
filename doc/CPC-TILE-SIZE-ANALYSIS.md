# JSP-CPC — Cell/Tile-Size Model Analysis (byte-cell vs pixel-cell)

**Status: DECIDED — Model A (byte-cell).** Settled at the start of Phase 7
(CPC Mode 0). The whole CPC port uses the byte-cell model: cell = 8 lines × 1
byte, 80×25 = 2000-cell grid in every mode; cell pixel-width = 2/4/8 px for
M0/M1/M2. See "Decision (Phase 7)" below for the rationale.
**Date:** 2026-06-01
**Context:** While planning the CPC port (`doc/CPC-TARGET-PLAN.md` §2), the
question arose: should a JSP-CPC "cell" be a fixed **8 bytes** (variable pixel
width per mode) or a fixed **8×8 pixels** (variable byte width per mode)?

This document captures the full analysis so the choice can be made later with
context, instead of being silently baked in. `doc/CPC-TARGET-PLAN.md` §2/§9
currently *implements* Model A for the Mode-2 bring-up; this doc is the record of
why that is provisional and what would make Model B the better call.

---

## The two models

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

---

## Two facts that frame the whole decision

1. **Mode 2 is identical in both models.** 8 px = 8 bytes = a 1-byte-wide cell,
   80×25, either way. **This choice only affects Mode 0 and Mode 1.** Since Mode
   2 is the first target, the decision can be deferred without blocking anything.

2. **Total pixel work is constant** across modes and across both models — the
   screen is always 16000 bytes and each dirty pixel is written once. So this is
   *not* a "cheap walk vs expensive blit" trade. The blit pixel-work is equal.
   What varies is **per-cell overhead** (cell addressing, coverage test, clip
   test, attribute, scratch seed) — paid per *cell*, not per *pixel*.

Consequence of (2): Model B's Mode 0 has **4× fewer cells** than Model A for the
same pixels, so it pays per-cell overhead 4× less (Mode 1 = 2× less). So Model B
is likely **faster in Mode 0**, not a wash — the opposite of the naive "coarser
cell = pricier blit" intuition. The pixel blitting is identical; only the
overhead differs, and coarser cells *reduce* overhead.

---

## Where each model wins

### Model B (pixel-cell) advantages

- **Tilemap / text / sprite-footprint fidelity — the decisive point.** JSP *is* a
  tilemap engine: BTT = one 8×8 tile per cell, `jsp_print_string`, `jsp_tile_put`,
  the ROM-font table, and "sprite `cols`" all assume **1 cell = 1 char = 1 tile =
  8×8 px**. Model B keeps that in every mode (a 16-px sprite = 2 cols, like ZX; a
  printed char advances 1 col). The project's north star
  (`CPC-SPRITE-ENGINE-ANALYSIS.md` §11.1) is "keep the high-level architecture
  unchanged" — and that architecture is the *tilemap semantics*, not the
  scratch-buffer byte count. Model B is more faithful to the real promise.
- **Less per-cell overhead and less table RAM in M0/M1** (fewer cells → smaller
  BTT/DTT/FTT, fewer coverage tests, cheaper DTT walk).

### Model A (byte-cell) advantages

- **Simplest, most ZX-like sprite compositor.** Cell = byte-column =
  sprite-column, so the existing `graph`/`graph_left` per-column kernel works
  verbatim: a sprite either covers a cell or it doesn't. This keeps complexity
  out of the hottest, most bug-prone code.
- **Clean grid math.** 80 is a multiple of 8 → clean byte-packed DTT grouping
  (10 groups/row). Model B's **Mode 0 = 20 columns is NOT a multiple of 8**, so
  byte-packed DTT groups straddle rows — a real wrinkle (pad to 24 cols, or
  row-align the DTT, both diverging from ZX's flat DTT).
- **Uniform engine geometry** (one grid size, one cell size) → fewer per-mode
  constants sprinkled through the engine.

---

## Two myths to retire

- **"Model B breaks the 8-byte scratch/kernel invariant."** (The original §2
  rejection.) Not really: Model B can keep the constant **8-byte-column kernel
  and scratch**, and just *loop it over each cell's byte-columns* (1/2/4 columns
  for M2/M1/M0), with the shift carry spilling column→column — the exact ZX
  cross-column `graph_left` mechanism, applied inside the cell instead of between
  cells. So the kernel/scratch need not grow.
- **"It's a walk-vs-blit wash."** No — pixel work is constant (fact 2); the real
  axis is per-cell overhead, which Model B reduces in M0/M1.

## The cost Model B genuinely cannot avoid

Even with the looped byte-column kernel, **the covered-cell compositor is more
complex in Model B**: a sprite can land at an arbitrary byte *within* an 8×8
cell, so for each covering sprite the compositor must map it to a *subset of
byte-columns inside the cell* (which columns, with which graph pointer). In Model
A, cell = byte-column = sprite-column, so this mapping is trivial. So **complexity
is conserved, it just moves**: Model A pushes it into cold tile/text/print code
(multi-cell glyphs, `cols` in 2-px units); Model B pushes it into the hot
compositor (intra-cell column mapping) plus the Mode-0 grid-alignment wrinkle.

---

## Performance summary (qualitative)

| Axis | M0 | M1 | M2 |
|---|---|---|---|
| Pixel blit work | equal | equal | equal |
| Per-cell overhead (walk, coverage, setup) | **B ≪ A** (4×) | **B < A** (2×) | equal |
| Compositor complexity | A simpler | A simpler | equal |
| Table RAM | **B < A** | **B < A** | equal |
| Tile/text/footprint fidelity | **B** | **B** | equal |

Net expectation: **B likely faster + leaner + more faithful in M0/M1**, at the
cost of a more complex covered-cell compositor and the 20-col DTT wrinkle. M2 is
a tie. This is close enough that it should be **measured, not argued**.

---

## Recommendation (agreed)

1. **Do not commit now.** Build the whole pipeline on **Mode 2 first** (identical
   in both models), as the plan already sequences.
2. **Parameterize the engine** so neither model is baked in: expose
   `JSP_CELL_BYTES`, `JSP_GRID_COLS`, `JSP_GRID_ROWS` (and derived cell count) as
   config macros in Phase 1. Mode-2 values are the same for A and B, so this costs
   ~nothing and keeps both options open.
3. **Decide for Mode 0 / Mode 1 by prototype + measurement:** when reaching
   Mode 0 (the extreme 4× case), prototype the covered-cell compositor **both
   ways** and compare on (a) redraw T-states under a representative sprite load,
   (b) code size, (c) table RAM, (d) tile/text-code complexity. Pick per result;
   Mode 1 likely follows Mode 0's choice.

If forced to choose blind today: lean **Model B** (tilemap/text fidelity + M0/M1
overhead/RAM win), implemented as the B-grid + looped 8-byte-column kernel, eating
the intra-cell mapping cost in the compositor. Model A is the defensible fallback
if that compositor complexity or the 20-col DTT wrinkle proves nastier in practice
than multi-cell glyphs.

---

## Decision (Phase 7) — Model A (byte-cell)

Decided at the start of Phase 7. **The decision context changed from the "blind"
lean above:** by the time Mode 0 was reached, **Mode 2 and Mode 1 were already
implemented and verified in Model A** (80-col grid, 1-byte cells, the
`graph`/`graph_left` per-byte-column compositor + the shared table-driven
kernels). That reframes the trade:

- **Zero rework + consistency.** Model A makes Mode 0 a near-clone of Mode 1
  (ppb=2, a single shift phase) and reuses the entire verified
  frame/compositor/kernel chain unchanged. Model B would mean *redoing the
  verified Mode 1* (intra-cell column mapping) plus the Mode-0 20-col DTT wrinkle.
- **The Model-B win is unmeasurable here.** Its claimed M0/M1 advantage is
  per-cell-overhead / RAM / "likely faster" — but there is **no headless CPC
  T-state profiler** (`CPC-TARGET-PLAN.md` §11, risk 5), so "measure, not argue"
  cannot actually be executed. With no measurement to justify reopening verified
  code, the safe, consistent choice wins.
- **Model A's cost is cold-path only.** A tile/char is 2 px wide in Mode 0 (spans
  4 cells) and `cols` is in 2-px byte units; the hot compositor stays simplest.
  Table RAM is the 2000-cell maximum (fits the budget, §9).

If a CPC profiler later lands and shows a decisive Model-B win for a real
workload, this can be revisited — but it would be a deliberate, measured rewrite,
not the default.

**Reconciliation:** `doc/CPC-TARGET-PLAN.md` §2/§9 already describe Model A as the
working model; no change needed. Mode 1 stays as built. The byte-cell figures
(BTT 4000, DTT/FTT 250, 80×25 grid) hold for all modes.
