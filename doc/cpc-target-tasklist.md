# JSP-CPC Target — Task List

One line per task. Detail lives in `doc/CPC-TARGET-PLAN.md` (section refs in
parentheses). Phases and tasks are both checkboxes; tick a phase when all its
tasks are done. Set a task's checkbox to [~] the moment you start working on it.

**Regression gate:** every phase ends with a green regression run — the ZX build
+ all ZX tests still pass, plus the CPC tests for every mode completed so far.
This is the last checkbox of each phase; do not tick the phase until it passes.

- [x] **Phase R — `sp1_*` → `jsp_*` rename (prerequisite)**
  - [x] Rename the 8 `lib/sp1_draw_*.asm` kernel files to `lib/jsp_draw_*.asm`
  - [x] Rename the public symbols `_sp1_draw_*` / `_SP1_DRAW_*` to `_jsp_draw_*` / `_JSP_DRAW_*`
  - [x] Rename internal kernel labels (`_SP1Mask2Rotate`, `…NR`, etc.) to `jsp_*`
  - [x] Update all `extern`/`public`/`call` references (notably `lib/jsp_covered.asm`)
  - [x] Rename the `sp1_draw_*` prototypes in `include/jsp.h` to `jsp_draw_*`
  - [x] Update the Makefile / wildcards and any other references to the renamed files (wildcard `lib/*.asm` auto-picks renamed files; no edit needed)
  - [x] Keep the "based on SP1 / thanks Alvin" credit lines in comments verbatim (rename code only, not credits)
  - [x] Leave the standalone SP1 benchmark (`tests/bench_sp1.c`) untouched — it uses the real SP1
  - [x] Rebuild ZX + full ZX test pass green after the rename

