# JSP-CPC — Tile & Sprite Memory Formats

This document is the authoritative reference for the **in-memory byte formats**
that the JSP engine expects for Amstrad CPC builds: background/foreground
**tiles** and **sprites** (`LOAD1` and `MASK2`), per CPC screen mode.

It describes what the bytes must look like in RAM when the engine reads them —
not the asset *tool*. The converter (`gfxgen.pl`, or a future per-mode emitter)
must produce exactly this layout; the shift/mask unit tests
(`make cpc-shift-test-mode<N>`) cross-check the engine's shift tables against it.

> Status: **Mode 2, Mode 1, Mode 1 MONO, Mode 0 and the FAST variants
> (Mode 0/1/2 FAST) are implemented and verified.**

| Mode            | px/byte | colours | shift phases | status        |
|-----------------|---------|---------|--------------|---------------|
| Mode 2          | 8       | 2       | 7 (xrot 1–7) | **done**      |
| Mode 1          | 4       | 4       | 3 (xrot 1–3) | **done**      |
| Mode 1 MONO     | 8 (1bpp, = Mode 2) | 2 | 3 (xrot 1–3, Mode-1 table) | **done**      |
| Mode 0          | 2       | 16      | 1 (xrot 1)   | **done**      |
| Mode 0/1/2 FAST | 2 / 4 / 8 | 16 / 4 / 2 | 0 (aligned)  | **done**      |

---

## 0. Cell model — affects the TILE format (sprites are model-agnostic)

JSP-CPC has two cell models (see `doc/CPC-TILE-SIZE-DESIGN.md`):

- **pixel-cell (Model B) — THE DEFAULT.** A cell is **8×8 pixels** in every mode,
  so it is `8/ppb` screen bytes wide: **2 bytes (Mode 1), 4 bytes (Mode 0),
  1 byte (Mode 2)**. Grid 20×25 (M0) / 40×25 (M1) / 80×25 (M2). Selected by the
  default, or explicitly `-DJSP_CELL_MODEL_PIXEL` (`make … JSP_CELL_MODEL=pixel`).
- **byte-cell (Model A).** A cell is **8 lines × 1 byte** in every mode (pixel
  width 2/4/8 px for M0/M1/M2), grid 80×25 always. Opt in with
  `-DJSP_CELL_MODEL_BYTE` (`make … JSP_CELL_MODEL=byte`).

**Mode 2 is identical in both models** (8 px = 1 byte = an 8×8-px cell either way).

What the model changes:

| Asset | Depends on cell model? | Format |
|-------|------------------------|--------|
| **Sprites** (`LOAD1`/`MASK2`) | **No — model-agnostic** | Always columns-major byte-columns (§1). A 16-px sprite is the same bytes and the same `cols` (byte-columns: 2/4/8 for M2/M1/M0) in both models — the compositor decomposes per byte-column regardless. |
| **Tiles** (background/foreground) | **Yes** | One **cell**: byte-cell = **8 bytes** (1 byte/line); **pixel-cell (default) = `(8/ppb)` byte-columns × 8 lines = `8/16/32` bytes (M2/M1/M0), COLUMN-MAJOR** (col 0's 8 bytes, then col 1's, …). |

So: **the default asset format is the pixel-cell format** — tiles are
**16-byte (Mode 1) / 32-byte (Mode 0) / 8-byte (Mode 2) column-major** cells, and
sprites are the same byte-column format as always. The byte-cell tile (a flat
8-byte cell) is only used when building `JSP_CELL_MODEL=byte`. Generate pixel-cell
tiles with `tools/cpcgfx.pl --gfx-type tile` (§6); sprites with
`--gfx-type sprite_mask|sprite_load` (unchanged, both models).

The per-mode pixel encoding (below) is the same in both models — only the cell's
*byte width / grouping* differs. The sub-sections §2–§4 describe the byte-cell
(8-byte) tile for clarity; the pixel-cell tile is that same per-line encoding,
`8/ppb` bytes per line × 8 lines, stored column-major.

