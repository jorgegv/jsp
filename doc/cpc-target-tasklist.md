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
  - [x] Reuse `jsp_init_rottbl()` for Mode 2 (= ZX linear table) (§4)
  - [x] Confirm the M2 `rottbl_msb` formula + 2-page-per-phase / `inc h` carry contract carry over (§4)
  - [x] Port the 8 `jsp_draw_*` kernels to CPC Mode 2 (near-verbatim) (§5)
  - [x] Wire the covered-cell compositor to the Mode 2 kernels (§5)
  - [x] Verify a moving, sub-byte-shifted CPC Mode 2 sprite on emulator (§12)
  - [x] Widen CPC descriptor X to 16-bit (full 640px) + reconcile asm offsets and public signatures (§3)
  - [x] Regression gate: ZX green + CPC Mode 2 sprite render green (§12)

- [x] **Phase 4 — CPC Mode 2 asset pipeline + shift unit test**
  - [x] Define and implement the CPC Mode 2 planar-in-byte pixel+mask asset format (§10, doc/CPC-ASSETS-FORMAT.md)
  - [x] Add the Mode 2 asset emitter (`gfxgen` flag or new emitter) (§10)
  - [x] Reuse the ZX sprite source art (re-convert `assets/*.png` per mode), don't hand-author CPC sprites (§10,§11)
  - [x] Unit-test the §8.1 shift/mask against the emitted Mode 2 bytes (§4,§10)
  - [x] Adapt the sprite-gen Makefile targets for Mode 2 (§11)
  - [x] Regression gate: ZX green + CPC Mode 2 (incl. shift unit test) green (§12)

- [x] **Phase 5 — Mode 2 full test pass**
  - [x] Keep CPC tests as the ZX tests recompiled (same layout/sprites); palette mirrors ZX colours (§11)
  - [x] Build all renderable `tests/*` under `CPC_MODE2` (§11)
  - [x] Visually verify all tests under `CPC_MODE2` via the `caprice-testing` skill (cap32 headless) (§11)
  - [x] Lock Mode 2 as the reference CPC pipeline (§12)
  - [x] Regression gate: ZX green + full CPC Mode 2 test pass green (§12)

- [x] **Phase 6 — CPC Mode 1** (full 4-colour mode; MONO split out to Phase 6.1)
  - [x] Add the Mode 1 nibble-plane shift table + `jsp_init_rottbl` Mode 1 variant (§4) — M1 IN/CARRY macros in `include/jsp_rottbl_formula.h`, guard-selected; `jsp_init_rottbl` reused (3 phases)
  - [x] Define the Mode 1 `rottbl_msb` formula + table stride (3 phases, 2-page-per-phase) (§4) — same `2*xrot-2` stride/`inc h` carry as M2; X-split parametrised by `JSP_PPB_SHIFT`/`JSP_XROT_MASK` in `lib/cpc/jsp_frame.asm`
  - [x] Write the Mode 1 `jsp_draw_*` kernels (§5) — the Mode-2 `lib/cpc/jsp_draw_*` kernels are table-driven, so Mode 1 reuses them verbatim (pixel encoding lives in `jsp_rottbl`, not the kernel)
  - [x] Define + emit the Mode 1 planar (two nibble-planes) asset format (§10) — in-repo emitter `tools/cpcgfx.pl`; `tests/test_sprite_{mask2,load1}_m1.asm`
  - [x] Unit-test the §8.2 shift/mask against the emitted Mode 1 bytes (§4,§10) — `tests/cpc/shift_test_mode1.c`, `make cpc-shift-test-mode1` (PASS, incl. emitted-byte cross-check)
  - [x] Test pass under `CPC_MODE1` (§12) — `tests/cpc/test_cpc_sprite_mode1.c`, `make run-cpc-sprite-mode1`; verified in cap32 (4-colour bg both planes, masked balls, all xrot 0–3 pixel-perfect)
  - [x] Regression gate: ZX byte-for-byte (`959048ee…`) + 9 taps + CPC Mode 2 (shift test + 4 builds) + Mode 1 green (§12)

