# CPC Implicit-Mask (`_IMASK`) Sprite Mode — Design Evaluation

Status: **implemented** (2026-06-08, branch `cpc_implicit_mask`). See
`doc/CPC-IMASK-IMPLEMENTATION-PLAN.md` for the build order and
`lib/cpc/jsp_draw_imask.asm` for the kernels.

## Summary

Add a new CPC sprite mode family, `_IMASK` ("implicit mask"), for **Mode 1 and
Mode 0**, in which transparency is encoded by dedicating **pen 0** as the
transparent colour instead of storing an explicit per-pixel mask. Masked sprites
then store only their graph bytes (8 B/cell instead of the 16 B/cell of MASK2),
halving masked-sprite memory, with **neutral-to-better** draw performance and a
structurally simpler shift/border path.

Mode 2 is intentionally **excluded**: with pen 0 transparent it collapses to the
existing `_MONO` semantics (see §6).

Tiles are unaffected (they are opaque `LOAD1`, no mask).

## 1. Current model (baseline)

MASK2 sprites store `(mask, graph)` byte pairs and composite:

```
screen = (background & mask) | graph        ; mask bit 1 = keep bg (transparent)
```

- Data: **16 B per 8×8 cell** (`lib/cpc/jsp_draw_mask2nr.asm`,
  `doc/CPC-ASSETS-FORMAT.md`).
- The mask is shifted/carried through `jsp_rottbl` in parallel with the graph in
  the rotating kernel (`lib/cpc/jsp_draw_mask2.asm:74-90` does ~4 table lookups
  per byte: mask-this, mask-left-carry, graph-left-carry, graph-this).
- Four MASK2 kernel variants exist (normal / left-border / right-border /
  no-rotate), partly because the *mask's* vacated/edge bits must be seeded to
  transparent (0xFF) specially.

## 2. Core idea

With "pen 0 = transparent", a pixel is transparent ⟺ **all of its plane bits are
0**, in every CPC encoding (the plane layouts are the single-source-of-truth
formulas in `include/jsp_rottbl_formula.h`). Therefore the mask is a pure
function of the graph byte, computable via a **256-byte lookup table per mode**:

```
imask[g] = for each pixel in g whose pen == 0, set ALL that pixel's plane bits;
           else 0
```

and the composite becomes:

```
screen = (background & imask[g]) | g
```

Why a LUT rather than in-register bit-twiddling:
- It is **uniform** across modes — only the table *contents* differ (built from
  the same plane layout already in `jsp_rottbl_formula.h`).
- It costs **exactly as many memory accesses** as MASK2 already performs.
- It is also **faster** than the in-register derivation in *every* mode, not just
  the awkward ones. M0 needs a horizontal OR-reduction of the 0xAA / 0x55 planes
  (expensive). M1 has a tidy "swap nibbles, `or`, `cpl`" trick — but that is
  still ~4 `rrca` + `cpl` (≈20 T) versus an 11 T index+load, so the LUT wins
  ~13 T/byte even there. So there is no per-mode special path: one LUT kernel for
  M0 and M1. (See Appendix A for the byte-level T-state comparison.)
- 256 B/build is negligible beside the 512–3584 B rotation table; it can share
  the rottbl's 256-aligned region.

### Correctness under shifting

The rotating kernel keeps shifting the **graph** (in-byte + left carry) through
`jsp_rottbl`; the mask is then derived from the *final combined graph byte* via
`imask[]`. This is correct because:
- A pixel shift preserves pen values; vacated high bits shift in as 0 = pen 0 =
  transparent, which is exactly what `imask[0…]` reports ("keep background").
- Border/edge bits of a sprite column are 0 in the graph, so `imask` yields
  "keep background" for them **for free** — no special transparent seeding.

## 3. Memory impact

