# JSP RECOMPOSITE REDESIGN — Analysis, Design & Implementation Handover

**Status:** DESIGN APPROVED — implementation pending (to be done in a new session in this repository).
**Date:** 2026-05-19.
**Scope:** Redesign of the JSP sprite/redraw model so JSP matches the SP1 sprite
library's observable semantics, fixing the sprite-overlap / differential-update
defects discovered during RAGE1's generic-sprite-library integration — while
keeping (in fact improving) JSP's memory advantage over SP1.

---

## 1. Executive summary

JSP currently *bakes*: each sprite's Private Drawing Buffer (PDB) holds a
composited `background+sprite` image, and the per-cell Drawing Records Table
(`DRT`) holds a single pointer to "what is displayed". This model cannot
correctly represent overlapping sprites, independent sprite movement, sprite
animation, or sprite deletion. It is the root cause of the RAGE1 `minimal_jsp`
test game rendering incorrectly (hero never appears).

SP1 is correct because it **never bakes**: each cell keeps `slist`, a *reference
list* of the sprite-chars occupying it, and re-composites from *live* sprite
graphics on every redraw. The cost of SP1's correctness is memory (~11.8 KB of
fixed data structures).

This document specifies a redesign — **deferred two/three-pass recompositing** —
that gives JSP SP1-equivalent correctness, requires **zero changes to RAGE1
logic**, and makes JSP's memory footprint *smaller* than it is today (it removes
`DRT` and all per-sprite PDBs). Projected JSP footprint after the redesign is
roughly **half** of SP1's.

---

## 2. Background and how the defect surfaced

### 2.1 Context

RAGE1 (a ZX Spectrum game engine) was refactored to abstract its sprite backend
behind a generic `gfx_*` API, so it can use either SP1 (its original, golden,
battle-tested backend) or JSP (this library, designed for a much smaller memory
footprint — see `doc/SP1-COMPARISON.md`).

A test game, `games/minimal_jsp`, was created: an exact copy of `games/minimal`
with only `SPRITE_ENGINE JSP` added to the game configuration. With identical
game data, `minimal_jsp` (JSP) **must** render pixel-identically to `minimal`
(SP1). It does not.

### 2.2 Symptoms observed (RAGE1 `minimal_jsp`, JNEXT emulator, 48K build)

1. **Stale loader artifacts** — leftover screen content from the BASIC/asm
   loader was not cleared. *Cause:* `jsp_init` only sets up internal tables; it
   never touches the screen (DFILE/attributes). SP1's `sp1_Initialize` clears
   DFILE via `SP1_IFLAG_OVERWRITE_DFILE`. *Resolution:* this is **fixed by the
   redesign itself** — Pass 1 of the new `jsp_redraw` (§7.5) repaints every
   invalidated cell, so the existing `gfx_init` sequence
   `gfx_invalidate(&full_screen); gfx_update()` clears the screen correctly. No
   special-case code in `jsp_init` is needed; `jsp_init` stays as-is.
2. **Hero sprite never appears.** Pixel-diff against the SP1 baseline: 27,993
   differing pixels initially; after eliminating the loader artifacts, 280
   differing pixels — the hero figure plus small sprite fragments. This is the
   core defect and the subject of this redesign.

---

## 3. Current JSP architecture (the "as-is")

### 3.1 Per-cell tables (768 cells, 32×24 screen), from `lib/jsp_data.c`

| Table | Type | Size | Purpose |
|-------|------|------|---------|
| `jsp_rottbl` | byte[7·2·256] | 3584 B | horizontal pixel rotation tables |
| `jsp_btt` | ptr[768] | 1536 B | Background Tiles Table — bg tile graphic per cell |
| `jsp_drt` | ptr[768] | 1536 B | Drawing Records Table — pointer to the *final* (composited) tile per cell |
| `jsp_dtt` | bit[768] | 96 B | Dirty Tiles Table — cells needing redraw |
| `jsp_ftt` | bit[768] | 96 B | Foreground Tiles Table — cells whose tile is above sprites |
| `jsp_bat` | byte[768] | 768 B | Background Attribute Table — bg attribute per cell |
| `jsp_tile_table` | ptr[256] | 512 B | tile-code → graphic lookup |

Fixed JSP region (48K map, `jspdata`): `0xE240–0xFFFF` = **7616 B**
(`rottbl+btt+drt+dtt+ftt+bat`); plus `jsp_tile_table` 512 B elsewhere.