- [x] **Phase 6.1 — CPC Mode 1 MONO** (1bpp assets on a Mode-1 screen, §8/§3.1)
  - [x] Resolve the table-vs-blitter split (DECIDED: reuse the Mode-1 nibble `jsp_rottbl` + an expanding blitter; expand 1bpp→Mode-1 per covered cell into scratch, then run the existing Mode-1 middle kernels — nothing stored). Recorded in `doc/CPC-ASSETS-FORMAT.md` §3.1
  - [x] Host-test the 1bpp→Mode-1 nibble expansion + combine vs a true monochrome shift (`tests/cpc/shift_test_mode1_mono.c`, `make cpc-shift-test-mode1-mono`) — PASS (786k+ checks)
  - [x] `jsp_frame.asm`: MONO footprint width `c1 = c0 + (xrot ? 2*cols : 2*cols-1)` via `JSP_MONO_DBL` in the shared `lib/cpc/jsp_cpc_geom.inc` (also fixed a latent Mode-1 dirty-marking bug: `mark_footprint` now uses the per-mode X-split, shared with the frame)
  - [x] MONO covered-cell compositor (`lib/cpc/jsp_covered_mono.asm`, `IFDEF CPC_MODE1_MONO`; `jsp_covered.asm` now `IFNDEF CPC_MODE1_MONO`): screen-col→(1bpp src col, nibble) mapping, expand this+left nibbles to scratch, always call the middle kernel
  - [x] MONO reuses the Mode-2 1bpp assets unchanged for BOTH sprites AND tiles (`test_sprite_mask2.asm`, 1bpp tiles): the blit expands `nibble(col&1)` of each 1bpp tile (`mono_tile_expand`, called from `jsp_redraw` bg path + the covered seed), so a uniform fill tiles the 8-px pattern seamlessly — full memory saving on both
  - [x] Test pass under `CPC_MODE1_MONO` (`tests/cpc/test_cpc_sprite_mode1_mono.c`, `make run-cpc-sprite-mode1-mono`); verified in cap32 (masked balls over 4-colour bg, all xrot 0–3 pixel-clean)
  - [x] Regression gate: ZX byte-for-byte (`959048ee…`) + 9 taps + CPC Mode 2 + Mode 1 + Mode 1 MONO green (§12)