---

## 1. Conventions common to all modes

These hold for every mode; only the per-byte *pixel encoding* and the *shift
arithmetic* change between modes.

- **Cell = 8 scan-lines.** A screen cell is 8 pixels tall. Its on-screen width is
  `8/ppb` bytes in the default pixel-cell model (2/4/1 for M1/M0/M2) and exactly
  1 byte in the byte-cell model (§0). A tile or one cell of a sprite is therefore
  **8 lines**, one (or more) bytes per line.
- **Pixel/bit order.** Within a byte the **most-significant bit is the leftmost
  pixel** (CPC convention). For multi-bit-per-pixel modes the bits of each pixel
  are interleaved across the byte (see each mode).
- **Tiles** are one cell: byte-cell = 8 bytes (one byte/line); pixel-cell
  (default) = `8/ppb` byte-columns × 8 lines, column-major (§0). Blitted to the
  cell's screen address stepping `+0x800` per line; a pixel-cell's `8/ppb`
  byte-columns go to adjacent screen bytes. Foreground tiles use the identical
  byte format — the only difference is the FTT flag, which makes `jsp_redraw`
  paint them from the BTT and never composite a sprite over them.
- **Sprites are stored columns-major**, one byte-column at a time, top-to-bottom
  within a column, left-to-right across columns. The compositor addresses a cell
  as `graph = base + pdc*rowstride + i*cs` (see §2.4), so this layout is a hard
  requirement, not a convention.