### 3.2 Per-sprite storage

- `struct jsp_sprite_s` (`include/jsp.h`): **13 bytes** — `rows, cols, xpos,
  ypos, flags{initialized,parked}, pixels*, pdbuf*, type_ptr*, color,
  color_mask`.
- **PDB** (Private Drawing Buffer): `(rows+1)·(cols+1)·8` bytes per sprite. For
  RAGE1's 16×16 hero (2×2 cells) the PDB is `3·3·8 = 72 B`.

### 3.3 Draw / move / redraw flow (verified against `lib/jsp_sprite.asm`,
`lib/jsp_redraw.asm`, `lib/jsp_sprite_c.c`)

- `jsp_draw_sprite(sp,x,y)`:
  1. fills the sprite's PDB with a **copy** of the current `jsp_drt[]` content
     for each covered cell (the "background" — which may itself be another
     sprite's PDB);
  2. composites the sprite pixels **into that same PDB** (single buffer — the
     background snapshot is overwritten by the composite);
  3. sets `jsp_drt[cell] = &PDB[...]` for each covered cell and marks the cells
     dirty.
- `jsp_move_sprite(sp,x,y)`: marks the sprite's **old** footprint dirty, then
  calls `jsp_draw_sprite` at the new position.
- `jsp_sprite_park(sp)`: marks the sprite's footprint dirty, sets `parked`.
- `jsp_redraw()`: walks `DTT`; for each dirty non-foreground cell it draws
  `*jsp_drt[cell]` to screen, conditionally restores the `BAT` attribute, marks
  the cell clean, **and resets `jsp_drt[cell] = jsp_btt[cell]`**.

The two facts in bold — *single-buffer PDB* and *`jsp_redraw` resets DRT to
background* — are the heart of the defect.

---

## 4. SP1 ↔ JSP semantic mismatch analysis

SP1 is the **golden reference**: RAGE1 ships real games on SP1 and works
perfectly. JSP must match SP1's observable behaviour. The analysis below was
produced by a code-reading pass over both libraries and then **independently
verified** by a second, separate review pass. All six mismatches were confirmed
CORRECT against source; one severity was corrected (overstated).

### 4.1 API mapping (RAGE1 `gfx_*` → backends)

| `gfx_*` op | SP1 symbol | JSP symbol |
|---|---|---|
| `gfx_init` | `sp1_Initialize` + invalidate + update | `jsp_init` + `jsp_sprite_pool_init` + invalidate + update |
| `gfx_invalidate` | `sp1_Invalidate` | `jsp_invalidate_rect` |
| `gfx_update` | `sp1_UpdateNow` | `jsp_redraw` |
| `gfx_sprite_create` | `sp1_CreateSpr` + `sp1_AddColSpr` loop | `jsp_sprite_alloc` |
| `gfx_sprite_destroy` | `sp1_DeleteSpr` | `jsp_sprite_free` |
| `gfx_sprite_set_color` | `sp1_IterateSprChar` + callback | `jsp_sprite_set_color` |
| `gfx_sprite_set_threshold` | sets `xthresh`/`ythresh` | no-op |
| `gfx_sprite_move_pixel` | `sp1_MoveSprPix` | `gfx_jsp_move_sprite_clipped` → `jsp_move_sprite_mask2_frame` |
| `gfx_sprite_move_cell` | `sp1_MoveSprAbs(...,r,c,0,0)` | `gfx_jsp_move_sprite_clipped(...,c·8,r·8)` |
| `gfx_sprite_get_row/col/width/height` | struct fields | `ypos/8`, `xpos/8`, `cols`, `rows` |
| `gfx_tile_put` | `sp1_PrintAtInv` | `jsp_tile_put` |
| `gfx_tile_register` | `sp1_TileEntry` | `jsp_tile_register` |
| `gfx_clear_rect` | `sp1_ClearRectInv` | `jsp_clear_rect` |
| `gfx_print_set_pos` | `sp1_SetPrintPos` | `jsp_print_set_pos` |
| `gfx_print_string` | `sp1_PrintString` | `jsp_print_string` |

### 4.2 The six mismatches

**#1 — Sprite redraw lifecycle (CRITICAL).** *Verified CORRECT.*
SP1: each `sp1_update` cell carries `slist`, a persistent reference list of the
sprite-chars in it; built by `sp1_MoveSprAbs`, consumed by `SP1DrawUpdateStruct`
on every redraw; membership persists across frames until the sprite moves away.
JSP: a sprite's presence in a cell is recorded *only* as `jsp_drt[cell]→PDB`,
and `jsp_redraw` resets `jsp_drt[cell]=jsp_btt[cell]` after drawing each dirty
cell — destroying that record. Background draws (`jsp_draw_background_tile`)
also overwrite `DRT` immediately.
*Consequence:* RAGE1 only re-issues a sprite move when the sprite changes
position (correct for SP1, whose `slist` is persistent). Under JSP the hero is
drawn once, then `map_draw_screen` repaints background over those cells / the
next `jsp_redraw` resets `DRT`, and the hero is never recomposited. **This is
the missing-hero bug.** A stationary sprite is also erased the moment anything
re-invalidates its cells.

**#2 — Sprite clipping (CRITICAL).** *Verified CORRECT.*
SP1 `sp1_MoveSprAbs` clips **per-cell** (in-rect cells drawn, out-of-rect cells
suppressed). JSP `jsp_sprite_in_rect` + `gfx_jsp_move_sprite_clipped` **park the
entire sprite** if its bounding box is not fully inside the clip rectangle.
*Consequence:* a sprite straddling the edge of `game_area` is partially visible
under SP1 but vanishes completely under JSP.

**#3 — `gfx_sprite_get_width/height` field discrepancy (LOW — severity
corrected from MODERATE).** *Verified: mechanism CORRECT, severity overstated.*
SP1 builds a sprite `(rows+1)×(cols+1)` cells and its `width`/`height` fields
include the `+1`; JSP stores raw `rows`/`cols`. Only one live caller exists
(`hero_check_tiles_below`); SP1's value was already arguably one-too-large per
axis. Not a crash or render bug.

