# ENGINE NOTES

A "tile" is an 8x8 UDG stored top to down in memory (8 consecutive bytes)

JSP uses a **deferred recompositing** model: drawing/moving a sprite never
touches the screen — it only updates sprite state and marks cells dirty.
`jsp_redraw()` then recomputes the affected part of the screen from the
background tables plus the *live* sprite state.  Nothing is "baked": the
displayed image is recomputed each frame, so overlapping, independently
moving and animated sprites all render correctly.  This matches the SP1
sprite library's observable semantics (see `doc/legacy/RECOMPOSITE-REDESIGN.md`
for the full rationale).

## ENGINE MEMORY AREAS

- BTT: Background tiles table: a table of 768 pointers to the background tiles
  (only background, no sprites) for each screen cell - 1536 bytes.  For a
  foreground cell, the BTT holds the foreground tile graphic.

- DTT: Dirty tiles table: a table of 768 bits (_not_ bytes), indicating what
  tiles need to be redrawn on each frame - 96 bytes

- FTT: Foreground tiles table: a table of 768 bits (_not_ bytes), indicating what
  tiles are on top of all sprites and should not be overwritten by them - 96 bytes

- BAT: Background attribute table: a table of 768 bytes holding one ZX Spectrum
  attribute byte per screen cell.  `jsp_redraw()` paints the BAT attribute for
  every dirty cell, so a sprite's colour disappears automatically when the
  sprite leaves the cell - 768 bytes

There are **no per-sprite drawing buffers**: a sprite holds only a small
descriptor and composites straight to the screen during `jsp_redraw()`.
The five JSP tables are packed into one contiguous block (see the memory
map below), with the program area and free RAM contiguous below it.

## SPRITE DEFINITIONS

- Normal graphic definition ( M x N chars ), MASK2 (mask+graphics) or LOAD1
  (graphics only) format.

- A sprite descriptor (`struct jsp_sprite_s`, ~13 bytes) holding size,
  position, flags, pixel pointer, type, colour and an optional clip rect.
  No drawing buffer is needed: sprites composite straight to the screen.

- All sprites that must appear on screen are kept in a small bounded
  **registry** (`JSP_SPRITE_REGISTRY_SIZE`).  A sprite registers itself the
  first time it is drawn or moved; `jsp_redraw()` walks the registry in
  registration order, which is the back-to-front z-order.

## WORKFLOW FOR DRAWING TILES

- For drawing a _background_ tile, store its address (pointer to 8-byte
  data) in the BTT, clear the FTT bit and mark the cell dirty.

- For drawing a _foreground_ tile, store its address in the BTT, set the
  FTT bit and mark the cell dirty.

- For removing a tile, just draw the default tile as a background tile on
  the same position.

All tile operations are deferred: the actual screen drawing happens in the
next `jsp_redraw()`.

## WORKFLOW FOR DRAWING / MOVING SPRITES (deferred)

Drawing, moving and parking never touch the screen.  They update the sprite
descriptor and mark cells dirty:

- `jsp_draw_sprite(sp,x,y)` — register the sprite, set position, set
  `active`, mark the new footprint dirty (intersected with the clip rect).

- `jsp_move_sprite(sp,x,y)` — mark the **old** footprint dirty (unclipped),
  reposition, mark the **new** footprint dirty (clipped).

- `jsp_sprite_park(sp)` — mark the footprint dirty, clear `active`.

The footprint of a sprite is `(rows+1) x (cols+1)` cells (the `+1` accounts
for sub-cell pixel shifting).

## WORKFLOW FOR REDRAWING THE SCREEN — `jsp_redraw()`

`jsp_redraw()` is **single-pass and flicker-free**: each screen cell is
written exactly once per frame, straight to its final `background+sprites`
content.  The screen is never left in an intermediate "background only"
state, so sprites do not flicker — every screen write is a plain store of
final pixels, never an erase.

It runs in three steps:

**1. Per-frame precompute — `jsp_redraw_begin()`.**  Walks the sprite
registry and, for every *active* sprite, fills one `jsp_sprite_frame`
entry in `jsp_frame_sprites[]`: the sprite's footprint rectangle
(`r0,c0,r1,c1`) plus the constants the compositor needs (rotation-table
selector, pixel base pointer, row stride, cell size, colour).  Doing this
once per frame keeps it out of the per-cell path.

**2. The DTT walk (assembly, `lib/jsp_redraw.asm`).**  Walks the DTT byte
by byte, skipping zero bytes (the common case) and, more importantly,
skipping them without losing place — the 96 *groups* are always iterated
in order even though most are clean.  For each dirty cell:

