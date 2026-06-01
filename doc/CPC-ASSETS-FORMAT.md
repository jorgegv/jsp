# JSP-CPC — Tile & Sprite Memory Formats

This document is the authoritative reference for the **in-memory byte formats**
that the JSP engine expects for Amstrad CPC builds: background/foreground
**tiles** and **sprites** (`LOAD1` and `MASK2`), per CPC screen mode.

It describes what the bytes must look like in RAM when the engine reads them —
not the asset *tool*. The converter (`gfxgen.pl`, or a future per-mode emitter)
must produce exactly this layout; the shift/mask unit tests
(`make cpc-shift-test-mode<N>`) cross-check the engine's shift tables against it.

> Status: **Mode 2 is implemented and verified.** Mode 1, Mode 0 and the
> MONO/FAST variants are specified here from the design (doc/CPC-TARGET-PLAN.md
> §4/§8/§10) but **not yet implemented** — their sections are marked TODO and
> must be confirmed by their own shift unit test before being relied upon.

| Mode            | px/byte | colours | shift phases | status        |
|-----------------|---------|---------|--------------|---------------|
| Mode 2          | 8       | 2       | 7 (xrot 1–7) | **done**      |
| Mode 1          | 4       | 4       | 3 (xrot 1–3) | TODO (Ph. 6)  |
| Mode 1 MONO     | 4 (1bpp src) | 2  | 3            | TODO (Ph. 6)  |
| Mode 0          | 2       | 16      | 1 (xrot 1)   | TODO (Ph. 7)  |
| Mode 0/1 FAST   | 2 / 4   | 16 / 4  | 0 (aligned)  | TODO (Ph. 8)  |

---

## 1. Conventions common to all modes

These hold for every mode; only the per-byte *pixel encoding* and the *shift
arithmetic* change between modes.

- **Cell = 8 scan-lines.** A screen cell is 8 pixels tall and one byte wide on
  screen (Model A: cell == byte column). A tile or one cell of a sprite is
  therefore **8 lines**, one (or more, see below) bytes per line.
- **Pixel/bit order.** Within a byte the **most-significant bit is the leftmost
  pixel** (CPC convention). For multi-bit-per-pixel modes the bits of each pixel
  are interleaved across the byte (see each mode).
- **Tiles are 8 bytes** (Mode 2): one byte per scan-line, blitted to
  `0xC000 + cell` stepping `+0x800` per line. Foreground tiles use the identical
  byte format — the only difference is the FTT flag, which makes `jsp_redraw`
  paint them from the BTT and never composite a sprite over them.
- **Sprites are stored columns-major**, one byte-column at a time, top-to-bottom
  within a column, left-to-right across columns. The compositor addresses a cell
  as `graph = base + pdc*rowstride + i*cs` (see §2.4), so this layout is a hard
  requirement, not a convention.
- **Sub-cell Y padding.** Each sprite has **7 transparent pre-rows before its
  label** and an **extra blank cell-row at the bottom of every column** (the
  `+1` in `rows+1`). Together they let a sprite be placed at any pixel Y: the
  engine starts reading `yrot` lines *above* the label (into the transparent
  pre-rows) and the bottom spill lands in the extra row. Without this padding a
  sub-cell-Y sprite would read neighbouring data.
- **Coordinates.** Sprite X is 16-bit on CPC (full 640 px); Y is 8-bit. The
  per-frame split is `byte_col = x / ppb`, `xrot = x % ppb`, `r0 = y >> 3`,
  `yrot = y & 7` (doc/CPC-TARGET-PLAN.md §3).

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
bytes per column    rowstride = (rows + 1) * cs        ; +1 = extra bottom row
sprite body         cols * rowstride bytes
pre-rows (before label) 7 lines = 7*1 (LOAD1) | 7*2 (MASK2) bytes
```

Memory layout (columns-major), label points at the first body byte:

```
            (7 transparent pre-rows live just BEFORE the label)
label ->  column 0 :  cell(0,0) [cs] cell(1,0) [cs] ... cell(rows,0) [cs]   ; rows+1 cells
          column 1 :  cell(0,1) ...
          ...
          column cols-1 : ...
```

### 1.3 How the engine reads a sprite (per covered cell)

Set once per frame, per sprite (`jsp_redraw_begin`, `lib/cpc/jsp_frame.asm`):

```
cs        = 8 (LOAD1) | 16 (MASK2)
base      = pixels - yrot * (cs / 8)        ; back up yrot lines into the pre-rows
rowstride = (rows + 1) * cs
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

Stored columns-major with the (rows+1) extra bottom cell-row and 7 pre-rows
(`db $00` ×7) before the label. Composites by overwrite.