| | Current MASK2 | `_IMASK` |
|---|---|---|
| Bytes per 8×8 cell | 16 (mask+graph) | **8** (graph only) |
| 16×16 masked sprite body | ~192 B | **~96 B** |
| M1 sprite vs ZX equivalent | 2× | **1× (same as ZX)** |
| M0 sprite vs ZX equivalent | 4× | **2×** |
| Extra engine RAM | — | +256 B LUT (one mode/build) |
| Tiles (`LOAD1`) | unchanged | unchanged |

Sprite banks dominate free-RAM usage in a real game, so halving masked-sprite
storage is the headline benefit.

## 4. Performance impact

Counting memory cycles per byte (the Z80 bottleneck):

- **No-rotate path** (`lib/cpc/jsp_draw_mask2nr.asm:38-44`):
  today = 2 sprite reads (mask, graph) + bg read + write.
  `_IMASK` = 1 graph read + 1 LUT read + bg read + write.
  → **same access count, half the data footprint.** T-states ≈ wash.
- **Rotating path**: today ≈ 6 reads/byte (4 rottbl + 2 sprite-def).
  `_IMASK` = graph-this lookup + graph-left-carry lookup + `imask[combined]` +
  1 sprite read = **~4 reads/byte** — fewer, because the mask no longer needs
  its own shift+carry.
  → **net faster in the shifted case.**

Conclusion: **no performance penalty expected**; small win in the rotating
kernel, plus halved data improves fetch locality.

**Measured** (2026-06-08, cap32 wall-clock, same scene built as MASK2 vs IMASK,
boot-free metric t(2000)−t(1000) for 1000 redraws of 8 sprites; lower = faster):

| Mode | MASK2 | IMASK | Δ |
|------|-------|-------|---|
| Mode 1 | 13.26 s | 13.28 s | +0.2% |
| Mode 0 | 15.12 s | 15.12 s | +0.05% |

So the simple correctness-first kernel is **performance-neutral** (within
measurement noise) at **half the sprite memory** — the predicted outcome. The
implemented kernel reloads the rottbl page per line and swaps to the LUT page,
which spends back the theoretical rotating-path saving; a future optimisation
pass could pull ahead, but the memory win is the point.

## 5. Special optimisations unlocked

1. **Simpler border kernels (not eliminated).** *Correction to an earlier draft:*
   the left/right border kernels are still needed — they handle the graph
   *rotation carry* at sprite edges, exactly as LOAD1's `load1lb`/`load1rb` do, so
   `_IMASK` keeps the same four-kernel shape (mid / nr / lb / rb). What implicit
   mask removes is the *parallel mask shift* (MASK2 shifts both mask and graph
   through `jsp_rottbl` and combines both; `_IMASK` shifts only the graph) and the
   `0xFF` transparent-mask seeding at borders: a sprite's vacated/edge graph bits
   are 0, so `imask[…]` yields "keep background" there for free. Each `_IMASK`
   kernel is therefore a simpler, graph-only variant of its MASK2 twin plus one
   LUT lookup. (The aligned, xrot==0 case still delegates to the no-rotate
   kernel, as in MASK2.)
2. **Free transparent padding.** The 8 blank pre-rows, trailing 8 blank lines,
   and the clamped overflow-column trick currently need explicit `0xFF/0x00`
   mask encoding. With implicit mask, zeroed bytes = transparent, so padding is
   just zeros — and half as many bytes.
3. **Mode 2 ⇒ pure `OR`.** For 1bpp, `imask[g] = ~g`, so
   `(bg & ~g) | g = bg | g`. That leaves only pen 1 drawable, which is exactly
   the existing `_MONO` semantics → no separate M2 `_IMASK` (see §6).
4. **Asset pipeline shrinks.** `tools/cpcgfx.pl` already chooses a transparent
   colour; pin it to pen 0 and emit graph-only (`db $graph`), dropping the
   `db $mask,$graph` pairing.

## 6. Scope: M1 and M0 only

Mode 2 with pen-0 transparency collapses to `bg | graph` with a single drawable
colour — identical to the existing `_MONO` mode. Implementing a separate M2
`_IMASK` would be redundant, so `_IMASK` is **M1 + M0 only**.