**#4 — Sprite colour not reapplied per redraw (MODERATE; compounds #1).**
*Verified CORRECT.*
SP1 stores colour per `sp1_cs` cell and recomposites it on every cell redraw.
JSP `jsp_sprite_set_color` only stores `sp->color`; `jsp_apply_sprite_color`
runs only from the move/draw path, never from `jsp_redraw`. A sprite repainted
by `jsp_redraw` (not by a move) loses its colour.

**#5 — Immediate vs deferred attribute writes (MODERATE).** *Verified CORRECT.*
SP1 `sp1_PrintAtInv`/`sp1_ClearRectInv` defer all drawing (tile + colour) to the
next `gfx_update`. JSP `jsp_tile_put`/`jsp_clear_rect` write the colour byte to
screen `0x5800` immediately, pixels deferred — a one-frame colour/pixel skew.

**#6 — Print-string control codes (MODERATE).** *Verified CORRECT.*
SP1 `sp1_PrintString` interprets ~31 control codes; JSP `jsp_print_string`
silently skips every byte `<32` or `>127` (plain ASCII only). Engine-internal
RAGE1 strings are plain, so the live impact depends on game data. Also verify
all RAGE1 print-area rects start at cell (0,0): SP1's print cursor is
bounds-relative, JSP's is absolute.

### 4.3 Independent verification — additional findings

The verification pass confirmed all six and noted:
- #1 and #4 **compound**: even in the window where a sprite is still
  `DRT`-registered, `jsp_redraw` redraws it with `jsp_draw_screen_tile` (no
  attribute) and skips the `BAT` restore for sprite cells — so a
  `jsp_redraw`-driven repaint loses the sprite's colour too.
- `jsp_clear_rect` (via `jsp_draw_background_tile`) destroys a sprite's `DRT`
  registration **immediately**, an extra instance of the #1 mechanism.
- `jsp_redraw`'s reset is nuanced (foreground cells special-cased via
  `restore_fg_cell`; `BAT` restore is conditional) but the verdict stands.

**The redesign in this document fixes #1, #2, #4, #5 and the parking bug
together.** #3 and #6 are minor and addressed separately (see §11).

---

## 5. Root cause — the baking model

### 5.1 Overlapping-sprite trace (current model)

Sprites A then B drawn over a shared cell:
- Draw A: `PDB_A ←` copy of background; A composited in → `PDB_A = bg+A`;
  `DRT[cell]→PDB_A`.
- Draw B: `PDB_B ←` copy of `*DRT[cell] = PDB_A` content = `bg+A`; B composited
  in → `PDB_B = bg+A+B`; `DRT[cell]→PDB_B`.

