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

- [x] **Phase 1 — Config header & geometry**
  - [x] Create `include/jsp_config.h` deriving per-guard constants from the mode (§8)
  - [x] Define `ppb`, shift-phase count, grid cols/rows/cellcount, cell size, rottbl phases, colour mode (`JSP_HAS_ATTR`) per guard (§8)
  - [x] Expose `JSP_CELL_BYTES`/`JSP_GRID_COLS`/`JSP_GRID_ROWS` as macros to keep byte-cell vs pixel-cell open (CPC-TILE-SIZE-ANALYSIS.md, §2)
  - [x] Add a compile error when zero or >1 mode guard is defined (§8)
  - [x] Replace hard-coded `768`/`32`/`24`/`96`/`7` literals in the C engine with config symbols (asm grid math deferred to its Phase-2 CPC variants) (§2)
  - [x] Decide descriptor X/Y width (per-target `jsp_coord_t`, ZX=uint8_t byte-for-byte; 16-bit CPC X applied with the asm/API in Phase 3) (§3)
  - [x] Regression gate: ZX build byte-for-byte identical + 9 test taps green (§12)

- [x] **Phase 1.1 — Platform source-tree reorganization** (pure file move, no new guards, §1.3)
  - [x] Create `lib/zx/` and `lib/cpc/` directories (`lib/cpc/` holds a README placeholder until Phase 2)
  - [x] Move the wholly-ZX platform files into `lib/zx/` per the §1.3 table (screen, redraw, covered, frame, sprite_defer, 8 kernels)
  - [x] Split `jsp_util.asm` → `lib/jsp_mem.asm` (shared) + `lib/zx/jsp_rowcolindex.asm` (ZX)
  - [x] Moved files keep their existing Phase-0 guard/SEAM marking; add no new guards (§1.3)
  - [x] Makefile: add `lib/$(JSP_TARGET)/*` (`JSP_TARGET ?= zx`) to BOTH `C_SRCS`/`ASM_SRCS` AND the per-test `LIB_SRCS`
  - [x] Makefile: extend `clean` to `lib/zx/` + `lib/cpc/` (`.o/.lis/.sym/.map`)
  - [x] Regression gate: ZX all green — build + 9 test taps link clean; sprite-move render pixel-identical (new baseline `959048ee…`) (§12)

- [x] **Phase 2 — CPC Mode 2 screen layer** (background-tile milestone)
  - [x] Write CPC `jsp_draw_screen_tile` blitting 8 lines stepping `+0x800` (`lib/cpc/jsp_screen.asm`) (§7)
  - [x] Cell-address math: in Model A, cell == byte offset, so a cell's line-0 addr is just `0xC000 + cell` — no `rd_rowtab`/row-col split needed (§7)
  - [x] Redraw walk for 250 groups (`lib/cpc/jsp_redraw.asm`); background path needs only the cell running counter (no power-of-two `&31`/`>>2`) (§2,§7,risk2)
  - [x] No attribute store / BAT paint in the CPC redraw (§6)
  - [~] `& 0x1F` mask widening lives in the CPC `jsp_frame` precompute — deferred to Phase 3 (Phase-2 `jsp_frame` is a stub: frame_count=0, background only) (§2,§3)
  - [x] Confirm one-store-per-cell (single blit) → no-flicker, no double buffer (§5.1)
  - [x] Add CPC data-block `__at` placement below `0xC000` (`jsp_data.c` `JSP_TARGET_CPC` branch, 2000-cell sizes) (§9)
  - [x] Shared `lib/` files compile for CPC as-is (BAT kept allocated so `jsp_bat[]` writes are harmless; `0x3D00` font ptrs set-but-unused). The `#if JSP_HAS_ATTR`/font guards become relevant only when dropping BAT / adding CPC text (later) (§6,§9)
  - [x] CPC test-harness (`tests/test_cpc_bg.c`) sets Mode 2 + palette before the first redraw (§11,§6)
  - [x] Background-tile-only CPC Mode 2 image rendered pixel-perfect in cap32 (`make run-cpc-bg`) (§12)
  - [x] Regression gate: ZX byte-for-byte identical (`959048ee…`) + 9 taps green; CPC Mode 2 background render green (§12)

