# JSP-CPC Target — Design & Implementation Plan

**Status:** Design — not yet started.
**Date:** 2026-05-31
**Goal:** Add Amstrad CPC support to JSP with pixel-perfect sprite positioning
in Mode 0 (4 bpp), Mode 1 (2 bpp) and Mode 2 (1 bpp), keeping JSP's high-level
architecture identical to the ZX version. Only the thin low-level layer (shift
tables/kernels, pixel encoding, screen addressing, mask/composite) is swapped.

**Required reading first:** `doc/refs/CPC-SPRITE-ENGINE-ANALYSIS.md` (the
strategic context and the per-mode shift mechanics, §4, §8, §11.1) and
`doc/ENGINE.md` (the ZX engine this plan ports).

---

## 1. Scope and guiding principle

The decisive architectural point (analysis §11.1): **the CPC port keeps JSP's
entire high-level engine unchanged and swaps only the platform layer.** This
plan is organised around that seam — first making the seam explicit in the
existing ZX code, then filling in the CPC side of it per mode.

### 1.1 Reused verbatim (the high-level engine — do NOT redesign)

- Deferred recomposite model + dirty-cell tracking (DTT walk).
- The four tables BTT / DTT / FTT / (BAT — see §6) and the cell-grid model.
- Sprite registry, `jsp_redraw_begin()` per-frame precompute
  (`jsp_frame_sprites[]`), and the covered-cell compositor *flow*
  (seed scratch from BTT → composite covering sprites in z-order → single store).
- The public API in `include/jsp.h` (sprite descriptor, draw/move/park, pool,
  tiles, print, clip).
- The footprint = `(rows+1) × (cols+1)` sub-cell-shift convention.

### 1.2 Swapped per target/mode (the platform layer — this plan's real work)

| Platform-layer concern | ZX implementation (today) | CPC change |
|---|---|---|
| Cell geometry / grid dims | 32×24 cells, cell = 8 bytes | §2 |
| Coordinate → (byte-col, shift) | `xpos>>3`, `xpos&7` | §3 |
| Shift tables (`jsp_rottbl`) | 1bpp linear, 7 phases | §4 |
| Composite kernels (`sp1_draw_*`) | ZX 1bpp mask2/load1 + nr/lb/rb | §5 |
| Colour / attributes (BAT) | ZX attribute RAM @ 0x5800 | §6 |
| Screen addressing | `asm_zx_cxy2saddr`, `rd_rowtab`, 0x4000/0x5800 | §7 |
| Compile guards | none (single ZX target) | §8 |
| Data block placement | `__at` 0xE840-0xFFFF / slot2 | §9 |
| Asset byte format | gfxgen ZX mask2/load1 | §10 |
| Toolchain / Makefile / emulator | `zcc +zx`, FUSE/JNEXT | §11 |

---

## 2. Cell model and grid geometry — the foundational decision

This is the single decision everything else depends on, so it is resolved first.

**ZX today:** a cell is 8×8 px. Two different byte counts must not be conflated:
- the **screen/scratch cell is 8 bytes** (1 byte/row) — the 8-byte scratch
  `cc_scratch` (`lib/jsp_covered.asm:381`, `ds 8`), the `ldi×8` seed copy, the
  8-iteration blit in `lib/jsp_screen.asm`, BTT entries treated as 8-byte tiles;
- the **source asset cell is 8 *or* 16 bytes**: `load1` = 8 (graph only),
  `mask2` = 16 ((mask,graph) byte pairs). `cs` = 8/16 and the rowstride math
  (`lib/jsp_frame.asm:212-227`) multiply by that source `cs`, *not* by 8.

The grid is fixed 32×24 = 768 cells.

**CPC framebuffer:** 80 bytes/line × 200 lines = 16 KB at `0xC000-0xFFFF`, in
*all three modes*. The mode only changes how many pixels a byte holds
(2/4/8 for M0/M1/M2). So the byte grid is always 80 columns wide.

**Decision — keep "cell = 8 lines × 1 byte" (8 bytes) for every CPC mode.**

- Preserves every **screen/scratch** 8-byte invariant above → the covered-cell
  compositor, the scratch, the seed copy, the BTT-as-8-byte-tile model carry
  over unchanged.
- The **source `mask2` cell stays 16 bytes** (mask+graph), `load1` 8 bytes, in
  every CPC mode — but for M0/M1 those bytes are now *planar-in-byte* pixels and
  the mask byte is planar too (§5, §10). `cs` / rowstride math is unchanged; only
  the *meaning* of the bytes changes per mode.