The static composite is correct. But:
- The PDB is a **single buffer**: B's snapshot of `bg+A` is overwritten by
  `bg+A+B`. B keeps no clean record of what was beneath it.
- `jsp_redraw` resets `DRT` to `jsp_btt` (the *plain tile background*), never to
  the under-sprite layer.
- There is no per-cell record of *which* sprites are stacked, or in what order.

### 5.2 Why a Saved Background Buffer (SVB) does not fix it

A proposed refinement: give each sprite a second buffer (SVB) holding a clean
copy of the under-layer at draw time. This was analysed and rejected:

- It fixes **only** reverse-order deletion of a **static** stack (nothing moves
  or animates between the draws and the deletes).
- It does **not** fix independent movement/animation: the SVB is a *snapshot*.
  If a lower sprite moves while an upper sprite covers it, the upper sprite's
  SVB *and* PDB still have the lower sprite baked in. Trace: A under B, A moves
  away — no buffer anywhere contains the required `bg+B`; every buffer at or
  above A's layer has stale A baked in. No deletion order recovers this.
- It doubles per-sprite buffer RAM.

**The defect is baking itself.** Any snapshot scheme breaks under independent
motion, because a snapshot of layer N becomes wrong as soon as layer `<N`
changes. The only correct shape of solution is SP1's: store *references*, never
copies, and re-composite from *live* data every redraw.

---

## 6. The redesign — deferred two/three-pass recompositing

### 6.1 Key insight

SP1 maintains a per-cell `slist` because it supports an unbounded number of
sprites and cannot afford to scan them all per cell. **JSP's sprite pool is
small and bounded** (`GFX_JSP_MAX_SPRITES`, typically 5–16). JSP can therefore
afford to iterate its entire pool during redraw, and needs **no per-cell sprite
data structure at all**.

### 6.2 Data model — what is kept, what is dropped

| Table | Fate | Reason |
|-------|------|--------|
| `jsp_btt` | **keep** (1536 B) | background tile per cell — Pass 1 source |
| `jsp_bat` | **keep** (768 B) | background attribute per cell — Pass 1 source |
| `jsp_dtt` | **keep** (96 B) | dirty bits drive both passes |
| `jsp_ftt` | keep or drop (96 B) | only if foreground tiles are used — see §11 |
| `jsp_rottbl` | **keep** (3584 B) | rotation tables — unchanged |
| `jsp_tile_table` | **keep** (512 B) | tile-code lookup — unchanged |
| `jsp_drt` | **DROP** (−1536 B) | no "current composite" to track; recomputed |
| per-sprite PDB | **DROP** (−`(r+1)(c+1)·8`/sprite) | sprites composite straight to screen |

### 6.3 New `struct jsp_sprite_s`