- [x] **Phase 3 — CPC Mode 2 shift + kernels**
  - [x] Reuse `jsp_init_rottbl()` for Mode 2 (= ZX linear table) (§4) — shared C, `JSP_SHIFT_PHASES=7`
  - [x] Confirm the M2 `rottbl_msb` formula + 2-page-per-phase / `inc h` carry contract carry over (§4)
  - [x] Port the 8 `jsp_draw_*` kernels to CPC Mode 2 (near-verbatim) (§5) — `lib/cpc/jsp_draw_*.asm`
  - [x] Wire the covered-cell compositor to the Mode 2 kernels (§5) — real `lib/cpc/jsp_covered.asm` (+ real `jsp_frame.asm`, `jsp_sprite_defer.asm`)
  - [x] Verify a moving, sub-byte-shifted CPC Mode 2 sprite on emulator (§12) — `make run-cpc-sprite`, all xrot phases clean (fixed a stack/rottbl 0xBF00 overlap → SP=0x9800)
  - [x] Regression gate: ZX green + CPC Mode 2 sprite render green (§12) — ZX `959048ee…`, 9 taps, CPC bg+sprite green
  - [x] Widen CPC descriptor X to 16-bit (full 640px) + reconcile asm offsets (frame/defer) and public signatures (§3) — `jsp_xcoord_t` (16-bit X, Y stays 8-bit); verified sprites at x=100/300/500 + animated full-width bounce in cap32

- [x] **Phase 4 — CPC Mode 2 asset pipeline + shift unit test**
  - [x] Define and implement the CPC Mode 2 planar-in-byte pixel+mask asset format (§10) — Mode 2 is 1bpp-linear == the ZX `mask2` (mask,graph pairs) / `load1` (graph) format; documented in the Makefile asset rules + `tests/cpc/shift_test_mode2.c`
  - [x] Add the Mode 2 asset emitter (`gfxgen` flag or new emitter) (§10) — M2 == ZX 1bpp, so the existing `gfxgen.pl` mask2/load1 invocation IS the M2 emitter; the CPC build reuses the emitted files unchanged (no new emitter needed for M2; M0/M1 get per-mode emitters in their phases)
  - [x] Reuse the ZX sprite source art (re-convert `assets/*.png` per mode), don't hand-author CPC sprites (§10,§11) — `assets/ball.png` reused directly (M2 = same monochrome bit pattern)
  - [x] Unit-test the §8.1 shift/mask against the emitted Mode 2 bytes (§4,§10) — `tests/cpc/shift_test_mode2.c` (`make cpc-shift-test-mode2`): validates the rottbl masks (in=src>>i, carry=src<<(8-i)) and the in|carry-from-left combine against a true 16-bit shift, exhaustively (256×256×7) + over the emitted asset bytes → 463k checks PASS
  - [x] Adapt the sprite-gen Makefile targets for Mode 2 (§11) — M2 reuses `tests/test_sprite_mask2.asm`/`load1`; documented in the Makefile (`## extras`); per-mode variants for M0/M1 deferred to their phases
  - [x] Regression gate: ZX green (`959048ee`, 9 taps) + CPC Mode 2 (bg + sprite + demo build) + shift unit test green (§12)

- [x] **Phase 5 — Mode 2 full test pass**
  - [x] Keep CPC tests as the ZX tests recompiled (same layout/sprites); palette mirrors ZX colours (§11) — CPC ports in `tests/cpc/` (mode-2 setup + geometric tiles, since CPC has no ZX ROM font / no attr colour): `test_cpc_bg` (bg tiles), `test_cpc_sprite`/`_demo` (sprites, shift, 16-bit X), `test_cpc_foreground` (foreground band + pool + sprites-behind), `test_cpc_btt_redraw` (tile draw/delete/redraw)
  - [x] Build all renderable `tests/*` under `CPC_MODE2` (§11) — `make cpc-bg cpc-sprite cpc-foreground cpc-btt-redraw cpc-sprite-demo-mode2` all build; `cpc-shift-test-mode2` (host) passes
  - [x] Visually verify all under `CPC_MODE2` via cap32 headless (§11) — bg grid, masked/shifted/full-width sprites, foreground occlusion (ball split by band), and BTT delete "hole" all confirmed in cap32
  - [x] Lock Mode 2 as the reference CPC pipeline (§12) — Mode 2 is the verified baseline; M0/M1/FAST diverge only in shift table + kernels + asset encoding (their shift/mask gated by the `cpc-shift-test-mode*` harness from Phase 4)
  - [x] Regression gate: ZX green (`959048ee`, 9 taps) + CPC Mode 2 test pass green (§12)
  - **Deferred (not Mode-2 renderable; tracked for later):** `test_dtt` / `test_btt_contents` are `printf`-to-console logic dumps — no CPC text console with both ROMs off; their 80-col DTT/BTT bookkeeping is exercised indirectly by the visual tiles/sprite tests. `test_tiles_and_print` needs a CPC font (the `0x3D00` ROM-font ptrs are unused on CPC, §6/§9) — revisit when CPC text lands. Benches (`test_redraw_bench`, `bench_sp1`) stay ZX-only (JNEXT magic port, §11).

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
