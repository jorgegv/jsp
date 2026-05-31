# JSP-CPC Target — Task List

One line per task. Detail lives in `doc/CPC-TARGET-PLAN.md` (section refs in
parentheses).

## Phase 0 — Seam & ZX regression baseline
- [ ] Add `JSP_TARGET_ZX`/`JSP_TARGET_CPC` umbrella guards (ZX default) around all platform-layer items (§1.2)
- [ ] Guard the screen-addressing code (`jsp_screen.asm`, `rd_rowtab`, `0x4000`/`0x5800`) as ZX-only (§7)
- [ ] Guard the BAT/attribute/colour code (`jsp_color.c`, BAT paints, color merge) as ZX-only (§6)
- [ ] Guard `jsp_rottbl` init/contents and the `sp1_draw_*` kernels as ZX-only (§4,§5)
- [ ] Capture a green ZX build + full ZX test pass as the regression baseline

## Phase 1 — Config header & geometry
- [ ] Create `include/jsp_config.h` deriving per-guard constants from the mode (§8)
- [ ] Define `ppb`, shift-phase count, grid cols/rows/cellcount, cell pixel size, rottbl size, colour mode per guard (§8)
- [ ] Add a compile error when zero or >1 mode guard is defined (§8)
- [ ] Replace hard-coded `768`/`32`/`24`/`96` literals across the engine with config symbols (§2)
- [ ] Decide and apply the descriptor X/Y width strategy (per-target field width) (§3)

## Phase 2 — CPC Mode 2 screen layer
- [ ] Write CPC `jsp_draw_screen_tile` blitting 8 lines stepping `+0x800` (§7)
- [ ] Build the CPC 25-entry `rd_rowtab` = `0xC000 + row*80` and cell-address math (§7)
- [ ] Re-derive the redraw group/column walk for 80 cols / 250 groups (no power-of-two `&31`/`>>2`) (§2,§7,risk2)
- [ ] Drop the attribute store and BAT paint under `JSP_TARGET_CPC` (§6)
- [ ] Widen/raise the `& 0x1F` row/col masks in `jsp_frame.asm` for 80×25 (§2,§3)
- [ ] Confirm JSP's one-store-per-cell already gives the analysis §13 no-flicker/accept-tearing model; add no double buffer (§5.1)
- [ ] Add CPC data-block `__at` placement, sizing and init below `0xC000` (§9)
- [ ] Add CPC test-harness mode-set + palette-program before the first redraw (§11,§6)
- [ ] Prove a background-tile-only CPC Mode 2 image end-to-end via the `caprice-testing` skill (§12)

## Phase 3 — CPC Mode 2 shift + kernels
- [ ] Reuse `jsp_init_rottbl()` for Mode 2 (= ZX linear table) (§4)
- [ ] Confirm the M2 `rottbl_msb` formula + 2-page-per-phase / `inc h` carry contract carry over (§4)
- [ ] Port the 8 `sp1_draw_*` kernels to CPC Mode 2 (near-verbatim) (§5)
- [ ] Wire the covered-cell compositor to the Mode 2 kernels (§5)
- [ ] Verify a moving, sub-byte-shifted CPC Mode 2 sprite on emulator (§12)

## Phase 4 — CPC Mode 2 asset pipeline + shift unit test
- [ ] Define and implement the CPC Mode 2 planar-in-byte pixel+mask asset format (§10)
- [ ] Add the Mode 2 asset emitter (`gfxgen` flag or new emitter) (§10)
- [ ] Unit-test the §8.1 shift/mask against the emitted Mode 2 bytes (§4,§10)
- [ ] Adapt the sprite-gen Makefile targets for Mode 2 (§11)

## Phase 5 — Mode 2 full test pass
- [ ] Build all `tests/*` under `CPC_MODE2` (§11)
- [ ] Visually verify all tests under `CPC_MODE2` via the `caprice-testing` skill (cap32 headless) (§11)
- [ ] Lock Mode 2 as the reference CPC pipeline (§12)

## Phase 6 — CPC Mode 1
- [ ] Add the Mode 1 nibble-plane shift table + `jsp_init_rottbl` Mode 1 variant (§4)
- [ ] Define the Mode 1 `rottbl_msb` formula + table stride (3 phases, 2-page-per-phase) (§4)
- [ ] Write the Mode 1 `sp1_draw_*` kernels (§5)
- [ ] Define + emit the Mode 1 planar (two nibble-planes) asset format (§10)
- [ ] Unit-test the §8.2 shift/mask against the emitted Mode 1 bytes (§4,§10)
- [ ] Resolve and implement the `CPC_MODE1_MONO` encoding decision (§8)
- [ ] Test pass under `CPC_MODE1` and `CPC_MODE1_MONO` (§12)

## Phase 7 — CPC Mode 0
- [ ] Add the Mode 0 odd/even interleave shift table (single phase) (§4)
- [ ] Define the Mode 0 `rottbl_msb` / single-phase table addressing (xrot 0/1) (§4)
- [ ] Write the Mode 0 `sp1_draw_*` kernels (§5)
- [ ] Define + emit the Mode 0 interleaved asset format (§10)
- [ ] Unit-test the §8.3 shift/mask against the emitted Mode 0 bytes (§4,§10)
- [ ] Test pass under `CPC_MODE0` (§12)

## Phase 8 — FAST variants
- [ ] Implement `CPC_MODE0_FAST` (force shift=0, `nr` kernel only, no shift table) (§3,§8)
- [ ] Implement `CPC_MODE1_FAST` (force shift=0, `nr` kernel only, no shift table) (§3,§8)
- [ ] Test pass under both FAST modes (§12)

## Phase 9 — Toolchain matrix & docs
- [ ] Parameterise the Makefile by `JSP_TARGET` and `JSP_CPC_MODE` with a build-matrix target (§11)
- [ ] Build `+cpc -create-app -subtype=dsk` and add a `make run` branch invoking the `caprice-testing` skill (§11,risk7)
- [ ] Adapt `tools/cap32-shot.sh` defaults / wire it to the JSP test build outputs (§11)
- [ ] Document the CPC profiling gap (visual via cap32; no T-state heatmap yet) (§11,risk5)
- [ ] Update `doc/ENGINE.md` with CPC memory maps, screen layout and the colour divergence (§6,§9)
- [ ] Update `README.md`; add `doc/CPC-MODES.md` if per-mode detail outgrows the plan (§12)

## Cross-cutting / sign-off
- [ ] Confirm with user that baked-in pixel colour (no dynamic recolour) is acceptable for first CPC milestone (§6,risk4)
- [ ] Confirm the Mode 2 memory budget (tables + rottbl + program) fits below `0xC000` (§9,risk6)
- [ ] Measure the 2000-cell / 250-group redraw cost early vs the ZX 768/96 baseline (§13 risk8)
- [ ] Definition-of-done: all 7 configs run pixel-smooth on emulator, ZX baseline unchanged, shift unit tests green (§14)