## 7. Trade-offs / what is given up

- **Pen 0 is no longer an opaque sprite colour.** M0: 16→15 usable colours;
  M1: 4→3 usable + transparent. Standard colour-key trade; fine for almost all
  game art. Art deliberately using black-via-pen-0 as a solid sprite fill would
  get holes — such cases keep using MASK2.
- **Additive, not a replacement.** MASK2 remains for the rare opaque-pen-0 need,
  so `_IMASK` adds code paths (like `_MONO` / `_FAST` did). The cost is bounded
  and partly offset by dropping the mask border-kernel variants in the `_IMASK`
  path.

## 8. Recommendation

**Implement** `CPC_MODE1_IMASK` and `CPC_MODE0_IMASK`. Best memory-per-effort
lever on CPC: ~50% sprite RAM recovered, neutral-to-positive performance, and a
simpler shift/border path. Skip M2 (covered by `_MONO`).

## 9. Draft implementation plan

Each step is independently testable; small commits per the repo conventions.

1. **Asset format + tool** — `cpcgfx.pl --imask`: reserve pen 0 = transparent,
   emit graph-only (8 B/cell), zeroed padding. Document in
   `doc/CPC-ASSETS-FORMAT.md`. *(test: golden-file ASM diff)*
2. **Build the LUT** — generate `jsp_imask_tbl[256]` per mode from the plane
   layout in `include/jsp_rottbl_formula.h` (single source of truth, like the
   rottbl). Host unit test asserting `imask[g]` matches a reference pixel-array
   derivation, mirroring `cpc-shift-test-mode*`. *(test: host, no emulator)*
3. **No-rotate kernel** — `jsp_draw_imasknr.asm`:
   `graph → LUT → (bg & m) | g`. Wire into `lib/cpc/jsp_covered.asm` dispatch
   under the new mode guard. *(test: byte-aligned screenshot)*
4. **Rotating kernels** — `jsp_draw_imask.asm` (mid/lb/rb): graph in+carry via
   rottbl, then `imask[combined]` for the mask. No mask carry, no `0xFF` border
   seeding (but lb/rb still needed for the graph carry). *(test: screenshot
   regression vs MASK2 reference over a black background — pixel-identical)*
5. **Geometry/config** — add `CPC_MODE{0,1}_IMASK` to `lib/cpc/jsp_cpc_geom.inc`
   (same PPB/XROT as the non-FAST mode) and the Makefile mode matrix; one new
   test sprite per mode + `tests/refs/` baselines.
6. **Verify & measure** — add to `cpc-tests`; run `cpc-perf-matrix` to confirm
   the neutral/positive timing claim before committing.

## References

- `lib/cpc/jsp_draw_mask2nr.asm` — MASK2 no-rotate kernel (baseline composite)
- `lib/cpc/jsp_draw_mask2.asm:72-95` — MASK2 rotating kernel inner loop
- `include/jsp_rottbl_formula.h` — per-mode plane layouts (LUT source of truth)
- `lib/cpc/jsp_cpc_geom.inc` — per-mode geometry constants
- `lib/cpc/jsp_covered.asm` — covered-cell compositor / kernel dispatch
- `tools/cpcgfx.pl` — asset emitter (`--multicolor`, mask encoding)
- `doc/CPC-ASSETS-FORMAT.md` — current sprite data formats

---

## Appendix A — Mode 1 compositing, worked example

This appendix walks one Mode-1 sprite byte through the kernel, value by value, to
make the read / mask / composite sequence concrete.

### A.1 Mode 1 pixel layout

A Mode 1 byte holds **4 pixels**, each 2 bits (pen 0–3). The two bits of a pixel
are split into two nibble-planes (per `include/jsp_rottbl_formula.h:38-42`):

```
bit:     7    6    5    4   |  3    2    1    0
pixel:   0    1    2    3   |  0    1    2    3
plane:  ---- plane 0 ----  |  ---- plane 1 ----
```