- [x] **Phase 7 — CPC Mode 0 (+ cell-model decision)**
  - [x] Cell-model decision: **DECIDED Model A (byte-cell)** for the whole port — context changed (M2+M1 already verified in A; no CPC profiler to measure B's claimed win; B would mean redoing verified Mode 1 + the 20-col DTT wrinkle). Recorded in `CPC-TILE-SIZE-ANALYSIS.md`; §2/§9 already match (no prototype-both-ways needed)
  - [x] Pick the cell model, record the outcome in CPC-TILE-SIZE-ANALYSIS.md, reconcile §2/§9 + Mode 1 (Model A → Mode 1 unchanged)
  - [x] Add the Mode 0 odd/even interleave shift table (single phase) (§4) — `JSP_ROTTBL_IN/CARRY` Mode-0 macros in `jsp_rottbl_formula.h` (`in=(v&0xAA)>>1`, `carry=(v&0x55)<<1`); `jsp_init_rottbl` reused (1 phase, 512B)
  - [x] Define the Mode 0 `rottbl_msb` / single-phase table addressing (xrot 0/1) (§4) — same `2*xrot-2` stride; xrot 0 → NR, xrot 1 → base page; X-split `JSP_PPB_SHIFT=1`/`XROT_MASK=1`
  - [x] Write the Mode 0 `jsp_draw_*` kernels (§5) — table-driven `lib/cpc/jsp_draw_*` reused verbatim (same as M1/M2)
  - [x] Define + emit the Mode 0 interleaved asset format (§10) — `tools/cpcgfx.pl --mode 0` (4 cells/8-px col, 2 px/cell); `tests/test_sprite_{mask2,load1}_m0.asm`
  - [x] Unit-test the §8.3 shift/mask against the emitted Mode 0 bytes (§4,§10) — `tests/cpc/shift_test_mode0.c`, `make cpc-shift-test-mode0` (PASS, incl. emitted-byte cross-check)
  - [x] Test pass under `CPC_MODE0` (§12) — `tests/cpc/test_cpc_sprite_mode0.c`, `make run-cpc-sprite-mode0`; verified in cap32 (masked balls over grid, xrot 0 + 1 clean)
  - [x] Regression gate: ZX byte-for-byte (`959048ee…`) + 9 taps + CPC Mode 2 + Mode 1/MONO + Mode 0 green (§12)

- [x] **Phase 8 — FAST variants**
  - [x] Implement `CPC_MODE0_FAST` (force shift=0, `nr` kernel only, no shift table) (§3,§8) — config/geom guards (`JSP_XROT_MASK=0`, `JSP_SHIFT_PHASES=0`); the lb/middle kernels already redirect the aligned case to `nr`, so no new kernels
  - [x] Implement `CPC_MODE1_FAST` (force shift=0, `nr` kernel only, no shift table) (§3,§8) — same mechanism as M0 FAST, reusing the Mode-1 nibble assets
  - [x] Implement `CPC_MODE2_FAST` (8-px aligned, `nr` only; reclaims the most RAM — largest rottbl) (§3,§8) — added at user request; same mechanism, reusing the ZX 1bpp assets
  - [x] Test pass under all three FAST modes (§12) — `make run-cpc-sprite-mode{2,0,1}-fast`; verified in cap32 (masked balls byte-aligned over the per-mode grids, all clean)
  - [x] Regression gate: ZX byte-for-byte (`959048ee…`) + 9 taps + all CPC modes incl. FAST green (§12)

- [x] **Phase 9 — Toolchain matrix & docs**
  - [x] Parameterise the Makefile by `JSP_TARGET` and `JSP_CPC_MODE` with a build-matrix target (§11) — `JSP_CPC_MODE` knob + `cpc-matrix` (build all) + `run-cpc-matrix` (build+screenshot all)
  - [x] Build `+cpc -create-app -subtype=dsk` and add a `make run` branch invoking the `caprice-testing` skill (§11,risk7) — `run` now dispatches on `JSP_TARGET`: `make run JSP_TARGET=cpc JSP_CPC_MODE=<m>` builds+shots that config in cap32
  - [x] Adapt `tools/cap32-shot.sh` defaults / wire it to the JSP test build outputs (§11) — already auto-detects the single `.dsk` + derives the AMSDOS run-name; wired into every `run-cpc-*` target
  - [x] Document the CPC profiling gap (visual via cap32; no T-state heatmap yet) (§11,risk5) — noted in `doc/ENGINE.md` (CPC section) + `README.md`
  - [x] Update `doc/ENGINE.md` with CPC memory maps, screen layout and the colour divergence (§6,§9) — added "AMSTRAD CPC TARGET" section (screen layout, colour asterisk, memory map, FAST, build/verify)
  - [x] Update `README.md`; add `doc/CPC-MODES.md` if per-mode detail outgrows the plan (§12) — README CPC section added; `CPC-MODES.md` NOT needed (per-mode detail fits `CPC-TARGET-PLAN.md` + `CPC-ASSETS-FORMAT.md`)
  - [x] Regression gate: full matrix green (ZX + all CPC modes) (§12)

- [ ] **Cross-cutting / sign-off**
  - [ ] Confirm with user that baked-in pixel colour (no dynamic recolour) is acceptable for first CPC milestone (§6,risk4)
  - [ ] Confirm the Mode 2 memory budget (tables + rottbl + program) fits below `0xC000` (§9,risk6)
  - [ ] Measure the 2000-cell / 250-group redraw cost early vs the ZX 768/96 baseline (§13 risk8)
  - [ ] Definition-of-done: all 8 configs (incl. `CPC_MODE2_FAST`) run pixel-smooth on emulator, ZX baseline unchanged, shift unit tests green (§14)
