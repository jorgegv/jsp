# CPC `_IMASK` Implementation Plan

Status: **complete** (2026-06-08, branch `cpc_implicit_mask`, not yet merged).
Companion to `doc/CPC-IMASK-DESIGN.md` (the evaluation/rationale). This document
is the concrete build order: every file to touch, the design decisions taken, and
the test gate per phase.

Scope: add `CPC_MODE0_IMASK` and `CPC_MODE1_IMASK`. **No** `CPC_MODE2_IMASK`
(collapses to `_MONO`). **No** `_IMASK_FAST` combo (IMASK is always a shifting
build). Work branch: `cpc_implicit_mask`.

## Outcome

All seven phases landed and verified:

- **Correctness:** the IMASK render is **pixel-identical to MASK2 over a black
  background** (AE = 0) at every xrot phase, in both Mode 0 and Mode 1 (the
  oracle — opaque pixels draw exactly as MASK2; over a coloured background they
  differ only in pen-0 regions, the intended transparency). Host LUT unit test
  PASS both modes. `make cpc-tests` green, `make zx-tests` all AE = 0 (no
  regression from the shared-header edits).
- **Memory:** masked sprites halved — M1 = ZX size, M0 = 2× ZX; +256 B LUT/build.
- **Performance:** an optimisation pass (rottbl page kept in H, LUT lookup via
  DE, graph pointer in BC, border kernels H-constant — baseline tagged
  `imask-baseline`) cut the per-byte kernel cost: mid 130→119 T (−8.5%), border
  110→85 T (−23%). At the **frame level** (rigorous 3-round interleaved,
  boot-free t(6000)−t(2000), 8-sprite scene) the optimised IMASK is **~1–3%
  faster than MASK2** — M1 54.4 s vs 56.2 s, M0 60.9 s vs 61.4 s per 4000 redraws
  — at half the sprite memory. The per-byte saving is diluted at frame level
  because the redraw is dominated by the background blit + DTT walk, not the
  sprite kernel. (An earlier *single-run* "23%" was a measurement artifact;
  cap32 wall-clock needs multi-round sampling. Full numbers + method in
  `doc/CPC-IMASK-DESIGN.md` §4.)