So pixel 0 = `bit7` (plane 0) + `bit3` (plane 1); pixel 1 = `bit6` + `bit2`; etc.
The two bits of a pixel sit at the same slot in each nibble, 4 positions apart.
Pen value = combine the two plane bits (the exact weighting is a hardware
convention and is irrelevant to transparency — only **zero vs non-zero** matters;
this example uses `pen = plane0 + 2·plane1`).

**Transparent = pen 0 = both plane bits of that pixel are 0.**

### A.2 Worked values

Draw a row `[transparent, pen 2, pen 1, transparent]` over a background that is
pen 3 everywhere (`bg = 0xFF`).

Build the graph byte `g`:

| pixel | pen | plane0 bit | plane1 bit |
|---|---|---|---|
| 0 | 0 (transp.) | bit7 = 0 | bit3 = 0 |
| 1 | 2           | bit6 = 0 | bit2 = 1 |
| 2 | 1           | bit5 = 1 | bit1 = 0 |
| 3 | 0 (transp.) | bit4 = 0 | bit0 = 0 |

```
g = 0010 0100 = 0x24
```

Derive the mask (set BOTH bits of each transparent pixel — pixels 0 and 3):

```
imask[0x24] = 1001 1001 = 0x99
```

Composite:

```
bg & mask = 0xFF & 0x99 = 0x99      ; keep background where mask = 1
result    = 0x99 | 0x24 = 0xBD      ; punch sprite pixels in where mask = 0
```

Decode `0xBD = 1011 1101`:

| pixel | plane0 | plane1 | pen | source |
|---|---|---|---|---|
| 0 | bit7=1 | bit3=1 | 3 | background kept |
| 1 | bit6=0 | bit2=1 | 2 | sprite drawn |
| 2 | bit5=1 | bit1=0 | 1 | sprite drawn |
| 3 | bit4=1 | bit0=1 | 3 | background kept |

Result `[bg, pen2, pen1, bg]` — correct.

### A.3 The kernel, instruction by instruction (LUT form, recommended)

Per scanline byte. `h` = `imask` table page, set **once** before the 8-line
unroll; `de` = sprite graph pointer (graph-only, 8 B/cell); `ix` = dst cell.

```
ld   a,(de)      ; READ  graph byte      a = 0x24            ← read #1
inc  de          ;       next graph byte
ld   c,a         ;       save g          c = 0x24
ld   l,a         ;       index = g
ld   a,(hl)      ; READ  mask = imask[g] a = 0x99            ← read #2
and  (ix+0)      ; READ  bg, & mask      a = 0xFF & 0x99 = 0x99   ← read #3
or   c           ;       | graph         a = 0x99 | 0x24 = 0xBD
ld   (ix+0),a    ; WRITE composited byte → 0xBD              ← write
```

Reads `graph + LUT + bg`, writes the result — same memory-access count as MASK2,
but the sprite stores **1 byte/pixel-byte instead of 2**.

### A.4 The in-register alternative (rejected)

Mode 1 *can* derive the mask without a table by swapping nibbles
(`mask = ~(g | swap(g))`), but it is both slower and a separate code path:

```
ld   a,(hl)      ; a = g = 0x24
ld   c,a
rrca/rrca/rrca/rrca   ; swap nibbles -> 0x42
or   c           ; occupancy both nibbles = 0x66
cpl              ; mask = 0x99
and  (ix+0)      ; & bg
or   c           ; | g
ld   (ix+0),a    ; write
inc  hl
```

Per-byte cost (h preset for the LUT form):

| | LUT | in-register |
|---|---|---|
| T-states / byte | ~70 | ~83 |

The 4×`rrca` + `cpl` (≈20 T) cost more than the LUT index+load (≈11 T), so the
LUT is ~13 T/byte faster **and** keeps one kernel shared with Mode 0. The
in-register trick is retained here only as documentation of why it was not used.