- **Sub-cell Y padding.** Each sprite has **8 transparent pre-rows before its
  label** and a **full 8-line blank cell after every column**. Together they let
  a sprite be placed at any pixel Y: the engine starts reading `yrot` lines
  *above* the label (into the pre-rows, `yrot ≤ 7`) and the bottom spill reaches
  at most 7 lines past a column's data — comfortably inside the 8. Columns
  therefore sit a clean `(rows+1)*cs` bytes apart (`rowstride = (rows+1)*cs`, no
  correction term). This is the layout RAGE1 (JSP's main consumer) assumes.
  (Earlier builds used a memory-saving 7-line overlapping pad with
  `rowstride = (rows+1)*cs - (cs>>3)`; the 8-line form trades `cols*(cs>>3)`
  bytes/sprite for RAGE1 compatibility and a correction-free stride.)
- **Coordinates.** Sprite X is 16-bit on CPC (full 640 px); Y is 8-bit. The
  per-frame split is `byte_col = x / ppb`, `xrot = x % ppb`, `r0 = y >> 3`,
  `yrot = y & 7` (doc/legacy/CPC-TARGET-PLAN.md §3).

### 1.1 Two sprite types

| Type    | bytes/line | bytes/cell (`cs`) | transparency | composite op                     |
|---------|------------|-------------------|--------------|----------------------------------|
| `LOAD1` | 1 (graph)  | 8                 | none (opaque)| `screen = graph` (overwrite)     |
| `MASK2` | 2 (mask,graph) | 16            | per-pixel    | `screen = (bg & mask) \| graph`  |

For `MASK2`, each scan-line is a **(mask, graph) byte pair**:
- **mask** bit = 1 → transparent (keep the background pixel);
  mask bit = 0 → opaque (replace with the graph pixel).
- **graph** = the sprite's pixel data for the opaque pixels.

So a fully-transparent line is `mask=0xFF, graph=0x00`; a fully-opaque line is
`mask=0x00, graph=<pixels>`.

### 1.2 Sprite size in memory

For a sprite that is `rows` cells tall and `cols` cells wide:

```
bytes per cell      cs        = 8 (LOAD1) | 16 (MASK2)
bytes per column    rowstride = (rows + 1) * cs              ; rows*cs + 8 trailing lines
sprite body         cols * rowstride bytes                  ; each col block incl. its 8-line tail
pre-rows (before label) 8 lines = 8*1 (LOAD1) | 8*2 (MASK2) bytes
```

Memory layout (columns-major), label points at the first body byte:

```
            (8 transparent pre-rows live just BEFORE the label)
label ->  column 0 :  cell(0,0) [cs] ... cell(rows-1,0) [cs] [8 blank lines]
          column 1 :  cell(0,1) ...                          [8 blank lines]
          ...
          column cols-1 : cell(0,..) ... cell(rows-1,..) [cs] [8 blank lines]  ; bottom pad
```

### 1.3 How the engine reads a sprite (per covered cell)

Set once per frame, per sprite (`jsp_redraw_begin`, `lib/cpc/jsp_frame.asm`):

```
cs        = 8 (LOAD1) | 16 (MASK2)
base      = pixels - yrot * (cs / 8)        ; back up yrot lines into the pre-rows
rowstride = (rows + 1) * cs                 ; columns a full 8-line cell apart
rottbl_msb= selects the xrot shift phase in jsp_rottbl
```

Per covered cell at sprite-relative cell-row `i` and cell-col `j`:

```
pdc   = (j == 0) ? 0 : (j >= cols) ? cols-1 : j     ; source column, clamped
graph = base + pdc*rowstride + i*cs                 ; -> this cell's cs bytes
```

The shift kernel reads those `cs` bytes (8 lines), shifts each line right by
`xrot` pixels using `jsp_rottbl`, and ORs in the carry spilling from the left
column — `out = rottbl_in[this] | rottbl_carry[left]`. The mode's pixel encoding
must make that table operation a true 1-pixel-per-step horizontal shift; this is
exactly what `make cpc-shift-test-mode<N>` verifies.

---

## 2. Mode 2 (1 bpp linear) — IMPLEMENTED

**Pixel encoding.** 8 pixels per byte, 1 bit per pixel, linear. Bit 7 = leftmost
pixel, bit 0 = rightmost. This is identical to the ZX Spectrum 1bpp byte, so the
CPC Mode-2 tile and sprite assets are **the same byte format as the ZX assets**
and the existing `gfxgen.pl` output is reused unchanged (see §2.5).

A 1-pixel right shift is a plain bit shift through the 16-bit window of two
horizontally-adjacent bytes:

```
phase i (1..7):   in-byte = src >> i        carry = (src << (8-i)) & 0xFF
out_byte[n] = (src[n] >> i) | (src[n-1] << (8-i))      ; src[-1] = 0 at the left edge
```

This is `jsp_rottbl` phase `i` (generated by `jsp_init_rottbl()`,
`include/jsp_rottbl_formula.h`) and is exhaustively unit-tested by
`make cpc-shift-test-mode2`.

### 2.1 Tile (background / foreground)

8 bytes, one per scan-line, MSB = leftmost pixel:

```c
// solid block, top+bottom border, vertical bars  (1 = ink/pen1, 0 = paper/pen0)
uint8_t tile[8] = { 0xFF, 0x81, 0x81, 0x81, 0x81, 0x81, 0x81, 0xFF };
```

`jsp_draw_background_tile(row,col,tile)` / `jsp_draw_foreground_tile(...)` store
the pointer in the BTT; `jsp_redraw` blits the 8 bytes to the cell.

### 2.2 LOAD1 sprite (opaque)

1 byte per line (graph only), `cs = 8`. One cell:

```
db $00          ; line 0   pixels: ........
db $3C          ; line 1   pixels: ..####..
db $7E          ; line 2   pixels: .######.
 ... (8 lines)
```

Stored columns-major with 8 trailing blank lines per column and 8 pre-rows
(`db $00` ×8) before the label. Composites by overwrite.

### 2.3 MASK2 sprite (transparent)

2 bytes per line `(mask, graph)`, `cs = 16`. Example — the top of the ball
sprite (`tests/test_sprite_mask2.asm`, `## = 1 bit, MSB left`):

```
;; 8 transparent pre-rows (before the label)
db $ff,$00      ; mask ################   graph ................
 ... (8 of these)
label:
;; column 0, cell-row 0 (8 lines)
db $f8,$00      ; mask ##########......   graph ................
db $e0,$03      ; mask ######..........   graph ............####
db $c0,$0c      ; mask ####............   graph ........####....
 ... (8 lines for this cell, then cell-row 1, then 8 trailing blank lines)
;; then column 1: same structure
```

A 16×16 (2×2-cell) MASK2 sprite body is `cols*rowstride = 2*48 = 96 bytes`
(the 8-line trailing cell; an older memory-saving 7-line form was `2*46 = 92`),
preceded by `8*2 = 16` pre-row bytes.

### 2.4 Engine constants for Mode 2

`ppb = 8`, `JSP_SHIFT_PHASES = 7`, `cs = 8/16`, `rottbl` = 7×(256 in + 256
carry) = 3584 bytes (256-aligned). Coordinate split: `byte_col = x >> 3`,
`xrot = x & 7`.

### 2.5 Generating Mode-2 assets

Mode 2 == ZX 1bpp, so the existing `gfxgen.pl` invocations emit Mode-2-ready
bytes directly (see the `## extras` rules in the `Makefile`):

```sh
# MASK2 (mask,graph pairs):
gfxgen.pl -i assets/ball.png --width 16 --height 16 \
    -m FF0000 -f FFFFFF -b 000000 \
    -s _sprite_pixels -g sprite_mask -l columns --extra-bottom-row --extra-top-rows

# LOAD1 (graph only): -g sprite_load
```

`-m` = the mask/transparent colour, `-f` = foreground (ink/pen1), `-b` =
background; `-l columns` = columns-major; `--extra-top-rows`/`--extra-bottom-row`
= the sub-cell-Y padding. Reuse the **same source PNG** across modes — only the
emitted encoding changes per mode, not the artwork.

---

## 3. Mode 1 (4 colours, two nibble-planes) — IMPLEMENTED

- `ppb = 4` (4 pixels/byte, 2 bits/pixel), `JSP_SHIFT_PHASES = 3` (xrot 1–3),
  `cs = 8` (LOAD1) / `16` (MASK2) — same cell-line count, same columns-major +
  pre-rows + (rows+1) layout as §1.
- **Pixel encoding:** the CPC Mode-1 byte holds 4 pixels with the two bit-planes
  interleaved: pixel `p` (0 = leftmost) has its plane-0 bit at position `(7-p)`
  (high nibble) and its plane-1 bit at `(3-p)` (low nibble); pixel value =
  `(plane1<<1)|plane0`.  So an 8-px ZX cell maps to TWO 4-px Mode-1 cells (the
  source px 7..4 → one byte's px 0..3, px 3..0 → the next byte's px 0..3) and a
  16-px-wide sprite is `cols = 4` Mode-1 columns.
- **Shift (one-pixel step):** `in = (src & 0xEE) >> 1`, `carry = (src & 0x11) << 3`;
  the closed forms for phases 1..3 are in `include/jsp_rottbl_formula.h`
  (guard-selected by `CPC_MODE1`/`CPC_MODE1_MONO`).  `jsp_init_rottbl()` builds the
  table unchanged (3 phases via `JSP_SHIFT_PHASES`); `rottbl_msb` keeps the M2
  `2*xrot-2` stride / `inc h` carry contract.  The kernels are the **same**
  table-driven `lib/cpc/jsp_draw_*` files as Mode 2 (only the table differs).
- **MASK2** mask is shifted with the **same** op as the pixels; composite stays
  `screen = (screen & shifted_mask) | shifted_pixels`.
- **Asset:** two nibble-plane pixel (and, for MASK2, mask) bytes, emitted by the
  in-repo `tools/cpcgfx.pl` (`--mode 1`) from the same source art.  For 2-colour
  art the low plane is 0 (pen 0/1); `--multicolor` uses all 4 pens (both planes
  carry the per-pixel pen bits) and can emit the matching palette.
- Validated by `make cpc-shift-test-mode1` (exhaustive combine vs an independent
  pixel-array shift, plus the emitted bytes) and visually in cap32
  (`make cpc-run-test TEST=sprite MODE=1`).

### 3.1 Mode 1 MONO — IMPLEMENTED

**The asset format is identical to SP1 / CPC Mode 2 — plain 1bpp** (`MASK2`
mask,graph pairs / `LOAD1` graph-only, MSB = leftmost, columns-major, the same
pre-rows / `(rows+1)` / `cs` = 8 or 16 layout). MONO therefore **reuses the
Mode-2 assets unchanged** (the very same `tests/test_sprite_mask2.asm` /
`load1` files) and the same source art — this is settled.

The **1bpp → Mode-1 planar conversion happens in the Mode-1 MONO blitting
kernels at draw time** (each source pixel bit becomes a 2-colour Mode-1 pixel,
pen 1 = set / pen 0 = clear; one 8-pixel source byte writes two Mode-1 screen
bytes, since Mode 1 = 4 px/byte). The conversion lives in the kernel, never in
the stored asset.

**DECIDED (Phase 6.1).** Reuse the **Mode-1 nibble `jsp_rottbl`** (3 phases, the
same table full Mode 1 uses) and put the 1bpp→Mode-1 expansion in the blitter.
Rationale: the expansion (a few nibble-mask instructions per byte) is cheap, and
reusing the already-verified Mode-1 table + middle kernels is far lower risk than
a bespoke MONO table.  Concretely:

- The MONO covered-cell compositor (`lib/cpc/jsp_covered_mono.asm`, guarded
  `IFDEF CPC_MODE1_MONO`; the full-colour `jsp_covered.asm` is guarded
  `IFNDEF CPC_MODE1_MONO`) maps each Mode-1 **screen** cell `j = col - c0` to a
  1bpp **source** column `j>>1` and a nibble `j&1` (0 = source px 7..4 → this
  cell, 1 = source px 3..0).  It expands the 8 lines of the selected nibble
  (and of the left screen cell's nibble, for the shift carry) into two transient
  Mode-1 scratch cells, then calls the **existing Mode-1 middle kernel**.  Because
  the left scratch is always supplied (zeroed at the sprite's left edge), MONO
  needs only the middle `mask2`/`load1` kernels — no `lb`/`rb` variants.
- The per-nibble expansion is exactly the `tools/cpcgfx.pl` byte transform:
  `graph_hi=g&0xF0`, `graph_lo=(g&0x0F)<<4`; `mask_hi=(m&0xF0)|((m&0xF0)>>4)`,
  `mask_lo=((m&0x0F)<<4)|(m&0x0F)`.
- `jsp_frame.asm` widens the MONO footprint to `c1 = c0 + (xrot ? 2*cols : 2*cols-1)`
  (each 1bpp column spans two Mode-1 screen cells); `cols` stays the 1bpp count.
- Nothing is stored expanded — the conversion is transient, per covered cell.
- **Tiles are 1bpp too.**  Background/foreground tiles reuse the same plain 1bpp
  (Mode-2) assets and halve their memory.  The BTT holds the 1bpp tile pointer;
  the blit expands `nibble(col & 1)` of the 8-byte tile into Mode-1 bytes
  (graph-only, `mono_tile_expand` in `jsp_covered_mono.asm`, called from the bg
  path in `jsp_redraw.asm` and from the covered-cell seed/uncovered fallback).
  A 1bpp 8-px tile spans two Mode-1 screen cells, so `parity = col & 1` (= even
  col → left 4 px, odd col → right 4 px; `cell & 1 == col & 1` since `row*80` is
  even).  A uniform fill — the same `for c: draw(r,c,tile)` loop as Mode 2 —
  therefore tiles the 8-px pattern seamlessly, and an explicit 8-px tile is
  placed at an even col so its halves land in cells `2k`/`2k+1`.  No per-cell
  parity storage is needed and the 80-col grid / 1-pointer-per-cell BTT are
  unchanged.
- Validated by `make cpc-shift-test-mode1-mono` (the expansion + combine vs a
  true monochrome shift) and visually in cap32 (`make cpc-run-test TEST=sprite MODE=1_mono`:
  masked 1bpp balls over a seamless 1bpp tile background, all xrot 0–3 clean).

(This is distinct from full Mode 1 above, whose assets are genuinely 4-colour
two-nibble-plane and need no expansion.)

---

## 4. Mode 0 (16 colours, odd/even interleave) — IMPLEMENTED

- `ppb = 2` (2 pixels/byte, 4 bits/pixel), `JSP_SHIFT_PHASES = 1` (xrot 0/1),
  `cs = 8/16`, same columns-major + pre-rows + (rows+1) layout as §1.
- **Pixel encoding:** the CPC Mode-0 byte holds 2 pixels with the four bit-planes
  interleaved.  Pixel 0 (left) occupies the odd bit positions {7,5,3,1}, pixel 1
  (right) the even {6,4,2,0}; cell-pixel `cp`'s plane `q` bit is `(7-cp) - q*ppc`
  (plane stride = `ppb` = 2).  Each 8-px ZX source column → **4 Mode-0 cells**
  (2 px each), so a 16-px-wide sprite is `cols = 8`.  For 2-colour art only
  plane 0 (pen 1) is set; `--multicolor` uses all 16 pens (the 4 planes carry the
  per-pixel pen bits) and can emit the matching palette.
- **Shift (single phase):** `in = (src & 0xAA) >> 1`, `carry = (src & 0x55) << 1`
  (xrot 0 = aligned/no shift, xrot 1 = the 1-px step) — in
  `include/jsp_rottbl_formula.h` (guard `CPC_MODE0`).  `jsp_init_rottbl` builds
  the 512-byte table unchanged; `rottbl_msb` keeps the `2*xrot-2` stride.  The
  kernels are the **same** table-driven `lib/cpc/jsp_draw_*` files as M1/M2.
- **Cell model:** pixel-cell (Model B) is the **default** — grid 20×25, cell =
  8×8 px = 4 bytes wide (32-byte column-major tile); byte-cell (Model A) is
  available (`JSP_CELL_MODEL=byte`, grid 80×25, 1-byte/2-px cell). See §0 and
  `doc/CPC-TILE-SIZE-DESIGN.md`.  Mode 0 is the extreme case (4× fewer cells in
  pixel-cell) and the biggest pixel-cell performance win.
- **Asset:** emitted by `tools/cpcgfx.pl --mode 0`; mask transparent pixel sets
  all four planes (so the AND keeps the background).
- Validated by `make cpc-shift-test-mode0` (exhaustive combine + emitted bytes
  vs an independent Mode-0 pixel-array shift) and visually in cap32
  (`make cpc-run-test TEST=sprite MODE=0`).

---

## 5. FAST variants (`CPC_MODE0_FAST`, `CPC_MODE1_FAST`, `CPC_MODE2_FAST`) — done

Force `xrot = 0` (byte-aligned positioning, `JSP_SHIFT_PHASES = 0`): no rotation
table, the `nr` (no-rotate) kernel only.  **Asset bytes are byte-for-byte the
same per-mode pixel encoding as the non-FAST mode** — a FAST build links the very
same emitted assets (`CPC_MODE2_FAST` reuses the ZX/Mode-2 1bpp `test_sprite_*`,
`CPC_MODE0/1_FAST` reuse the `_m0`/`_m1` planar assets).  Only the positioning
granularity (8 px for Mode 2, 4 px for Mode 1, 2 px for Mode 0) and the absence
of sub-byte shifting differ.

**No asset change.**  FAST builds simply guarantee byte alignment for every cell:
the geom include (`lib/cpc/jsp_cpc_geom.inc`) sets `JSP_XROT_MASK = 0` (xrot
always 0) and `jsp_init_rottbl` builds an empty table (`JSP_SHIFT_PHASES = 0`).
`CPC_MODE2_FAST` reclaims the most RAM, since the Mode-2 rottbl is the largest
(3584 B → 0).

**The rotating kernels are compiled OUT of a FAST binary (not merely bypassed).**
A non-FAST build relies on a *runtime* redirect: when a sprite happens to land
byte-aligned (`xrot == 0`), `jsp_frame.asm` writes `rottbl_msb == jsp_rottbl/256
- 2`, and the lb/middle composite kernels detect that and `jp` to the `nr` kernel.
That redirect still exists for the occasional aligned sprite in a *shifting*
build.  In a FAST build, where *every* cell is aligned, the redirect would be
pure overhead and the six rotating kernels (`mask2`/`load1` × middle/`lb`/`rb`)
would be dead code, so they are removed at assembly time:

- The six `lib/cpc/jsp_draw_*` rotating kernels are wrapped in
  `IF CPC_MODE0_FAST || CPC_MODE1_FAST || CPC_MODE2_FAST` … `ELSE` … `ENDIF`, so
  in a FAST build they assemble to nothing (no symbol, no code linked).  The two
  `nr` kernels (`jsp_draw_mask2nr`, `jsp_draw_load1nr`) are always present.
- The covered-cell compositor (`lib/cpc/jsp_covered.asm`) has a matching FAST
  dispatch under the same guard: it skips the `graph_left` computation and the
  left/right-border decision entirely and `call`s the `nr` kernel directly with
  `(dst, graph)`.
- The guard is the **OR of the three existing `CPC_MODE*_FAST` flags** — no new
  "is-FAST" symbol is introduced (z80asm treats an undefined symbol as 0 in an
  `IF` expression, so the OR is true iff one FAST mode is defined).

Net effect of a FAST build vs the corresponding shifting mode: **no rotation
table** (RAM saved: 3584/1536/512 B for M2/M1/M0 → 0) **and no rotating kernel
code** (~1 KB of composite kernels gone), with a shorter per-cell path (no
redirect prologue, no `graph_left`).  Verified: the FAST maps contain only the
`nr` kernels; the rotating kernel symbols are absent.

No shift unit test is needed (no shift); the no-rotate render is confirmed by
`make cpc-run-test TEST=sprite MODE=2_fast` (and `0_fast` / `1_fast`) (masked
balls byte-aligned over the per-mode grid, verified in cap32).

---

## 6. Generating tiles (`tools/cpcgfx.pl --gfx-type tile`)

The default (pixel-cell) background/foreground tile is a single 8×8-px cell:
`8/ppb` byte-columns × 8 lines, **column-major** (col 0's 8 bytes, then col 1's),
graph-only. `tools/cpcgfx.pl --gfx-type tile` emits exactly this:

```sh
# Mode 1 (16-byte cell = 2 byte-cols × 8 lines), pen 0/1 art:
tools/cpcgfx.pl -i tile.png -x 0 -y 0 --width 8 --height 8 -s my_tile -g tile --mode 1
# Mode 0 -> 32-byte cell (4 byte-cols × 8 lines):  --mode 0
```

Store the symbol with `jsp_draw_background_tile(row,col, my_tile)` /
`jsp_draw_foreground_tile(...)`. Sprites are emitted as before with
`-g sprite_mask|sprite_load` (model-agnostic). The byte-cell tile (a flat 8-byte
cell, `JSP_CELL_MODEL=byte`) has no dedicated emitter — its 8 bytes are the §2–§4
per-line encoding written directly.

---

## See also

- `doc/legacy/CPC-TARGET-PLAN.md` — full design (§4 shift tables, §10 asset format).
- `include/jsp_rottbl_formula.h` — the shared shift-table entry formula.
- `tests/cpc/shift_test_mode2.c` — the Mode-2 shift/mask unit test.
- `tests/test_sprite_mask2.asm` / `test_sprite_load1.asm` — emitted Mode-2 assets.