- **Correction to §0.2 below:** the lb/rb border kernels are **kept** (they
  handle the graph rotation carry, like LOAD1's); IMASK only drops the parallel
  *mask* shift and the 0xFF border-mask seeding. The §5/§9 notes in the design
  doc are corrected accordingly.

---

## 0. Key architectural findings (drive every decision below)

1. **`ismask2` currently couples transparency to `cs=16`.** In
   `lib/cpc/jsp_frame.asm` the per-frame precompute sets
   `ismask2 = (type_ptr == JSP_TYPE_MASK2)` and then derives `cs = ismask2?16:8`,
   `base` displacement `×(ismask2?2:1)`, `rowstride = (rows+1)*cs`. IMASK is a
   **graph-only (8 B/cell)** format that nonetheless composites with
   transparency. Since IMASK and MASK2 never coexist in one build, **in an IMASK
   build `cs` is always 8** and `ismask2` is repurposed to mean only "use the
   transparent (imask) kernel vs the opaque (load1) kernel". All the
   `×2`/`×16`/`cs=16` doublings are guarded off in IMASK builds.

2. **The lb/rb border kernels are NOT eliminated** (this corrects a claim in the
   design doc). They handle the *graph rotation carry* at sprite edges — LOAD1
   has `load1lb`/`load1rb` too. What IMASK removes vs MASK2 is the *parallel mask
   shift* (mask2 shifts both mask and graph through `jsp_rottbl`; imask shifts
   only graph and derives the mask via a LUT) and the 0xFF transparent
   border-mask seeding (borders are transparent for free because edge graph bits
   are 0 → `imask[0…]` = keep background). So IMASK needs **3 rotating kernels**
   (mid/lb/rb), each simpler than its mask2 twin, and **no** no-rotate kernel
   (IMASK is never FAST).

3. **The LUT page is addressable as an immediate.** `z80asm` accepts
   `_jsp_rottbl/256` on an extern (`jsp_frame.asm:226`), so the kernel can do
   `ld h,_jsp_imask_tbl/256` — no second source of truth for the address, no
   runtime page variable.

4. **LUT fits in the reserved rottbl block** (`0xB200–0xBFFF`, sized for M2's
   3584 B). M1 rottbl = 1536 B (ends `0xB7FF`) → LUT at `0xB800`. M0 rottbl =
   512 B (ends `0xB3FF`) → LUT at `0xB400`. Both 256-aligned, below `0xC000`
   screen. No memory-map change.

5. **`cpcgfx.pl` already emits the right graph bytes.** `cell_bytes()` builds the
   graph byte `$g` with **0 for transparent pixels** and pen bits for opaque
   ones — exactly the IMASK byte. `--imask` therefore emits the `$g` stream
   (1 B/line, like LOAD1) and only needs to (a) validate that no *opaque* pixel
   resolves to pen 0, and (b) label/comment as imask.

---

## 1. The IMASK composite (recap, for the kernel author)

Per byte: `screen = (background & imask[graph]) | graph`, where
`imask[g]` sets all plane bits of every pen-0 (transparent) pixel of `g`, and
clears the rest. The rotating kernels shift only the **graph** through
`jsp_rottbl` (same as load1), combine this column's IN with the left column's
CARRY, then look up `imask[combined]` for the mask. Full worked Mode-1 example
and T-state budget: `doc/CPC-IMASK-DESIGN.md` Appendix A.

`imask[g]` generation formula (LUT source of truth, mode-selected):
- **M1** (nibble planes): `imask[g] = (~(g | (g<<4) | (g>>4))) & 0xFF`
- **M0** (0xAA/0x55 planes): `imask[g] = ((g&0xAA)?0:0xAA) | ((g&0x55)?0:0x55)`

(Both verified by hand in the design doc; a host unit test pins them.)

---

## 2. Build order (small commits, each with a test gate)

### Phase 1 — mode plumbing + LUT formula + host test (no kernels yet)
Files:
- `include/jsp_config.h`: add `CPC_MODE0_IMASK`, `CPC_MODE1_IMASK` to the
  exactly-one-mode check (l.33-35) and the `JSP_PPB`/`JSP_SHIFT_PHASES` switch
  (l.76-94): M0_IMASK → ppb 2, phases 1; M1_IMASK → ppb 4, phases 3 (same as
  their base modes).
- `include/jsp_rottbl_formula.h`: add `CPC_MODE0_IMASK`/`CPC_MODE1_IMASK` to the
  M0/M1 `JSP_ROTTBL_IN/CARRY` guards (reuse base formulas), AND add a new
  `JSP_IMASK(g)` macro (the two formulas in §1), mode-selected.
- `lib/cpc/jsp_cpc_geom.inc`: add `IFDEF CPC_MODE0_IMASK` (PPB_SHIFT 1,
  XROT_MASK 1) and `IFDEF CPC_MODE1_IMASK` (PPB_SHIFT 2, XROT_MASK 3) blocks,
  MONO_DBL 0.
- `tests/cpc/imask_test.c` (new, host C): build the 256-entry table from
  `JSP_IMASK` and assert it matches an independent reference derived from a
  per-pixel pen-array model (mirrors `shift_test_mode*.c`).

**Gate:** `imask_test` passes for both modes (host `$(HOSTCC)`, no emulator).

### Phase 2 — LUT data + init
Files:
- `lib/jsp_data.c`: under `CPC_MODE*_IMASK`, define
  `IMASK_TBL_ADDR = ROTTBL_ADDR + JSP_SHIFT_PHASES*2*256` and
  `__at(IMASK_TBL_ADDR) uint8_t jsp_imask_tbl[256];`.
- `lib/jsp_init.c`: add `jsp_init_imask_tbl()` (fill `jsp_imask_tbl[val] =
  JSP_IMASK(val)` for 0..255) and call it from `jsp_init()` under the IMASK
  guard.
- `include/jsp.h`: `extern uint8_t jsp_imask_tbl[];` (guarded).

**Gate:** an IMASK build links the table at the expected 256-aligned address
(map check); host test already validated contents.

### Phase 3 — asset tool (`cpcgfx.pl --imask`) + generate test assets
Files:
- `tools/cpcgfx.pl`: add `--imask`. Behaviour: emit graph-only (`db $g`,
  1 B/line, like LOAD1) + 8-line trailing column pad as zero bytes (transparent)
  + the 8 transparent pre-rows. Restrict to Mode 0/1 (error otherwise). With
  `--multicolor`, force the transparent colour to pen 0 and real inks to pens
  1..N; **error** if any opaque pixel resolves to pen 0. Label/comment as imask.
- Generate `tests/test_sprite_imask_m1.asm`, `tests/test_sprite_imask_m0.asm`
  from the same PNG used by the mask2/load1 tests.

**Gate:** golden ASM diff; manually confirm transparent pixels → `$00`, opaque →
pen bits, padding present.

### Phase 4 — kernels + dispatch + frame decoupling + type tag
Files:
- `lib/cpc/jsp_draw_imask.asm`, `jsp_draw_imasklb.asm`, `jsp_draw_imaskrb.asm`
  (new): model on `jsp_draw_mask2{,lb,rb}.asm` but read 1 graph byte/line,
  shift graph only, then `ld h,_jsp_imask_tbl/256; ld l,combined; ld a,(hl)` for
  the mask; reuse `jsp_cc_store.inc` (`CC_RD16`/`CC_WR`) for the dst. Keep the
  rottbl page in a spare register across the byte loop so the per-byte LUT page
  switch doesn't cost a reload. Preserve the C-reference comment block per repo
  convention. Guard: `IF CPC_MODE0_IMASK || CPC_MODE1_IMASK`.
- `lib/cpc/jsp_draw_mask2{,lb,rb}.asm`: extend the existing
  `IF CPC_MODE*_FAST` skip-guard to also skip in IMASK builds (mask2 unused
  there; imask replaces it). `load1*` unchanged (opaque path stays).
- `lib/cpc/jsp_covered.asm`: in the non-FAST `extern` arm and at the 6 mask call
  sites (Model A: `cc_mid_mask`/`cc_lb_mask`/`cc_rb_mask`; Model B:
  `cb_mid_mask`/`cb_lb_mask`/`cb_rb_mask`) call the imask family under
  `IF CPC_MODE0_IMASK || CPC_MODE1_IMASK`, else mask2. (load1 calls unchanged.)
- `lib/cpc/jsp_frame.asm`: (a) compare `type_ptr` to the build's transparent type
  — `JSP_TYPE_IMASK` in IMASK builds, `JSP_TYPE_MASK2` otherwise; (b) guard off
  the `cs=16`, base `×2`, rowstride `×16` doublings in IMASK builds (cs always 8).
- `lib/jsp_data.c`: `uint8_t JSP_TYPE_IMASK[1] = { 8 };` (guarded).
- `include/jsp.h`: `extern uint8_t JSP_TYPE_IMASK[];` (guarded).
- `tests/cpc/test_cpc_sprite_imask.c` (new): draw a static sprite using
  `JSP_TYPE_IMASK`, set the screen mode register for M0/M1.

**Gate:** build `CPC_MODE1_IMASK` and `CPC_MODE0_IMASK` sprite tests; headless
screenshot must be **pixel-identical to the same art rendered as MASK2** (the
strongest correctness check — same image, pen 0 transparent).

### Phase 5 — C API wrappers
Files:
- `lib/jsp_sprite_c.c`: add `jsp_draw_sprite_imask` / `jsp_move_sprite_imask`
  / `jsp_move_sprite_imask_frame` (set `type_ptr = JSP_TYPE_IMASK`, defer) —
  mirror the mask2 wrappers. (Generic `jsp_draw_sprite` already works via
  `type_ptr`; wrappers are for API symmetry.)
- `include/jsp.h`: prototypes (guarded or always-declared with the extern type).

**Gate:** the Phase-4 test switches to the wrapper API and still passes.

### Phase 6 — Makefile mode matrix + regression wiring
Files (`Makefile`):
- Add `0_imask 1_imask` to `CPC_SPRITE_MODES`; add an imask host-test target.
- `m_def_{0,1}_imask = {0,1}_IMASK`; `m_src_*` = the new test; `m_mask_*` =
  the imask asset; `m_load_*` = existing load1 asset; `m_name_*` = `CPCSPR0I`/
  `CPCSPR1I`; `m_shiftdef_*` n/a (no new shift test; reuse base-mode shift test).
- Add imask asset build rules (`tests/test_sprite_imask_m{0,1}.asm` via
  `cpcgfx.pl --imask`).
- Commit `tests/refs/cpc/...` baselines (ideally the byte-identical mask2 refs).
- Hook the imask sprite test + host LUT test into `cpc-tests`.

**Gate:** `make cpc-tests` builds all configs incl. imask and all regressions
pass (AE = 0).

### Phase 7 — documentation
- `doc/CPC-IMASK-DESIGN.md`: correct the border-kernel claim (§0.2 above);
  flip status to "implemented".
- `doc/CPC-ASSETS-FORMAT.md`: add the IMASK asset format (graph-only, pen 0 =
  transparent, M0/M1).
- `doc/CPC-USAGE.md`: document the two new modes + the `_imask` API + pen-0
  reservation caveat.
- `Makefile` help text / `README` mode list; `cpcgfx.pl --help`.

**Gate:** docs match the shipped behaviour; `make` help lists the modes.

---

## 3. Decisions taken (so they are not re-litigated mid-build)

- **Kernel naming:** distinct `_jsp_draw_imask{,lb,rb}` (honest, filename matches
  symbol), with `covered.asm` dispatch made IMASK-aware via `IF` guards —
  consistent with how `_FAST` is already branched. (Rejected: reusing the
  `_jsp_draw_mask2` symbols to avoid touching `covered.asm` — too confusing.)
- **`cs` decoupling:** in IMASK builds `cs=8` always; `ismask2` selects only the
  kernel. (Rejected: a third dispatch value / new frame field — unnecessary since
  modes are mutually exclusive per build.)
- **LUT, not in-register derivation:** uniform across M0/M1, faster than the M1
  nibble trick (design doc §2 / Appendix A).
- **No `_IMASK_FAST`, no `CPC_MODE2_IMASK`:** out of scope by decision.

## 4. Risks / watch-items

- **IX corruption across the C↔ASM boundary** (CLAUDE.md): the imask kernels are
  pure asm called from asm (`covered.asm`); keep IX usage matching the mask2
  kernels they are modelled on.
- **Stack**: kernels use registers + the existing `cc_*` globals; no new large
  stack locals.
- **Opaque-pen-0 art**: the tool must hard-error, else silent holes. Documented.
- **Reference parity**: if the imask screenshot does NOT match the mask2 render,
  the bug is in the kernel/LUT, not the art — that equivalence is the oracle.