- Grid becomes **80 columns × 25 rows = 2000 cells** in every mode.
- A cell therefore spans a *mode-dependent pixel width*: M0 = 2 px, M1 = 4 px,
  M2 = 8 px wide (always 8 px tall). Sprite `cols` is a count of **bytes**, not
  pixels — exactly as ZX `cols` is already a byte count (8 px) that happens to
  equal pixel-cells there.

**Rejected alternative:** "cell = 8×8 *pixels*, variable byte width"
(M0 = 4 B, M1 = 2 B, M2 = 1 B wide). This keeps a 32-ish-column grid but makes
the per-cell byte count mode-dependent, breaking *every* 8-byte invariant and
forcing a different scratch/blit/rowstride per mode. The whole point of §11.1 is
to keep the high-level engine untouched; an 8-byte cell does that. Rejected.

**Consequences to carry through the plan:**

- **Cell-indexed** tables scale from 768 → 2000 cells (§9 memory budget):
  BTT 4000 B, DTT 250 B, FTT 250 B, BAT dropped (§6). The **registry-sized**
  scratch structures do *not* scale — `jsp_frame_sprites[JSP_SPRITE_REGISTRY_SIZE]`
  and `cc_row_active` (`ds 32` = 16 pointers, `lib/jsp_covered.asm:388`) stay
  sized by the sprite registry, not the cell count; do not resize them.
- The `g`/group loop in `lib/jsp_redraw.asm` walks `2000/8 = 250` groups, not 96.
- The DTT/FTT bit-index math (8 cells/byte) is unchanged; only the totals change.
- **The non-power-of-two column walk is the trickiest single change.** ZX uses
  `row = g >> 2` (4 groups/row = 32 cols ÷ 8) and `col = cell & 31`. On CPC there
  are **10 groups/row** (80 ÷ 8); `g / 10` and `g % 10` are *not* free shifts and
  `cell & 31` is meaningless for cols 0..79. **Decision:** do not divide per cell
  — carry an explicit `(row, col0)` pair advanced once per group:
  `col0 += 8; if (col0 == 80) { col0 = 0; row++; }`. The per-bit column is
  `col0 + bit`. This replaces the ZX power-of-two extraction entirely.
- `rd_rowtab` grows to 25 rows (§7).
- The precompute (`lib/jsp_frame.asm:115-126`) masks `r0`/`c0` with `& 0x1F`
  (caps at 31) — **wrong for CPC** (cols 0..79, rows 0..24). Drop/raise those
  masks. The derived single-byte fields `r1 = r0+rows`, `c1 = c0+cols` and the
  8-bit `rd_is_covered` / `cc_sweep` row/col compares already hold 0..79 in a
  byte, so they need no width change — only the `& 0x1F` truncation must go.

---

## 3. Coordinate model — real pixels in, byte-col + shift out

**ZX today:** `xpos`/`ypos` are 8-bit cell-pixel coordinates; `c0 = xpos>>3`,
`xrot = xpos & 7`, `r0 = ypos>>3`, `yrot = ypos & 7` (`lib/jsp_frame.asm`).
8 px/byte and 8 px/cell coincide, so one shift does both.

**CPC:** the task requires "coordinates can be real (1-pixel) in all modes; JSP
discards unused bits if needed." Two facts force a descriptor change:

1. **Horizontal range exceeds 8 bits.** Mode 2 is 640 px wide, Mode 1 is 320,
   Mode 0 is 160. `xpos` as a single `uint8_t` cannot address a Mode-2 screen.
2. **px/byte ≠ px/cell.** Splitting X is now `byte_col = x / ppb`,
   `shift = x % ppb` with `ppb` = pixels-per-byte = 2/4/8 (M0/M1/M2); the cell
   column is the byte column (cell = 1 byte wide).

**Decision:** widen the descriptor's X (and keep Y 8-bit; 200 lines fits, but
see note) to 16-bit for CPC builds, and compute the split per mode:

```
byte_col (cell col) = x_pixels >> log2(ppb)     ; ppb = 2/4/8  -> shift by 1/2/3
shift   (phase)     = x_pixels &  (ppb-1)        ; 0..ppb-1
```

- M0: ppb=2 → 1 shift phase (offset 0/1).  M1: ppb=4 → 3 phases (1..3).
  M2: ppb=8 → 7 phases (1..7), identical to ZX.
- **FAST modes** (`CPC_MODE0_FAST`, `CPC_MODE1_FAST`): discard the sub-byte bits
  entirely (`shift` forced to 0) → byte-aligned, no shift kernel, fast path.
  `CPC_MODE0_FAST` = 2-px positioning, `CPC_MODE1_FAST` = 4-px positioning.