Drop `pdbuf` (no PDB). Add `clip` (clip-rect pointer, set per move — matches
SP1's per-call clip) and `z` (z-order byte). Result ≈ **14 bytes** (was 13):

```
rows, cols, xpos, ypos,                  (4)
flags{ initialized, active },            (1)   "parked" → "active" (composite or not)
pixels*,                                 (2)   current frame graphic
type_ptr*,                               (2)   MASK2 / LOAD1 draw dispatch
color, color_mask,                       (2)
clip*,                                   (2)   clip rect for this sprite
z                                        (1)   z-order: lower = behind
```

### 6.4 Deferred draw / move / park

Drawing/moving no longer touches the screen. They update sprite state and mark
cells dirty (this also fixes mismatch #5 — deferred, like SP1):

- `jsp_draw_sprite(sp,x,y)` / first draw / unpark: set `xpos,ypos`, `active=1`;
  mark the new footprint cells dirty (intersected with `clip`).
- `jsp_move_sprite(sp,x,y)`: mark the **old** footprint dirty; update
  `xpos,ypos,pixels`; mark the **new** footprint dirty (∩ `clip`).
- `jsp_sprite_park(sp)`: mark the footprint dirty; `active=0`.

### 6.5 The new `jsp_redraw` — three passes over dirty cells

```
PASS 1 — background
  for each DIRTY cell:
      blit jsp_btt[cell] (8 bytes) to the screen cell
      write jsp_bat[cell] to attribute memory

PASS 2 — sprites
  for each ACTIVE sprite, in z-order (ascending z = back to front):
      for each cell of the sprite's (rows+1)x(cols+1) footprint:
          if cell is DIRTY and inside the sprite's clip rect:
              read the screen cell into an 8-byte scratch
              composite the sprite's graphic slice into the scratch
                  (existing sp1_draw_mask2 / _lb / _rb / load1 primitives)
              write the scratch back to the screen cell
              if sprite has colour: merge attr = (scr_attr & mask) | sprite_attr

PASS 3 — foreground tiles            (only if FTT is retained — see §11)
  for each DIRTY foreground cell: draw the foreground tile over everything

FINALLY
  clear DTT (jsp_memzero(jsp_dtt, 96))
```

Pass 1 clears every dirty cell to clean background. Pass 2 re-composites — in
z-order, accumulating directly on the screen (read-modify-write per cell, so
sprite B over sprite A reads `bg+A` and produces `bg+A+B`). Nothing is stored
baked; the displayed image is recomputed from live sprite state each redraw,
exactly as SP1 does via `slist`.

Implementation note: Pass 2's read-screen → scratch → composite → write-screen
keeps the existing draw primitives unchanged (they operate on a contiguous
8-byte buffer). JSP already has `jsp_draw_screen_tile` for the write; a
symmetric "read screen cell into buffer" routine is the only new primitive
needed.

### 6.6 Correctness walkthrough

| Scenario | New-model result |
|---|---|
| A under B, B moves away | shared cell dirty → P1 bg → P2 A composites; B's footprint no longer covers it → `bg+A` ✓ |
| A under B, A moves away | shared cell dirty → P2 A's footprint no longer covers, B does → `bg+B` ✓ |
| A animates (new frame) in place under B | A's cells dirty → P2 composites A(new) then B → `bg+A'+B` ✓ |
| Park/delete B | B's cells dirty, B inactive → P1 bg, P2 skips B → `bg+A` ✓ (parking works — currently broken) |
| Sprite straddling clip edge | P2 composites only in-clip dirty cells → per-cell clipping ✓ (fixes #2) |
| Stationary sprite, nothing nearby moves | its cells never dirty → P2 composites nothing → pixels persist ✓ (differential) |
| Stationary sprite, an enemy passes through its cell | enemy's move dirties the shared cell → P2 recomposites the stationary sprite too ✓ |
| Background tile changes under sprites | tile cell dirty, BTT updated → P1 new bg, P2 covering sprites recomposite ✓ |

**Zero RAGE1 changes.** RAGE1's "redraw the hero only when it moves"
(`F_LOOP_REDRAW_HERO`) optimisation stays valid: a stationary sprite whose cells
are invalidated by another sprite is recomposited automatically by Pass 2 —
RAGE1 never needs to know. This is precisely SP1's contract.

### 6.7 z-order, colour, clipping

- **z-order:** Pass 2 iterates sprites back-to-front. Simplest: pool index = z.
  An explicit `z` byte (in the struct, §6.3) is recommended for flexibility; it
  costs 1 byte/sprite. Decide during implementation (see §11).
- **Colour:** applied in Pass 2 as each sprite composites — so colour is
  reapplied on every redraw of the cell (fixes #4). Multiple coloured sprites
  merge in z-order.
- **Clipping:** per-cell in Pass 2 (and at dirty-marking time in move/draw).
  Out-of-clip cells are simply never composited (fixes #2).

---

## 7. Concrete implementation draft (pseudocode)

```c
/* ---- jsp_sprite.asm : deferred, no drawing ---- */

void jsp_draw_sprite(sp, x, y) {            /* first draw / unpark */
    sp->xpos = x; sp->ypos = y;
    sp->flags.active = 1;
    mark_footprint_dirty(sp, /*clip=*/sp->clip);
}

void jsp_move_sprite(sp, x, y) {
    mark_footprint_dirty(sp, /*clip=*/NULL);   /* OLD position, unclipped */
    sp->xpos = x; sp->ypos = y;
    mark_footprint_dirty(sp, /*clip=*/sp->clip);   /* NEW position, clipped */
}

void jsp_sprite_park(sp) {
    mark_footprint_dirty(sp, NULL);
    sp->flags.active = 0;
}

/* mark all cells of sp's (rows+1)x(cols+1) footprint dirty;
   if clip != NULL, skip cells outside clip */
static void mark_footprint_dirty(sp, clip) {
    r0 = sp->ypos / 8;  c0 = sp->xpos / 8;
    for (i = 0; i <= sp->rows; i++)
        for (j = 0; j <= sp->cols; j++)
            if (clip == NULL || cell_in_rect(r0+i, c0+j, clip))
                jsp_dtt_mark_dirty(r0+i, c0+j);
}

/* ---- jsp_redraw.asm : three passes ---- */

void jsp_redraw(void) {
    /* PASS 1: background */
    for (cell = 0; cell < 768; cell++)
        if (dtt_is_dirty(cell)) {
            jsp_draw_screen_tile(cell, jsp_btt[cell]);
            screen_attr[cell] = jsp_bat[cell];
        }

    /* PASS 2: sprites, z-order */
    for each active sprite sp in pool, ascending z:
        r0 = sp->ypos/8; c0 = sp->xpos/8;
        for (i = 0; i <= sp->rows; i++)
          for (j = 0; j <= sp->cols; j++) {
            cell = (r0+i)*32 + (c0+j);
            if (!dtt_is_dirty(cell))                  continue;
            if (sp->clip && !cell_in_rect(r0+i,c0+j,sp->clip)) continue;
            read_screen_cell(cell, scratch8);
            composite_sprite_cell(sp, i, j, scratch8); /* sp1_draw_mask2 etc. */
            jsp_draw_screen_tile(cell, scratch8);
            if (sp->color)
                screen_attr[cell] =
                    (screen_attr[cell] & sp->color_mask) | sp->color;
        }

    /* PASS 3: foreground tiles — only if FTT retained */

    jsp_memzero(jsp_dtt, 96);
}
```

`composite_sprite_cell` reuses the existing rotation logic from the current
`jsp_draw_sprite` (the left-border / middle / right-border `sp1_draw_*`
primitives selected via `type_ptr`), applied to a single footprint cell instead
of the whole sprite. The total compositing work is unchanged; it is merely
driven by the redraw loop rather than baked at move time.

---

## 8. Memory analysis

### 8.1 Per-cell screen bookkeeping (768 cells) — the dominant term

| Engine | Per-cell data | × 768 |
|---|---|---|
| **SP1** | `sp1_update` = 10 B (`nload, colour, tile, slist, ulist, screen`) | **7680 B** |
| **JSP current** | BTT 2 + DRT 2 + BAT 1 + DTT ⅛ + FTT ⅛ ≈ 5.25 B | **4032 B** |
| **JSP new** | BTT 2 + BAT 1 + DTT ⅛ + FTT ⅛ ≈ 3.25 B | **2496 B** |

SP1's `sp1_update` embeds the slist head, the update-list link and the screen
pointer in every cell. JSP keeps compact parallel arrays; the redesign drops
`DRT`, taking per-cell data to **a third** of SP1's.

### 8.2 Per sprite

| Engine | 2×2-cell sprite (e.g. RAGE1's 16×16 hero) |
|---|---|
| **SP1** | `sp1_ss` 20 B + (rows+1)(cols+1) × `sp1_cs` 24 B = 20 + 9·24 = **236 B** |
| **JSP current** | `jsp_sprite_s` 13 B + PDB (rows+1)(cols+1)·8 = 13 + 72 = **85 B** |
| **JSP new** | descriptor only (drop `pdbuf`, add `clip`,`z`) ≈ **14 B** |

SP1 pays a 24-byte linked-list node per covered cell. JSP new pays a flat ~14 B
per sprite — a ~17× per-sprite advantage that grows with sprite count and size.

### 8.3 Fixed tables both pay (≈ wash)

Rotation table: JSP 3584 B; SP1 `SP1V_ROTTBL` 3584 B. Tile lookup: both 512 B.

### 8.4 Empirical — RAGE1 `minimal` (SP1) vs `minimal_jsp` (JSP), `make mem`

| | SP1 (`minimal`) | JSP current (`minimal_jsp`) | JSP new (projected) |
|---|---|---|---|
| Library data region | `sp1data` **11795 B** | `jspdata` **7616 B** | `jspdata` **≈ 6080 B** (−DRT 1536) |
| Sprite storage | ~1.2 KB (SP1 heap) | ~0.95 KB (pool+PDBs, bss) | ~0.06–0.2 KB (pool only) |
| **Total used** | **28867 B** | 25955 B | **≈ 24300 B** |
| **Free RAM** | **12349 B** | 15261 B | **≈ 16900 B** |

(The empirical 11795 B for SP1 matches the component sum of the SP1 memory map
in `doc/SP1-COMPARISON.md`.)

### 8.5 Verdict

The redesign makes JSP **both correct and smaller**:

- Per-cell data **2496 B vs SP1's 7680 B** — the structural win (~5.2 KB).
- Per-sprite **~14 B vs SP1's ~236 B** — scales with sprite count.
- Empirically **~6–7 KB less total RAM than SP1** on `minimal`. On a 48K
  Spectrum with ~12 KB free, that is decisive — it is the difference between a
  game fitting or not.
- It is also **~1.5 KB + all PDBs smaller than *current* JSP**: `DRT` and the
  PDBs were wasted memory in a model that did not even work.

JSP's founding premise — "much smaller footprint than SP1" — holds decisively,
**provided JSP recomposites instead of bakes.**

---

## 9. CPU analysis

- The new `jsp_redraw` walks `DTT` (as today), blits backgrounds, composites
  sprites. Total compositing work is proportional to the actual sprite area
  touched — the same as today.
- It **drops** the per-move background-snapshot copy (`jsp_draw_sprite`
  currently `memcpy`s 8 bytes/cell into the PDB) — so moving sprites are
  slightly *faster*.
- New cost: Pass 2 iterates all active sprites every redraw. Made negligible by
  a global dirty-bounding-box prefilter (one rectangle test skips any sprite
  away from the action). Even without it, the cost is ~`pool_size ×
  footprint_cells` dirty-bit checks (~hundreds of cheap operations).
- The redraw asm becomes *simpler* (no DRT reset, no conditional BAT restore, no
  FTT special-casing in the hot path), so code size likely shrinks too.

Net: CPU roughly neutral, likely slightly faster for moving sprites.

---

## 10. Caveats and open questions

1. **Foreground tiles (FTT).** RAGE1's `gfx_*` API exposes no foreground-tile
   call, so RAGE1 never uses JSP foreground tiles. Decide: drop `FTT` entirely
   (−96 B, simpler) or keep it as Pass 3 for non-RAGE1 use. If kept, a
   foreground cell needs its tile pointer stored somewhere other than the
   removed `DRT` — a small sparse side-table.
2. **z-order.** Pool-index-as-z is simplest; an explicit `z` byte is more
   flexible. RAGE1 sprites rarely deeply overlap (hero touching enemy = death),
   so this is low-stakes. Decide during implementation.
3. **Draw primitives.** Confirm `sp1_draw_mask2`/`_lb`/`_rb` (and the load1
   variants) can be invoked per-cell from the redraw loop; they currently run in
   a per-sprite loop inside `jsp_draw_sprite`. Expected to be straightforward —
   they already take a destination buffer.
4. **Mismatch #3** (`gfx_sprite_get_width/height` off-by-one): align the
   `gfx_sp1.h` and `gfx_jsp.h` accessor macros on one convention. Low priority.
5. **Mismatch #6** (`jsp_print_string` control codes): out of scope for this
   redesign; implement the control codes RAGE1 games actually emit, or document
   a plain-strings-only constraint. Separate task.
6. **`gfx_sprite_set_threshold`** is a no-op in JSP. Acceptable for transparent
   MASK2 sprites (the suppressed trailing row/col is blank). Revisit only if
   bullet thresholds prove to matter for the dirty footprint.

---

## 11. Implementation handover (next session, JSP repository)

### 11.1 Starting state

- **JSP repo** (`~/src/spectrum/jsp`): branch `main`, clean. `lib/jsp_init.c` is
  the original 8-call version (an interim DFILE-clear experiment was reverted —
  the redesign's Pass 1 handles screen clearing correctly, so no `jsp_init`
  change is needed).
- **RAGE1 repo** (`~/src/spectrum/rage1/generic_spritelib_refactor/rage1`):
  branch `feat/generic_spritelib_refactor`. Has the JNEXT screenshot-regression
  framework at `tests/00regression/` (used as the acceptance test, §11.4).
- Per JSP's `CLAUDE.md`: do **not** commit to `main`; work on a feature branch;
  do **not** push without explicit authorization; run an independent code review
  of the new code before merge.

### 11.2 Files to change (JSP repo unless noted)

| File | Change |
|---|---|
| `include/jsp.h` | new `jsp_sprite_s` (drop `pdbuf`, add `clip`,`z`; `parked`→`active`); remove `jsp_drt` extern; declare the new "read screen cell" primitive |
| `lib/jsp_data.c` | remove `jsp_drt` declaration (`__at(DRT_ADDR)`); free `DRT_ADDR` region — revise the 48K/128K memory map comments |
| `lib/jsp_init.c` | remove `jsp_init_drt()` and its call; otherwise unchanged |
| `lib/jsp_sprite.asm` | rewrite `jsp_draw_sprite`/`jsp_move_sprite` as **deferred** (update state + mark dirty, no drawing); keep the rotation/composite helpers for reuse by the redraw |
| `lib/jsp_redraw.asm` | rewrite as the **three-pass** redraw (§6.5); add `read_screen_cell`; remove the DRT-reset and BAT-conditional-restore logic |
| `lib/jsp_sprite_c.c` | simplify `_do_move`/`_do_draw`, `jsp_move_sprite_*_frame`, `jsp_sprite_park` to the deferred model |
| `lib/jsp_pool.c` | expose pool iteration for Pass 2 (the redraw must walk active sprites in z-order) |
| `lib/jsp_tiles.c` | `jsp_tile_put`/`jsp_clear_rect`: defer the attribute write (write `BAT` + mark dirty; let Pass 1 push it) — fixes #5; drop `DRT` touching |
| `lib/jsp_color.c` | `jsp_apply_sprite_color` no longer needed as a separate per-move step (colour is applied in Pass 2); keep `jsp_sprite_set_color` as a state setter |
| RAGE1 `engine/src/gfx_jsp.c` | remove the PDB pool (`_sprite_pdbs_flat`, `_sprite_pdbs`); `jsp_sprite_pool_init` no longer needs the `pdbs` argument — simplify |
| RAGE1 `engine/include/rage1/gfx_jsp.h` | adjust `gfx_sprite_get_width/height` if aligning #3; otherwise unchanged |

### 11.3 Suggested task ordering

1. **Data model first.** Update `jsp.h`, `jsp_data.c`, `jsp_init.c` — remove
   `DRT`, change the struct. Get the library compiling.
2. **Deferred draw/move/park** in `jsp_sprite.asm` + `jsp_sprite_c.c`.
3. **Three-pass `jsp_redraw`** in `jsp_redraw.asm`; add `read_screen_cell`;
   wire Pass 2 to the pool (`jsp_pool.c`).
4. **Deferred attribute writes** in `jsp_tiles.c` (#5).
5. **RAGE1 side:** drop the PDB pool in `gfx_jsp.c`.
6. Build `minimal_jsp`, iterate against the regression test (§11.4).
7. Independent code review before merge (per JSP `CLAUDE.md`).

### 11.4 Test plan

- **Primary acceptance test:** RAGE1's JNEXT screenshot regression. Build
  `games/minimal_jsp`, run `bash tests/00regression/regression.sh` in the RAGE1
  repo. `minimal_jsp` must pixel-match the `minimal` (SP1) baseline at **0 px
  diff**. (Before the redesign: 280 px diff — the missing hero + fragments.)
- Add a `minimal_jsp` test directory under `tests/00regression/` once it passes,
  so it becomes a permanent regression.
- **JSP unit tests:** `jsp/tests/` and `jsp/test/` — extend with overlap /
  movement / animation / park cases that exercise the recompositing
  (specifically the §6.6 scenarios).
- **Memory check:** `make mem` on the RAGE1 `minimal_jsp` build — confirm
  `jspdata` shrank by ~1.5 KB (DRT removed) and the sprite-pool bss shrank
  (PDBs removed); confirm no address overlap.
- Manual: run `minimal_jsp` in JNEXT, verify hero appears immediately, moves,
  animates; verify no artifacts at the `game_area` boundary (per-cell clip).

### 11.5 Verify-first items (before coding)

- Confirm RAGE1 makes no use of JSP foreground tiles → decide FTT fate (§10.1).
- Confirm the `sp1_draw_*` primitives can be driven per-cell (§10.3).
- Decide z-order representation (§10.2).

---

## 12. Summary

The current JSP baking model (`DRT` single-pointer + per-sprite PDB composite)
is fundamentally unable to render overlapping, independently moving sprites
correctly — it is the cause of RAGE1's `minimal_jsp` failure — and no
snapshot-based patch (SVB included) can fix it. The redesign replaces baking
with **deferred three-pass recompositing**: mark dirty on move, then redraw =
backgrounds + sprites recomposited live in z-order. This matches SP1's golden
semantics exactly, needs zero RAGE1 changes, and is *smaller* than both current
JSP and SP1 — keeping JSP's footprint at roughly half of SP1's. The redesign is
therefore worth implementing; JSP remains a worthwhile, lighter alternative to
SP1.
