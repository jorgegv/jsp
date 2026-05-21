# ENGINE NOTES

A "tile" is an 8x8 UDG stored top to down in memory (8 consecutive bytes)

JSP uses a **deferred recompositing** model: drawing/moving a sprite never
touches the screen — it only updates sprite state and marks cells dirty.
`jsp_redraw()` then recomputes the affected part of the screen from the
background tables plus the *live* sprite state.  Nothing is "baked": the
displayed image is recomputed each frame, so overlapping, independently
moving and animated sprites all render correctly.  This matches the SP1
sprite library's observable semantics (see `doc/RECOMPOSITE-REDESIGN.md`
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

There is **no DRT** (Drawing Records Table) and there are **no per-sprite
drawing buffers (PDB)** any more — both belonged to the old baking model and
were removed by the recompositing redesign.  The 1.5 KB formerly used by the
DRT is now free.

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

`jsp_redraw()` is **single-pass and flicker-free**.  It walks the DTT byte
by byte (skipping zero bytes, the common case) and, for each dirty cell,
assembles the final image in an 8-byte scratch buffer and writes it to the
screen with **one** store:

1. copy the cell's BTT tile into the scratch (the background);
2. unless the cell is a foreground cell, composite — in z-order
   (registry/registration order, back to front) — every active sprite
   whose footprint covers the cell, intersected with its clip rect;
3. store the scratch to the screen cell, and the BAT attribute (merged
   with any covering sprite's colour) to attribute memory.

A cell is therefore written exactly once per frame, straight to its final
`background + sprites` content.  The screen is **never** left in an
intermediate "background only" state, so sprites do not flicker — every
screen write is a plain store of final pixels, never an erase.

Compositing in z-order means sprite B drawn over sprite A produces
`bg+A+B`.  Foreground cells are left as the plain background tile, so
sprites pass *behind* them.  Only dirty cells are touched, so a stationary
sprite whose cells are not invalidated keeps its pixels (differential
update); if another sprite moves through one of its cells, that cell
becomes dirty and both sprites are recomposited there.

**Finally**, the DTT is cleared for the next frame.

The redraw and compositing code is a correct, readable C implementation;
it can be optimised to assembly later if profiling shows it is needed.

## MEMORY MAPS

Be careful when using JSP with the standard ROM interrupt routine, some of its routines use the IY register!

**48K MODE**

| Range     | Contents                                          |
|-----------|---------------------------------------------------|
| F200-FFFF | Rotation tables (3.5 kB, 256-aligned)             |
| EC00-F199 | Background Tiles Table, BTT (1.5 kB, 256-aligned) |
| E600-EBFF | free (1.5 kB) — was Drawing Records Table, DRT    |
| E5A0-E5FF | Dirty Tiles Table, DTT (96 bytes)                 |
| E540-E59F | Foreground Tiles Table, FTT (96 bytes)            |
| E240-E53F | Background Attribute Table, BAT (768 bytes)       |
| 5D00-E23F | free for program code and data                   |

- These structures should not be in contended memory, since they must be checked at top speed.

**128K MODE**

The layout is similar to 48K mode, but down 16K, in order to free up the C000-FFFF range for banking:

| Range     | Contents                                          |
|-----------|---------------------------------------------------|
| B200-BFFF | Rotation tables (3.5 kB, 256-aligned)             |
| AC00-B199 | Background Tiles Table, BTT (1.5 kB, 256-aligned) |
| A600-ABFF | free (1.5 kB) — was Drawing Records Table, DRT    |
| A5A0-A5FF | Dirty Tiles Table, DTT (96 bytes)                 |
| A540-A59F | Foreground Tiles Table, FTT (96 bytes)            |
| A240-A53F | Background Attribute Table, BAT (768 bytes)       |
| 5D00-A23F | free for program code and data                   |

- These structures should not be in contended memory, since they must be checked at top speed.