- Y is the scan-line directly (1-px vertical free in every mode, analysis §4);
  `r0 = y >> 3`, `yrot = y & 7` is unchanged (8 lines/cell) — but the `& 0x1F`
  cap on `r0`/`c0` in `lib/jsp_frame.asm` must be widened (see §2 consequences).

**Descriptor impact (`struct jsp_sprite_s`):** `xpos` (and possibly `ypos`) must
become 16-bit on CPC. This ripples into `jsp_frame.asm` (the split *and* the
`& 0x1F` col/row masks, §2), the deferred draw/move (`lib/jsp_sprite_c.c`,
`lib/jsp_sprite_defer.asm`) and every test that pokes `xpos`/`ypos`. The derived
`r1`/`c1` and the covered-cell row/col compares stay 8-bit (0..79 fits a byte).
Two options to weigh during Phase 1:
- (a) `#if` the field width per target (smaller, but two descriptor layouts);
- (b) always 16-bit X/Y (uniform layout, +2 bytes/sprite on ZX).
Recommend (a) guarded by `JSP_TARGET_*` to avoid a ZX regression in size/speed.

---

## 4. Shift tables — `jsp_rottbl`, per mode

`jsp_rottbl` (`lib/jsp_data.c`, built by `jsp_init_rottbl()` in
`lib/jsp_init.c`) is a set of 256-aligned tables: for shift `i` and source byte
`val`, two halves give the **in-byte** part and the **carry/spill** part of `val`
shifted right by `i` bits in a 16-bit window. `jsp_current_rottbl_msb` selects
the active table by high byte; the kernels do `inc h` to reach the carry half.

The plan keeps this **two-half (in-byte / carry) table structure** for every
mode so the kernels stay structurally identical. Note that, per mode, **two
things change together**: the table *contents/phase count* **and the addressing
stride into the table** — the ZX `rottbl_msb = (rottbl>>8) + 2*xrot - 2`
(`lib/jsp_frame.asm:182-186`) and the kernel's `inc h`-for-carry-half
(`lib/sp1_draw_mask2.asm:66-67`) both assume **each phase occupies 2 aligned
256-byte pages (in-byte page, carry page), phases contiguous**. That contract is
generalised, not assumed, per mode:

| Mode | phases | xrot range | layout | `rottbl_msb` (in-byte page) | carry page |
|---|---|---|---|---|---|
| M2 (=ZX) | 7 | 1..7 | 7×(256 in + 256 carry) | `(rottbl>>8) + 2*xrot - 2` | `+1` (`inc h`) |
| M1 | 3 | 1..3 | 3×(256 in + 256 carry) | `(rottbl>>8) + 2*xrot - 2` | `+1` (`inc h`) |
| M0 | 1 | 1 | 1×(256 in + 256 carry) | `(rottbl>>8)` (single phase) | `+1` (`inc h`) |
| FAST | 0 | n/a | no table | n/a (`nr` kernel only) | n/a |

So the **same `2*xrot-2` stride and `inc h` carry contract are kept** for M1/M2
(both use 2-page-per-phase layout); M0 has a single phase so `xrot` is 0/1 and
the table base is used directly (xrot=0 → aligned cell, no shift). The kernels
need no structural change — only the table is shorter. The `xrot`→phase mapping
is the §3 split (`shift = x % ppb`).

- **Mode 2 (1 bpp linear):** ZX table ports **verbatim** (analysis §8.1).
  7 phases, `in = src>>i`, `carry = src<<(8-i)`. `jsp_init_rottbl()` is reused
  as-is. This is why Mode 2 is the first target.
- **Mode 1 (two nibble-planes):** 3 phases. The 1-px step is
  `in = (src & 0xEE) >> 1`, `carry = (src & 0x11) << 3` (analysis §8.2/App.A);
  2- and 3-px phases compose it. Generate a 256-entry in/carry table per phase
  (`jsp_init_rottbl()` gets a Mode-1 variant under guard).
- **Mode 0 (odd/even interleave):** 1 phase. `in = (src & 0xAA) >> 1`,
  `carry = (src & 0x55) << 1` (analysis §8.3/App.A).
- **FAST / aligned:** no table (shift forced 0); kernels use the `nr`
  (no-rotate) path only.

**Table sizing per mode** (256 B × 2 halves × phases): M2 = 7×512 = 3584 B (as
ZX), M1 = 3×512 = 1536 B, M0 = 1×512 = 512 B. Mode selection picks the size; the
data-block layout (§9) must budget the largest *enabled* table.

**Caveat (analysis §8 banner):** these masks are derived but **must be
unit-tested against the asset converter's exact byte format** (§10) before
relying on them. This is a first-class task, not an afterthought.

---