- [x] **Phase 0 — Seam & ZX regression baseline**
  - [x] Add `JSP_TARGET_ZX`/`JSP_TARGET_CPC` umbrella guards (ZX default) via `include/jsp_target.h`; asm uses `IFNDEF JSP_TARGET_CPC` + zcc `-Ca-D` passthrough (§1.2)
  - [x] Guard the screen-addressing code: `jsp_screen.asm` whole-file `IFNDEF`; `rd_rowtab`/`0x4000`/`0x5800` in `jsp_redraw.asm` SEAM-marked (functional split is Phase 2's CPC rewrite) (§7)
  - [x] Guard the BAT/attribute/colour code: `jsp_color.c` body under `JSP_TARGET_ZX` (no-op on CPC); BAT paint/colour merge in `jsp_redraw`/`jsp_covered` SEAM-marked (§6)
  - [x] Guard the 8 `jsp_draw_*` kernels whole-file `IFNDEF` (`jsp_rottbl` init left shared — CPC Mode 2 reuses it, §4) (§4,§5)
  - [x] Capture a green ZX build + full ZX test pass as the regression baseline (main.tap byte-for-byte identical; 9 test taps green)

- [ ] **Phase 1 — Config header & geometry**
  - [ ] Create `include/jsp_config.h` deriving per-guard constants from the mode (§8)
  - [ ] Define `ppb`, shift-phase count, grid cols/rows/cellcount, cell pixel size, rottbl size, colour mode per guard (§8)
  - [ ] Expose `JSP_CELL_BYTES`/`JSP_GRID_COLS`/`JSP_GRID_ROWS` as macros to keep byte-cell vs pixel-cell open (CPC-TILE-SIZE-ANALYSIS.md, §2)
  - [ ] Add a compile error when zero or >1 mode guard is defined (§8)
  - [ ] Replace hard-coded `768`/`32`/`24`/`96`/`8` literals across the engine with config symbols (§2)
  - [ ] Decide and apply the descriptor X/Y width strategy (per-target field width) (§3)
  - [ ] Regression gate: ZX build + all ZX tests green (§12)

- [ ] **Phase 2 — CPC Mode 2 screen layer**
  - [ ] Write CPC `jsp_draw_screen_tile` blitting 8 lines stepping `+0x800` (§7)
  - [ ] Build the CPC 25-entry `rd_rowtab` = `0xC000 + row*80` and cell-address math (§7)
  - [ ] Re-derive the redraw group/column walk for 80 cols / 250 groups (no power-of-two `&31`/`>>2`) (§2,§7,risk2)
  - [ ] Drop the attribute store and BAT paint under `JSP_TARGET_CPC` (§6)
  - [ ] Widen/raise the `& 0x1F` row/col masks in `jsp_frame.asm` for 80×25 (§2,§3)
  - [ ] Confirm JSP's one-store-per-cell already gives the analysis §13 no-flicker/accept-tearing model; add no double buffer (§5.1)
  - [ ] Add CPC data-block `__at` placement, sizing and init below `0xC000` (§9)
  - [ ] Add CPC test-harness mode-set + palette-program before the first redraw (§11,§6)
  - [ ] Prove a background-tile-only CPC Mode 2 image end-to-end via the `caprice-testing` skill (§12)
  - [ ] Regression gate: ZX green + CPC Mode 2 background render green (§12)

- [ ] **Phase 3 — CPC Mode 2 shift + kernels**
  - [ ] Reuse `jsp_init_rottbl()` for Mode 2 (= ZX linear table) (§4)
  - [ ] Confirm the M2 `rottbl_msb` formula + 2-page-per-phase / `inc h` carry contract carry over (§4)
  - [ ] Port the 8 `jsp_draw_*` kernels to CPC Mode 2 (near-verbatim) (§5)
  - [ ] Wire the covered-cell compositor to the Mode 2 kernels (§5)
  - [ ] Verify a moving, sub-byte-shifted CPC Mode 2 sprite on emulator (§12)
  - [ ] Regression gate: ZX green + CPC Mode 2 sprite render green (§12)

- [ ] **Phase 4 — CPC Mode 2 asset pipeline + shift unit test**
  - [ ] Define and implement the CPC Mode 2 planar-in-byte pixel+mask asset format (§10)
  - [ ] Add the Mode 2 asset emitter (`gfxgen` flag or new emitter) (§10)
  - [ ] Reuse the ZX sprite source art (re-convert `assets/*.png` per mode), don't hand-author CPC sprites (§10,§11)
  - [ ] Unit-test the §8.1 shift/mask against the emitted Mode 2 bytes (§4,§10)
  - [ ] Adapt the sprite-gen Makefile targets for Mode 2 (§11)
  - [ ] Regression gate: ZX green + CPC Mode 2 (incl. shift unit test) green (§12)

- [ ] **Phase 5 — Mode 2 full test pass**
  - [ ] Keep CPC tests as the ZX tests recompiled (same layout/sprites); palette mirrors ZX colours (§11)
  - [ ] Build all `tests/*` under `CPC_MODE2` (§11)
  - [ ] Visually verify all tests under `CPC_MODE2` via the `caprice-testing` skill (cap32 headless) (§11)
  - [ ] Lock Mode 2 as the reference CPC pipeline (§12)
  - [ ] Regression gate: ZX green + full CPC Mode 2 test pass green (§12)

- [ ] **Phase 6 — CPC Mode 1**
  - [ ] Add the Mode 1 nibble-plane shift table + `jsp_init_rottbl` Mode 1 variant (§4)
  - [ ] Define the Mode 1 `rottbl_msb` formula + table stride (3 phases, 2-page-per-phase) (§4)
  - [ ] Write the Mode 1 `jsp_draw_*` kernels (§5)
  - [ ] Define + emit the Mode 1 planar (two nibble-planes) asset format (§10)
  - [ ] Unit-test the §8.2 shift/mask against the emitted Mode 1 bytes (§4,§10)
  - [ ] Resolve and implement the `CPC_MODE1_MONO` encoding decision (§8)
  - [ ] Test pass under `CPC_MODE1` and `CPC_MODE1_MONO` (§12)
  - [ ] Regression gate: ZX green + CPC Mode 2 + Mode 1/MONO green (§12)

- [ ] **Phase 7 — CPC Mode 0 (+ cell-model decision)**
  - [ ] Prototype the Mode 0 covered-cell compositor both ways (byte-cell A / pixel-cell B) and measure (CPC-TILE-SIZE-ANALYSIS.md)
  - [ ] Pick the cell model, record the outcome in CPC-TILE-SIZE-ANALYSIS.md, reconcile §2/§9 + Mode 1 if it differs from the M2 default
  - [ ] Add the Mode 0 odd/even interleave shift table (single phase) (§4)
  - [ ] Define the Mode 0 `rottbl_msb` / single-phase table addressing (xrot 0/1) (§4)
  - [ ] Write the Mode 0 `jsp_draw_*` kernels (§5)
  - [ ] Define + emit the Mode 0 interleaved asset format (§10)
  - [ ] Unit-test the §8.3 shift/mask against the emitted Mode 0 bytes (§4,§10)
  - [ ] Test pass under `CPC_MODE0` (§12)
  - [ ] Regression gate: ZX green + CPC Mode 2 + Mode 1/MONO + Mode 0 green (§12)

- [ ] **Phase 8 — FAST variants**
  - [ ] Implement `CPC_MODE0_FAST` (force shift=0, `nr` kernel only, no shift table) (§3,§8)
  - [ ] Implement `CPC_MODE1_FAST` (force shift=0, `nr` kernel only, no shift table) (§3,§8)
  - [ ] Test pass under both FAST modes (§12)
  - [ ] Regression gate: ZX green + all CPC modes incl. FAST green (§12)

- [ ] **Phase 9 — Toolchain matrix & docs**
  - [ ] Parameterise the Makefile by `JSP_TARGET` and `JSP_CPC_MODE` with a build-matrix target (§11)
  - [ ] Build `+cpc -create-app -subtype=dsk` and add a `make run` branch invoking the `caprice-testing` skill (§11,risk7)
  - [ ] Adapt `tools/cap32-shot.sh` defaults / wire it to the JSP test build outputs (§11)
  - [ ] Document the CPC profiling gap (visual via cap32; no T-state heatmap yet) (§11,risk5)
  - [ ] Update `doc/ENGINE.md` with CPC memory maps, screen layout and the colour divergence (§6,§9)
  - [ ] Update `README.md`; add `doc/CPC-MODES.md` if per-mode detail outgrows the plan (§12)
  - [ ] Regression gate: full matrix green (ZX + all CPC modes) (§12)

- [ ] **Cross-cutting / sign-off**
  - [ ] Confirm with user that baked-in pixel colour (no dynamic recolour) is acceptable for first CPC milestone (§6,risk4)
  - [ ] Confirm the Mode 2 memory budget (tables + rottbl + program) fits below `0xC000` (§9,risk6)
  - [ ] Measure the 2000-cell / 250-group redraw cost early vs the ZX 768/96 baseline (§13 risk8)
  - [ ] Definition-of-done: all 7 configs run pixel-smooth on emulator, ZX baseline unchanged, shift unit tests green (§14)