### 2.3 MASK2 sprite (transparent)

2 bytes per line `(mask, graph)`, `cs = 16`. Example — the top of the ball
sprite (`tests/test_sprite_mask2.asm`, `## = 1 bit, MSB left`):

```
;; 7 transparent pre-rows (before the label)
db $ff,$00      ; mask ################   graph ................
 ... (7 of these)
label:
;; column 0, cell-row 0 (8 lines)
db $f8,$00      ; mask ##########......   graph ................
db $e0,$03      ; mask ######..........   graph ............####
db $c0,$0c      ; mask ####............   graph ........####....
 ... (8 lines for this cell, then cell-row 1, then the extra bottom row)
;; then column 1: same structure
```

A 16×16 (2×2-cell) MASK2 sprite body is `cols*(rows+1)*cs = 2*3*16 = 96 bytes`,
preceded by `7*2 = 14` pre-row bytes.

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

## 3. Mode 1 (4 colours, two nibble-planes) — TODO (Phase 6)

**Planned (doc/CPC-TARGET-PLAN.md §4/§8/§10); not yet implemented.**

- `ppb = 4` (4 pixels/byte, 2 bits/pixel), `JSP_SHIFT_PHASES = 3` (xrot 1–3),
  `cs = 8` (LOAD1) / `16` (MASK2) — same cell-line count, same columns-major +
  pre-rows + (rows+1) layout as §1.
- **Pixel encoding:** CPC Mode-1 byte holds 4 pixels with the two bit-planes
  interleaved (each pixel = one bit in the high nibble + one in the low nibble).
- **Shift (one-pixel step):** `in = (src & 0xEE) >> 1`, `carry = (src & 0x11) << 3`;
  the 2- and 3-pixel phases compose the 1-pixel step. `jsp_init_rottbl()` gains a
  Mode-1 variant generating a 256-entry in/carry table per phase.
- **MASK2** mask is shifted with the **same** per-mode op as the pixels;
  composite stays `screen = (screen & shifted_mask) | shifted_pixels`.
- **Asset:** two nibble-plane pixel (and, for MASK2, mask) bytes; re-quantise the
  same source art to the 4-colour palette.
- Must be validated by `make cpc-shift-test-mode1` against the emitted bytes
  before the kernels are trusted.

### 3.1 Mode 1 MONO — TODO (Phase 6)

1bpp source art packed into the Mode-1 framebuffer per the MONO encoding decision
(doc/CPC-TARGET-PLAN.md §8, still open). Document the chosen packing here once
decided.

---

## 4. Mode 0 (16 colours, odd/even interleave) — TODO (Phase 7)

**Planned (doc/CPC-TARGET-PLAN.md §4/§8/§10); not yet implemented.**

- `ppb = 2` (2 pixels/byte, 4 bits/pixel), `JSP_SHIFT_PHASES = 1` (xrot 0/1),
  `cs = 8/16`, same columns-major + pad layout.
- **Pixel encoding:** CPC Mode-0 byte holds 2 pixels with the four bit-planes
  interleaved (odd/even pixel bits spread across the byte).
- **Shift (one-pixel step):** `in = (src & 0xAA) >> 1`, `carry = (src & 0x55) << 1`
  (single phase; xrot 0 = aligned, no shift).
- **Cell model** (byte-cell vs pixel-cell) is settled in Phase 7 by measurement
  (doc/CPC-TILE-SIZE-ANALYSIS.md); if it differs from the Model-A default the
  grid/asset sizing notes here must be reconciled.
- Validate with `make cpc-shift-test-mode0`.

---

## 5. FAST variants (`CPC_MODE0_FAST`, `CPC_MODE1_FAST`) — TODO (Phase 8)

**Planned; not yet implemented.** Force `xrot = 0` (byte-aligned positioning,
`JSP_SHIFT_PHASES = 0`): no rotation table, the `nr` (no-rotate) kernel only.
Asset bytes are the same per-mode pixel encoding as the non-FAST mode; only the
positioning granularity (2 px for Mode 0, 4 px for Mode 1) and the absence of
sub-byte shifting differ. No shift unit test is needed (no shift), but a
no-rotate render test should confirm alignment.

---

## See also

- `doc/CPC-TARGET-PLAN.md` — full design (§4 shift tables, §10 asset format).
- `include/jsp_rottbl_formula.h` — the shared shift-table entry formula.
- `tests/cpc/shift_test_mode2.c` — the Mode-2 shift/mask unit test.
- `tests/test_sprite_mask2.asm` / `test_sprite_load1.asm` — emitted Mode-2 assets.