## 5. Composite kernels — `sp1_draw_*`, per mode

Today there are 8 kernels: `mask2` / `load1`, each with middle + `nr` / `lb` /
`rb` border variants (`lib/sp1_draw_*.asm`). They:
- read source bytes, index `jsp_rottbl` via `jsp_current_rottbl_msb` to shift,
- combine the in-byte part with the carry from the adjacent column
  (`graph` / `graph_left`),
- composite into `cc_scratch` (addressed **absolutely**, 13T vs 19T — they
  hard-reference the `cc_scratch` symbol), with `mask2` doing
  `screen = (bg & mask) | pix` and `load1` overwriting.

**CPC plan:** provide a per-mode kernel set behind the same symbol names so the
covered-cell compositor (`lib/jsp_covered.asm`) calls them unchanged.

- **Mode 2:** the ZX kernels are 1bpp-linear and port **near-verbatim** — the
  rotate-through-carry is identical. Smallest delta; first target.
- **Mode 1 / Mode 0:** new kernels using the §4 mask-ops. The in-byte/carry
  split and the `graph`/`graph_left` plumbing are the *same shape*; only the
  shift/mask arithmetic differs. The `mask2` composite stays
  `screen = (screen & shifted_mask) | shifted_pixels` (analysis §8.4) — the mask
  is shifted with the **identical** per-mode op as the pixels.
- **`nr` / `lb` / `rb`:** still needed (no-rotate aligned cell, left edge with no
  left neighbour, right edge spill). FAST modes use only `nr`.
- **Absolute `cc_scratch` addressing** is retained (the scratch is still 8 bytes
  at a fixed symbol).

Kernel count: 8 per shifting mode (M0, M1, M2) + the shared `nr` for FAST. These
are the bulk of the new assembly.

### 5.1 Flicker / tearing / ISR model (analysis §13 — DECIDED, inherited)

The analysis §13 makes a load-bearing, *already-decided* call that this plan
inherits rather than re-opens: **direct-to-screen, no double buffer; some
tearing accepted; no flicker.** JSP already satisfies this for free — its
single-pass redraw writes **each cell exactly once** to its final
`background+sprites` content (`doc/ENGINE.md`; one store per cell in
`jsp_redraw.asm` / the `cc_draw` blit in `jsp_covered.asm`), so there is no
erase→redraw gap and therefore no flicker, with or without a back buffer. The
CPC port keeps this property unchanged — **do not add a CPC double buffer.**

One CPC-specific obligation: if a timer/audio ISR (e.g. an Arkos player) runs
during a blit, it **must be register-clean** (save/restore IX/IY/AF/BC/DE/HL +
any shadow regs it uses), because the blitter and the ISR share video RAM timing
but no mutable engine state. This mirrors the analysis's `cpc_fast_isr` note; it
is an integration constraint for the consuming program, recorded here so the
JSP-CPC build does not assume an interrupt-free main loop.

---

## 6. Colour / attributes — the biggest semantic divergence

**ZX:** colour lives in separate attribute RAM (`0x5800`, one byte per 8×8
cell). JSP mirrors it in the **BAT** and repaints it per dirty cell; sprites
carry `color`/`color_mask` merged into the attribute in
`lib/jsp_covered.asm` (`cc_after_draw`) and `lib/jsp_color.c`.

**CPC:** **there is no attribute RAM.** Colour is encoded in the pixel bits
themselves (palette index per pixel, planar-in-byte). Therefore:

- The **BAT table, the BAT paint in the redraw paths, `jsp_apply_sprite_color`,
  and the `color`/`color_mask` per-cell merge are ZX-specific** and have no CPC
  equivalent in their current form.
- **Phase-1 CPC decision:** drop BAT/attribute entirely. Colour comes baked into
  the sprite/tile pixel data (the asset converter emits coloured pixels per
  mode). `jsp_sprite_set_color()` / `jsp_apply_sprite_color()` become no-ops (or
  compile out) on CPC; the redraw paths skip the attribute store
  (`0x5800` writes in `jsp_redraw.asm`/`jsp_covered.asm` are guarded out).
- **Per-mode nuance:** M0 (16) and M1 (4) carry a palette index *per pixel*, so
  "colour baked into pixels" is real. **M2 is 1 bpp = monochrome-per-screen**
  (ink/paper from palette registers, no per-pixel colour choice) — exactly like
  ZX-without-attributes. For M2 the "bake colour into pixels" step is a no-op:
  there is simply nothing per-pixel to bake, and dropping BAT just removes the
  attribute write.
- **Deferred (later phase, optional):** a cpctelera-style runtime *colorize*
  (per-pixel INK remap) if dynamic recolouring is ever needed. Out of initial
  scope; note it so the API shape leaves room.