- **foreground cell, or no active sprite covers it** — the common case
  (the whole initial redraw, every sprite trail): blit the cell's BTT tile
  and BAT attribute straight to the screen.  No scratch buffer, no copy.
- **a sprite covers it** — hand the cell to the C helper
  `jsp_redraw_covered_cell()`: it seeds an 8-byte scratch with the BTT
  tile, composites every covering frame-sprite in z-order (registration
  order, back to front), merges sprite colour into the attribute, and
  writes the cell with a single store.

Coverage is a plain rectangle test against the precomputed
`jsp_frame_sprites[]` entries.

**3.** The DTT is cleared for the next frame.

Compositing in z-order means sprite B over sprite A produces `bg+A+B`.
Foreground cells keep the plain background tile, so sprites pass *behind*
them.  Only dirty cells are touched, so a stationary sprite whose cells
are not invalidated keeps its pixels (differential update); if another
sprite moves through one of its cells, that cell becomes dirty and both
sprites are recomposited there.

The DTT-walk hot loop is assembly; the per-frame precompute and the
per-covered-cell compositing are C (`lib/jsp_composite.c`).  The actual
pixel rotation/masking is still done by the original SP1 `sp1_draw_*`
assembler kernels.

## MEMORY MAPS

Be careful when using JSP with the standard ROM interrupt routine, some of its routines use the IY register!

The five JSP tables form one contiguous block (ROTTBL + BTT + DTT + FTT +
BAT); the program area and free RAM sit contiguously below the block.

Where that block sits is a **compile-time choice**, selected by defining
`JSPDATA_SLOT3` or `JSPDATA_SLOT2`.  The names refer to the Z80's 16K
memory slots — slot 2 is `8000-BFFF`, slot 3 is `C000-FFFF`.  Both
layouts are valid in 48K and 128K mode without restriction — the flag
does not select a "machine mode", it only governs where the JSP data is
located in memory.  `JSPDATA_SLOT2` exists so that slot 3 — the window
the 128K machine pages its banks into — can be kept entirely free of JSP
data, leaving it available for bank switching.

**JSPDATA_SLOT3** (the default) places the block in slot 3, the top 16K
(`C000-FFFF`):

| Range     | Contents                                          |
|-----------|---------------------------------------------------|
| F200-FFFF | Rotation tables (3.5 kB, 256-aligned)             |
| EC00-F1FF | Background Tiles Table, BTT (1.5 kB, 256-aligned) |
| EBA0-EBFF | Dirty Tiles Table, DTT (96 bytes)                 |
| EB40-EB9F | Foreground Tiles Table, FTT (96 bytes)            |
| E840-EB3F | Background Attribute Table, BAT (768 bytes)       |
| 5D00-E83F | free for program code and data                    |

**JSPDATA_SLOT2** places the same block in slot 2 (`8000-BFFF`), leaving
slot 3 (`C000-FFFF`) free of JSP data:

| Range     | Contents                                          |
|-----------|---------------------------------------------------|
| B200-BFFF | Rotation tables (3.5 kB, 256-aligned)             |
| AC00-B1FF | Background Tiles Table, BTT (1.5 kB, 256-aligned) |
| ABA0-ABFF | Dirty Tiles Table, DTT (96 bytes)                 |
| AB40-AB9F | Foreground Tiles Table, FTT (96 bytes)            |
| A840-AB3F | Background Attribute Table, BAT (768 bytes)       |
| 5D00-A83F | free for program code and data                    |

- These structures should not be in contended memory, since they must be checked at top speed.

## AMSTRAD CPC TARGET

JSP also targets the Amstrad CPC.  The **high-level engine is unchanged** — the
same deferred-recompositing model, the same four tables, the same sprite
registry, per-frame precompute and covered-cell compositor flow.  Only a thin
**platform layer** is swapped (`lib/cpc/` instead of `lib/zx/`), selected by the
`JSP_TARGET_CPC` umbrella guard plus exactly one `CPC_MODE*` mode guard.  The
full design lives in `doc/legacy/CPC-TARGET-PLAN.md`; the per-mode asset byte formats in
`doc/CPC-ASSETS-FORMAT.md`.  Three things genuinely differ from the ZX, because
the hardware does:

**1. Screen layout.**  The CPC framebuffer is 80 bytes/line × 200 lines = 16 KB
at `C000-FFFF` in **all** modes; the mode only changes how many pixels a byte
holds (8/4/2 for Mode 2/1/0).  A scan-line `y` address is
`0xC000 + (y & 7) * 0x800 + (y >> 3) * 80`, so within an 8-line cell the pixel
lines step by **`+0x800`** (not the ZX `+0x100`).  The cell grid depends on the
cell model (`doc/CPC-TILE-SIZE-DESIGN.md`): **by default JSP uses the pixel-cell
model** (8×8-px cells → 80×25 / 40×25 / 20×25 in Mode 2/1/0); the legacy
byte-cell model (`JSP_CELL_MODEL=byte`) is 80×25 in every mode (a cell is 8 lines
× 1 byte, 8/4/2 px wide).  In Mode 2 the two coincide.  There is no thirds
layout: `rd_rowtab` is 25
entries of `0xC000 + row*80`, and the redraw walks an explicit `(row, col0)`
running counter (80 ÷ 8 = 10 groups/row is not a power of two).

**2. Colour — no attribute RAM (the honest asterisk).**  The CPC has no
attribute byte per cell: colour is encoded in the **pixel bits themselves**
(palette index per pixel, planar-in-byte), interpreted through the gate-array
palette.  So on CPC the **BAT is dropped**, `jsp_apply_sprite_color()` is a no-op,
and the redraw paths skip the attribute store — colour is baked into the
sprite/tile pixel data by the asset converter (`tools/cpcgfx.pl`).  Mode 0 (16)
and Mode 1 (4) carry a real per-pixel palette index; Mode 2 (1 bpp) is
monochrome-per-screen (ink/paper from palette registers), exactly like
ZX-without-attributes.  A CPC test harness must therefore **set the screen mode
and program the palette before the first `jsp_redraw()`** (the firmware boots in
Mode 1) — kept in the test `main`, never in the library.

**3. Coordinates + per-mode shift.**  X is widened to 16-bit on CPC
(`jsp_xcoord_t`; Mode 2 is 640 px wide), Y stays 8-bit.  The horizontal split is
`byte_col = x >> log2(ppb)`, `shift = x & (ppb-1)` with `ppb` = 8/4/2.  The
sub-byte shift lives entirely in `jsp_rottbl` (mode-selected encoding: Mode 2
1bpp-linear / Mode 1 nibble-plane / Mode 0 odd-even interleave), so the composite
kernels are **shared and table-driven** across modes.  The **FAST** modes
(`CPC_MODE2/1/0_FAST`) force `shift = 0` (byte-aligned positioning, 8/4/2-px
granularity), build no shift table, and **compile the six rotating composite
kernels out** — the covered-cell compositor calls the no-rotate kernel directly
(guarded by the OR of the `CPC_MODE*_FAST` flags), so a FAST binary carries
neither the rotation table nor the rotating kernel code (~1 KB), at a coarser
horizontal granularity.

**CPC memory map (largest case — Mode 2; all modes packed below the `C000`
screen).**  Sizes: ROTTBL ≤ 3584 B (Mode 2; Mode 1 1536, Mode 0 512, FAST 0),
BTT 4000, DTT 250, FTT 250, BAT 2000 (still allocated but unused, §6).  These
are the Mode-2 sizes; under the default pixel-cell model Mode 1 has half the
cells and Mode 0 a quarter, so BTT/DTT/FTT shrink accordingly.  Block `9800-BFFF`:

| Range     | Contents                                                |
|-----------|---------------------------------------------------------|
| B200-BFFF | Rotation tables (Mode 2 size; smaller/empty per mode)   |
| A200-B19F | Background Tiles Table, BTT (4000 B)                    |
| A100-A1F9 | Dirty Tiles Table, DTT (250 bytes)                      |
| A000-A0F9 | Foreground Tiles Table, FTT (250 bytes)                 |
| 9800-9FCF | Background Attribute Table, BAT (2000 B, unused)        |
| below     | program code/data + stack (forced `REGISTER_SP=0x9800`) |

The firmware-default stack sits high (~`B000-BFFF`) and would overlap the
rottbl, so the CPC build forces `REGISTER_SP=0x9800` (stack grows down below the
block).  Both ROMs are kept off (code at `0x1200`, in the lower-ROM region).

**Build / verify.**  The Makefile drives the matrix: `make cpc-run-test
TEST=sprite MODE=<2|1|1_mono|0|2_fast|0_fast|1_fast>` builds and screenshots one
config in cap32; `make cpc-tests` builds every config and runs the regressions.
There is **no headless T-state profiler** for the CPC
(the JNEXT magic-port/heatmap path is ZX-only): CPC performance is eyeballed /
wall-clock-timed via the `caprice-testing` skill (`tools/cap32-shot.sh`, cap32
headless in a private Xvfb) until a CPC profiling path exists.