This removes ~768→0 bytes of BAT (CPC) and simplifies the per-cell path, but it
is the one place where "architecture unchanged" has an honest asterisk: the
*colour* sub-system genuinely differs, because the hardware does. Call it out
plainly in `doc/ENGINE.md` when the CPC notes are added.

---

## 7. Screen addressing

**ZX today:**
- `lib/jsp_screen.asm` calls z88dk `asm_zx_cxy2saddr` / `asm_zx_cxy2aaddr`
  (link-resolved from the `+zx` target) and blits 8 rows with the
  `ldi; dec de; inc d` idiom: within one character row the 8 pixel lines are
  exactly `+0x100` apart, so after the `ldi` (which did `inc de`) it does
  `dec de; inc d` to land on the next line's same column. This idiom *only* works
  because the within-cell line step is exactly +256.
- `lib/jsp_redraw.asm` has `rd_rowtab` (24 entries, the ZX thirds layout) and
  hard-codes `0x4000` (pixels) and `0x5800` (attrs).

**CPC standard CRTC layout:** scan-line `y` address =
`0xC000 + (y & 7) * 0x800 + (y >> 3) * 80`. So for one 8-line character cell at
`(row, col)`:
- cell base (line 0) = `0xC000 + row*80 + col` (note `row*80`, not a thirds
  table — but a 25-entry `rd_rowtab` of precomputed `0xC000 + row*80` is the
  natural equivalent and keeps the redraw loop's "row-constant base" trick).
- the 8 pixel lines step by **`+0x800`** (not `+0x100` / `inc d`).

**CPC plan:**
- New `jsp_draw_screen_tile` (CPC) blitting 8 bytes at `base, base+0x800, …,
  base+0x3800`. This is **not** a constant swap of `inc d`→`add 0x800`: the ZX
  `ldi; dec de; inc d` idiom relied on the +256 step. The CPC inner loop is a
  genuinely different idiom — e.g. keep the line base in a 16-bit reg, `ld`/store
  the byte, `add hl, 0x800` for the next line (no `ldi` line-step trick).
- New `rd_rowtab` = 25 entries `0xC000 + row*80`; cell address = `rowbase + col`.
- Drop the `0x5800` attribute stores (§6).
- Column extraction is the explicit `(row, col0)` running-counter scheme decided
  in §2 (no `cell & 31`, no `g >> 2`): the group loop advances `col0 += 8` and
  wraps `row` at `col0 == 80`. The redraw group/column walk in `jsp_redraw.asm`
  must be re-derived around this — the single most error-prone piece of new asm
  (risk 2).

---

## 8. Compile guards / mode configuration

Exactly one target+mode is selected at compile time. Introduce a single config
header (e.g. `include/jsp_config.h`) that, from the guard, defines every
mode-dependent constant the rest of the code reads:

| Guard | ppb | shift phases | grid (cols×rows) | cell px (w×h) | shift kernels | colour |
|---|---|---|---|---|---|---|
| (ZX, default/no guard) | 8 | 7 | 32×24 | 8×8 | ZX 1bpp | BAT attr |
| `CPC_MODE0` | 2 | 1 | 80×25 | 2×8 | M0 interleave | per-pixel (16) |
| `CPC_MODE1` | 4 | 3 | 80×25 | 4×8 | M1 nibble | per-pixel (4) |
| `CPC_MODE2` | 8 | 7 | 80×25 | 8×8 | M2 linear (=ZX) | mono/screen (2) |
| `CPC_MODE1_MONO` | 4 | 3 | 80×25 | 4×8 | M1 nibble | per-pixel (1bpp assets) |
| `CPC_MODE0_FAST` | 2 | 0 (aligned) | 80×25 | 2×8 | none (`nr`) | per-pixel (16) |
| `CPC_MODE1_FAST` | 4 | 0 (aligned) | 80×25 | 4×8 | none (`nr`) | per-pixel (4) |

- A `JSP_TARGET_ZX` / `JSP_TARGET_CPC` umbrella guard gates the platform layer
  (screen addr, colour, descriptor width); the `CPC_MODE*` guard refines the
  pixel encoding/shift within CPC.
- **`CPC_MODE1_MONO`:** 1-bpp (monochrome) assets/tiles rendered on a Mode-1
  screen for memory savings, still 1-px positioned. Open sub-decision (Phase 6):
  treat the mono source as Mode-1 ink-0/1 and reuse the Mode-1 nibble shift, or
  carry a true 1bpp shift (Mode-2 style) and expand to Mode-1 at blit. Resolve
  when the Mode-1 path exists; the analysis does not pin it down.
- Add a compile-time guard that **errors if zero or more than one** mode is
  defined (mutually-exclusive selection), to fail fast.

---

## 9. Data-block placement and memory budget

**ZX:** five tables packed at the top of RAM (`__at` in `lib/jsp_data.c`),
selectable slot2/slot3.

**CPC:** screen occupies `0xC000-0xFFFF`. JSP tables must sit **below** the
screen. With the 2000-cell grid (§2):

| Table | ZX (768 cells) | CPC (2000 cells) |
|---|---|---|
| BTT (ptr/cell) | 1536 B | **4000 B** |
| DTT (bit/cell) | 96 B | **250 B** |
| FTT (bit/cell) | 96 B | **250 B** |
| BAT (byte/cell) | 768 B | **0** (dropped, §6) |
| rottbl | 3584 B | M0 512 / M1 1536 / M2 3584 B |

- The per-frame scratch structures are **registry-sized, not cell-sized**, so
  they do *not* grow with the 2000-cell grid: `jsp_frame_sprites[]`
  (`JSP_SPRITE_REGISTRY_SIZE` × 16 B) and `cc_row_active` (`ds 32`). Leave them
  as-is; only the cell-indexed tables above scale.
- rottbl must stay 256-aligned (`jsp_current_rottbl_msb` derives from its high
  byte) — unchanged constraint.
- New CPC `__at` addresses in `lib/jsp_data.c` under `JSP_TARGET_CPC`, sized by
  the enabled mode's rottbl. Total CPC block ≈ 4.5–8 KB depending on mode; place
  it ending just below `0xC000` (or lower to leave a contiguous program/free
  area, mirroring the ZX layout doc in `doc/ENGINE.md`).
- CPC firmware/stack/restart-vector reserved areas (low RAM) must be respected;
  pick a placement that avoids `0x0000-0x003F`, firmware jumpblocks and the
  default stack. Document the chosen CPC memory map alongside the ZX maps in
  `doc/ENGINE.md`.

---

## 10. Asset format and generation

**ZX:** `gfxgen.pl` (external `../zxtools/`) emits ZX 1bpp `mask2` (interleaved
`(mask,graph)` byte pairs) / `load1` (graph only), columns-major with extra
top/bottom blank rows for safe sub-cell Y positioning (seen in
`tests/test_sprite_mask2.asm`). The covered-cell compositor's `base + pdc*
rowstride + i*cs` math assumes this **columns-major, 8-bytes/cell** layout.

**CPC plan:**
- The asset converter must emit **per-mode planar-in-byte** pixel (and, for
  mask2, mask) bytes: M0 odd/even interleave, M1 two nibble-planes, M2 linear
  (analysis §4). Same columns-major, 8-lines/cell, extra top/bottom-row
  convention so the rowstride math is unchanged.
- JSP-CPC **defines** the byte format; the converter follows it (analysis §13).
  Either extend `gfxgen.pl` with `--target cpc --mode {0,1,2}` or add a CPC
  emitter. Whichever, **the §4/§8 shift masks must be unit-tested against the
  emitted bytes** before the kernels are trusted (this is the cross-check the
  analysis flags twice).
- `CPC_MODE1_MONO` assets are 1bpp source; emitter packs them per the MONO
  decision in §8.
- The Makefile sprite-gen targets (`tests/test_sprite_mask2.asm` etc.) gain
  per-mode variants.

---

## 11. Toolchain, Makefile, tests, emulation

- **Compiler target:** `zcc +cpc -compiler=sdcc` instead of `+zx`. The
  `asm_zx_*` screen helpers are `+zx`-only; the CPC build uses the new CPC
  screen code (§7), so the link no longer needs them. JSP writes its **own** CPC
  kernels (§4/§5) — it does **not** translate or link cpctelera.
- **Output format:** `zcc +cpc -compiler=sdcc -create-app -subtype=dsk` emits a
  cap32-loadable **`.dsk`** (AMSDOS binary; the catalog entry has an *empty*
  extension, so it launches with `RUN"NAME.` — trailing dot). `-subtype=none`
  gives a tape/`.cpc`. This resolves the prior `-create-app` unknown. Artifact
  naming becomes target/mode-specific.
- **Makefile:** parameterise by `JSP_TARGET` (`zx`|`cpc`) and `JSP_CPC_MODE`
  (`0`|`1`|`2`|`1_mono`|`0_fast`|`1_fast`). `ZCC`, `CFLAGS` (`-D` the mode guard),
  data-block `__at`/`-zorg` selection, and the run/emulator target all switch on
  these. Keep the existing self-documenting `make` help
  (`doc`/`semantic-makefile` convention) and the per-test pattern rules; add a
  build-matrix target that loops the modes.
- **Emulator / visual verification — Caprice32, via the `caprice-testing`
  skill.** The CPC testing path is the **`caprice-testing` skill**
  (`.claude/skills/caprice-testing/`) adapted into this project from the RAGE1
  port, with its `tools/cap32-shot.sh` driver: it builds `+cpc`, runs the `.dsk`
  headless in `cap32` inside a dedicated Xvfb (the live session is Wayland, where
  root grabs come back black), and captures a screen PNG (`import -window root`
  + cap32's F3 dump). This is the CPC analogue of the ZX `jnext-emulation`
  skill. `make run` branches on `JSP_TARGET` to invoke it. Capture analysis uses
  ImageMagick (`mean`=0 → black/failed; histogram → dominant colours); the CPC
  mode-1 boot banner (yellow-on-blue "Ready") means the program did **not** run.
- **Profiling gap (acknowledged, not hidden):** the JNEXT magic-port / T-state
  heatmap (`reference_jnext_screenshot`, the `bench`/`profile` targets) is
  ZX-only. cap32 gives **visual** verification but **no headless T-state
  profiler**; CPC performance is eyeballed / wall-clock-timed until a CPC
  profiling path exists (risk 5). Do not assume profiling parity.
- **Tests:** every `tests/*.c` must build per CPC mode and be visually checked via
  the `caprice-testing` skill. Each CPC test harness must **set the screen mode
  and program the palette before the first `jsp_redraw`** (the firmware boots in
  Mode 1; colour is in the pixels via the gate-array palette, §6) — otherwise the
  screenshot's colours are uninterpretable. Keep that setup in the test
  harness/`main`, not in the library. The AMSDOS `-o` name is ≤8 chars/uppercase
  and is the `RUN"NAME.` launch target, so the ZX test names are re-mapped to
  short disk names at build time. The benches (`test_redraw_bench`, `bench_sp1`)
  lean on the JNEXT magic port and are ZX-only until a CPC profiling path lands.

---

## 12. Phased implementation order

Ordering follows analysis §12 (Mode 2 → Mode 1 → Mode 0), prefixed by a
refactor phase that makes the ZX/CPC seam explicit **without changing ZX
behaviour** (the regression guard), and a config phase.

**Phase 0 — Seam & ZX regression baseline.**
Introduce `JSP_TARGET_ZX`/`JSP_TARGET_CPC` umbrella guards around every
platform-layer item in §1.2 *in the existing ZX code*, behind the ZX default, so
the ZX build/tests are byte-for-byte unchanged. This isolates exactly what CPC
must replace and gives a green baseline to regress against.

**Phase 1 — Config header & geometry.**
`include/jsp_config.h`: per-guard `ppb`, shift phases, grid dims (cols/rows/cell
count), cell pixel size, rottbl size, colour mode. Mutually-exclusive-mode
compile error. Decide descriptor X/Y width strategy (§3) and apply under guard.
Replace hard-coded `768`/`32`/`24`/`96` literals across the engine with the
config symbols (ZX values unchanged).

**Phase 2 — CPC Mode 2 screen layer.**
CPC screen addressing (§7): new `jsp_draw_screen_tile` (8 lines × `+0x800`),
25-entry `rd_rowtab` = `0xC000 + row*80`, drop attribute stores under
`JSP_TARGET_CPC`. CPC data-block `__at` placement & init (§9), BAT dropped (§6).
Get a *background-tile-only* CPC Mode 2 image on screen end-to-end (no sprites
yet) — the smallest provable CPC milestone.

**Phase 3 — CPC Mode 2 shift + kernels.**
Reuse `jsp_init_rottbl()` (M2 = ZX). Port the 8 `sp1_draw_*` kernels to CPC
Mode 2 (near-verbatim). Wire the covered-cell compositor. First moving,
pixel-shifted CPC sprite (Mode 2). Validate sub-byte X positioning visually.

**Phase 4 — CPC asset pipeline (Mode 2) + shift unit test.**
CPC Mode-2 asset emitter (§10); unit-test the §8.1 shift/mask against the
emitted bytes (the mandated cross-check). Adapt the sprite-gen Makefile targets.

**Phase 5 — Mode 2 full test pass.**
Build & visually verify all `tests/*` under `CPC_MODE2` on a CPC emulator.
Lock Mode 2 as the reference CPC pipeline.

**Phase 6 — CPC Mode 1.**
Mode-1 nibble shift table + `jsp_init_rottbl` variant (§4). Mode-1 kernels (§5).
Mode-1 asset emitter + shift unit test (§8.2). Resolve `CPC_MODE1_MONO` sub-
decision (§8) and add it. Test pass under `CPC_MODE1` / `CPC_MODE1_MONO`.
(Mode 1 is RAGE1's current CPC target, per analysis §12.)

**Phase 7 — CPC Mode 0.**
Mode-0 interleave shift (§4) + kernels (§5) + asset emitter + shift unit test
(§8.3). Test pass under `CPC_MODE0`.

**Phase 8 — FAST variants.**
`CPC_MODE0_FAST` / `CPC_MODE1_FAST`: force `shift=0`, use only the `nr` kernel,
skip the shift table. A thin compile-time fast path over Modes 0/1.

**Phase 9 — Toolchain matrix & docs.**
Finalise the `JSP_TARGET`/`JSP_CPC_MODE` Makefile matrix, CPC emulator run
target, and the CPC visual-verification/profiling story (§11). Update
`doc/ENGINE.md` (CPC memory maps, the colour asterisk §6, screen layout) and
`README.md`. Add a `doc/CPC-MODES.md` reference if the per-mode detail outgrows
this plan.

---

## 13. Risks and open decisions

1. **Descriptor X/Y width (§3).** 8-bit `xpos` cannot address Mode 2 (640 px).
   Widening ripples into the deferred draw/move asm and every test. Resolve in
   Phase 1; prefer per-target field width to avoid ZX size/speed regression.
2. **Hot-loop power-of-two assumptions (§2, §7).** `jsp_redraw.asm` extracts the
   column as `cell & 31` (32 cols) and the row as `g >> 2` (4 groups/row, from 8
   cells/group). CPC has 10 groups/row (80 ÷ 8) — `g/10`, `g%10` are not free
   shifts. **Resolved** (not deferred): replace per-cell division with an explicit
   `(row, col0)` running counter advanced once per group (`col0 += 8`, wrap at
   80). Still the trickiest single piece of new asm; called out so it is built
   deliberately, not by analogy to the ZX masks.
3. **Shift masks vs asset byte order (§4, §10).** The §8 masks are *derived*, not
   yet verified against a real converter. A first-class unit test gates each
   mode's kernels (Phases 4/6/7). Highest-likelihood source of subtle bugs.
4. **Colour subsystem genuinely differs (§6).** "Architecture unchanged" has an
   honest asterisk on colour; Phase-1 CPC drops dynamic colour. Confirm with the
   user that baked-in pixel colour is acceptable for the first CPC milestone.
5. **CPC profiling gap (§11) — visual verification is solved, profiling is not.**
   Visual checking is handled by the **`caprice-testing` skill** (cap32 headless
   + `tools/cap32-shot.sh`, adapted from RAGE1), the CPC analogue of
   `jnext-emulation`. What remains a gap is **headless T-state profiling**: there
   is no CPC equivalent of the JNEXT magic-port/heatmap, so CPC performance is
   eyeballed / wall-clock-timed for now. Do not claim profiling parity.
6. **Memory budget (§9).** 2000-cell tables + rottbl must coexist below the
   `0xC000` screen with program + free RAM. Tight in Mode 2 (largest rottbl);
   confirm the layout fits a realistic program before committing.
7. **`-create-app` output for `+cpc` — resolved.** `zcc +cpc -compiler=sdcc
   -create-app -subtype=dsk` emits a cap32-loadable `.dsk`; the AMSDOS catalog
   entry has an empty extension so it launches with `RUN"NAME.` (trailing dot,
   handled by `tools/cap32-shot.sh`). Still validate the *org/memory map* placement
   on first build (Phase 2).
8. **2000-cell DTT walk cost.** The redraw walks 250 groups vs ZX's 96 (~2.6×)
   and the screen is 16 KB vs 6.75 KB. The byte-skip clean-group fast path keeps
   the *clean* case cheap, but a full-screen CPC redraw moves far more data.
   Measure early; the FAST modes (§8) exist partly to claw this back. Note the
   ZX JNEXT profiler does not cover CPC (risk 5), so this may be eyeballed first.

---

## 14. Definition of done

- All seven configs (`CPC_MODE0/1/2`, `CPC_MODE1_MONO`, `CPC_MODE0_FAST`,
  `CPC_MODE1_FAST`) build and run pixel-smooth sprites on a CPC emulator.
- The ZX build and all ZX tests remain byte-for-byte unchanged (Phase 0
  baseline holds).
- Per-mode shift/mask unit tests pass against the real asset byte format.
- Makefile drives the full `JSP_TARGET × JSP_CPC_MODE` matrix; `doc/ENGINE.md`
  documents the CPC memory maps, screen layout and the colour divergence.
