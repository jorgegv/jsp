# Using JSP on the Amstrad CPC — a getting-started guide

This is the **third-party usage guide** for building an Amstrad CPC program with
JSP. It assumes you can write C + a little Z80 and have the
[z88dk](https://www.z88dk.org) toolchain installed. For *why* the engine works
the way it does, see [ENGINE.md](ENGINE.md) (the CPC section) and the design
record in [CPC-TARGET-PLAN.md](CPC-TARGET-PLAN.md); for the exact sprite/tile
**byte formats**, see [CPC-ASSETS-FORMAT.md](CPC-ASSETS-FORMAT.md). This document
is the practical "how do I actually use it" path.

The high-level API is identical to the ZX build — only the screen mode, the
colour model and the coordinate width differ (all described below).

---

## 1. What you get

A deferred-recompositing sprite + tile engine: you place background tiles and
move sprites (which only update state and mark cells dirty), then call
`jsp_redraw()` once per frame to repaint just the changed cells, flicker-free.
Sprites are **pixel-accurately positioned** horizontally (sub-byte shifting) and
composite with per-pixel masking. Memory footprint is small (≈6 KB less than
SP1's equivalent).

---

## 2. Prerequisites

- **z88dk** with `zcc` on `PATH`, built with the **sdcc** C compiler backend
  (`zcc +cpc -compiler=sdcc`). This is mandatory — JSP's asm kernels use the SDCC
  calling convention.
- **Perl + the GD module** (`libgd`), only if you regenerate sprite/tile assets
  from PNGs (§7). The asset generators are vendored in `tools/` — JSP has no
  external tool dependency.
- **Caprice32 (`cap32`)** is optional, for visually testing `.dsk` builds (see
  the `caprice-testing` skill / `tools/cap32-shot.sh`).

---

## 3. Pick a screen mode

Choose **exactly one** mode at compile time via a `-D` guard. The mode fixes the
colour count, horizontal resolution and sub-pixel positioning granularity:

| Compile guard      | px/byte | colours | screen W | sprite X positioning | notes                              |
|--------------------|---------|---------|----------|----------------------|------------------------------------|
| `CPC_MODE2`        | 8       | 2       | 640 px   | 1 px (7 shift phases)| closest to ZX; mono ink/paper      |
| `CPC_MODE1`        | 4       | 4       | 320 px   | 1 px (3 shift phases)| per-pixel colour (4 pens)          |
| `CPC_MODE0`        | 2       | 16      | 160 px   | 1 px (1 shift phase) | per-pixel colour (16 pens)         |
| `CPC_MODE1_MONO`   | 4       | 2       | 320 px   | 1 px                 | 1bpp assets on a Mode-1 screen     |
| `CPC_MODE2_FAST`   | 8       | 2       | 640 px   | **8 px** (byte-aligned)| no shift table — smallest/fastest |
| `CPC_MODE0_FAST`   | 2       | 16      | 160 px   | **2 px** (byte-aligned)| no shift table                    |
| `CPC_MODE1_FAST`   | 4       | 4       | 320 px   | **4 px** (byte-aligned)| no shift table                    |

The **FAST** variants force byte-aligned positioning (no sub-byte shift); they
drop the rotation table and the rotating kernels, saving RAM/time at coarser
horizontal granularity. Vertical positioning is always 1 px in every mode.

---

## 4. Build your own program

JSP is a source library — you compile its sources together with yours in one
`zcc` invocation. The platform layer is selected by directory: compile
`lib/*.{c,asm}` (shared engine) **plus** `lib/cpc/*.asm` (the CPC layer).

```sh
JSP=/path/to/jsp            # the JSP checkout
MODE=CPC_MODE2              # one of the §3 guards

zcc +cpc -compiler=sdcc \
    -DJSP_TARGET_CPC -Ca-DJSP_TARGET_CPC \
    -D$MODE       -Ca-D$MODE \
    -pragma-define:REGISTER_SP=0x9800 \
    -SO2 --max-allocs-per-node200000 \
    -I$JSP/include -Ca-I$JSP \
    -create-app -subtype=dsk \
    mygame.c mygame_sprites.asm \
    $JSP/lib/*.c $JSP/lib/*.asm $JSP/lib/cpc/*.asm \
    -o MYGAME -m
```

Key points:

- **`-DJSP_TARGET_CPC` AND `-Ca-DJSP_TARGET_CPC`** — the macro must reach both the
  C compiler (`-D`) and the assembler (`-Ca-D`). Same for the mode guard.
- **`-I$JSP/include`** (C headers) **and `-Ca-I$JSP`** (assembler include path).
  Both are required: the C sources include `jsp.h`/`jsp_config.h` from
  `include/`, and a couple of CPC asm files pull in `lib/cpc/jsp_cpc_geom.inc` by
  a JSP-root-relative path, so the assembler's include root must be the JSP
  checkout. (The bundled `Makefile` omits `-Ca-I` only because it runs *from* the
  JSP root; building from your own directory needs it.)
- **`-pragma-define:REGISTER_SP=0x9800`** — JSP's data block lives at
  `0x9800–0xBFFF` (just below the `0xC000` screen); the firmware-default stack
  sits high and would corrupt it, so the stack is forced below the block. **Do
  not omit this.**
- **`-subtype=dsk`** emits a cap32-loadable `.dsk`. The AMSDOS catalog name is the
  `-o` name, uppercased, ≤8 chars, with an *empty* extension, so it launches with
  a **trailing dot**: `RUN"MYGAME.` (note the `.`). `-subtype=none` gives a tape.
- Both ROMs are kept off and code is placed low (≈`0x1200`); JSP renders from its
  own tile/sprite data, never the firmware font, so you don't page in any ROM.

The repository `Makefile` is a working reference for all of this (see the
`cpc-sprite*` targets and `CPC_CFLAGS`).

---

## 5. Program structure

Every CPC JSP program follows the same shape. **The order matters**: you must set
the screen mode and program the palette *before* the first `jsp_redraw()`, because
on the CPC colour lives in the pixels interpreted through the gate-array palette
(there is no attribute RAM — see §6).

```c
#include <stdint.h>
#include "jsp.h"

void main( void ) {
    cpc_set_mode_and_palette();   // 1. mode + palette  (YOUR code, see below)
    jsp_init( default_tile, 0 );  // 2. init engine (default_attr unused on CPC)

    // 3. paint the background (80 cols x 25 rows of 8x8 cells)
    for ( r = 0; r < 25; r++ )
        for ( c = 0; c < 80; c++ )
            jsp_draw_background_tile( r, c, my_tile );

    // 4. game loop
    for (;;) {
        jsp_move_sprite( &player, x, y );   // deferred: just marks cells dirty
        // ... move other sprites, place/remove tiles ...
        jsp_redraw();                       // 5. repaint changed cells, once/frame
        // ... wait for frame / vsync, read input ...
    }
}
```

### Setting the mode + palette (your harness, not the library)

This is the one piece JSP deliberately leaves to you. Program the gate array
directly. RMR value `0x8E / 0x8D / 0x8C` selects mode `2 / 1 / 0` with **both
ROMs off** (full RAM). Pen `p` is set by writing `p` then `0x40|hw_ink` to port
`0x7F00`:

```c
// Mode 2 (2 colours): pen0 = black, pen1 = bright white.
static void cpc_set_mode_and_palette( void ) {
    __asm
    di
    ld bc,0x7f00
    ld a,0x00            ; select pen 0
    out (c),a
    ld a,0x54            ; pen 0 = black      (0x40 | hw ink)
    out (c),a
    ld a,0x01            ; select pen 1
    out (c),a
    ld a,0x4b            ; pen 1 = bright white
    out (c),a
    ld a,0x8e            ; RMR: mode 2, both ROMs OFF
    out (c),a
    __endasm;
}
```

For Mode 0/1, loop over all 4/16 pens the same way (see
`tests/cpc/test_cpc_sprite_mode0.c` for a 16-pen loop). The hardware-ink values
are the standard CPC gate-array inks `0x40 | hw`.

### Defining and placing sprites

Declare a sprite statically with `DEFINE_SPRITE`, or allocate from a pool
(`jsp_sprite_pool_init` / `jsp_sprite_alloc`):

```c
extern uint8_t ball_pixels[];   // emitted asset (see §7)

//             name    rows cols pixels        x  y  type
DEFINE_SPRITE( player, 2,   2,   ball_pixels,  0, 0, JSP_TYPE_MASK2 );
```

- **`rows`** = sprite height in 8-px cells (`height_px / 8`).
- **`cols`** = sprite width in **byte-cells**, which is mode-dependent (a byte
  spans 8/4/2 px in Mode 2/1/0). The simple rule: **`cols = width_px / ppb`**
  (ppb = 8/4/2). A 16×16 sprite is `cols = 2 / 4 / 8` in Mode 2 / 1 / 0;
  `rows = 2` always.
- **`type`** = `JSP_TYPE_MASK2` (transparent, per-pixel mask) or `JSP_TYPE_LOAD1`
  (opaque, overwrites the background).

Then each frame:

```c
jsp_move_sprite( &player, x, y );   // x = pixel X, y = pixel Y
```

`x` is a **pixel** coordinate (`jsp_xcoord_t`, 16-bit on CPC: 0..639 / 0..319 /
0..159 for Mode 2 / 1 / 0). `y` is 8-bit (0..199). `jsp_move_sprite` defers: it
updates the descriptor and dirties the old + new footprint; nothing is drawn
until `jsp_redraw()`. To make a sprite stop being drawn use `jsp_sprite_park()`.

### Background and foreground tiles

```c
jsp_draw_background_tile( row, col, pix );   // row 0..24, col 0..79; pix = 8 bytes
jsp_delete_background_tile( row, col );      // restore the default tile
jsp_draw_foreground_tile( row, col, pix );   // sprites pass BEHIND this cell
```

A tile is always **8 bytes** (8 scan-lines, one byte wide). What those bits mean
depends on the mode's pixel encoding (Mode 2 = 8 mono px; Mode 1 = 4 px in two
nibble-planes; Mode 0 = 2 px interleaved — see CPC-ASSETS-FORMAT.md). Build tiles
with the asset tool (§7), or by hand for simple shapes.

---

## 6. Colour and coordinates — CPC specifics

- **No attribute RAM.** Colour is baked into the pixel bits and read through the
  gate-array palette. `jsp_init`'s `default_attr` and the `jsp_*_color` API are
  ZX-only and are no-ops on CPC — set colour via the palette + the pixel data.
- **Mode 2 is monochrome** per screen (ink/paper from two palette registers).
  **Mode 1/0 carry a real per-pixel palette index** (4 / 16 pens).
- **X is 16-bit, Y is 8-bit** on CPC. The engine splits X into a byte column and a
  sub-byte shift phase automatically.
- **Grid is 80 × 25 byte-cells** in every mode (a cell is 8 lines tall and
  2/4/8 px wide in Mode 0/1/2).

---

## 7. Make your own sprites and tiles (from PNG)

JSP ships two vendored, in-repo generators (no external dependency):

- **`tools/cpcgfx.pl --mode 0|1`** — emits the Mode 0 / Mode 1 planar byte format.
- **`tools/gfxgen.pl`** — emits the 1bpp byte format used by **Mode 2** (and
  `CPC_MODE1_MONO`, `CPC_MODE2_FAST`).

Example — convert a 16×16 region of a PNG into a Mode-1 masked sprite:

```sh
tools/cpcgfx.pl -i art/ball.png -x 0 -y 0 --width 16 --height 16 \
    -m FF0000 -f FFFFFF -b 000000 --mode 1 \
    -s _ball_pixels -g sprite_mask --extra-bottom-row --extra-top-rows > ball.asm
```

- `-m/-f/-b` = the **mask / foreground / background** RGB colours in the source
  PNG (mask colour marks transparent pixels).
- `-s` = the emitted C-linkable symbol (`extern uint8_t _ball_pixels[];` — refer
  to it in C without the leading underscore: `ball_pixels`).
- `-g sprite_mask` (→ `JSP_TYPE_MASK2`) or `-g sprite_load` (→ `JSP_TYPE_LOAD1`).
- **`--extra-bottom-row --extra-top-rows` are required for sprites** — they emit
  the sub-cell-Y padding the engine relies on. (Omit them only for tiles.)

For Mode 2, call `tools/gfxgen.pl` with the same `-i/-x/-y/--width/--height/-m/-f/-b`
options plus `--code-type asm -l columns -g sprite_mask|sprite_load
--extra-bottom-row --extra-top-rows`. The repository `Makefile` (`$(TESTS_DIR)/...`
asset rules) shows the exact invocations for all modes.

> **Current limitation (honest note).** The Mode 0/1 emitter maps **2-colour**
> source art (foreground → pen 1, background → pen 0); full per-pixel multi-pen
> source art is a planned extension. The shift kernels already handle every byte
> value, so the engine itself is not the limit — only the converter's colour
> mapping. Mode 2 is inherently 2-colour.

---

## 8. Memory map (Model A, all modes)

```
0xC000-0xFFFF   screen (16 KB)
0xB200-0xBFFF   rotation tables   (Mode-2 size; smaller / empty in M1/M0/FAST)
0xA200-0xB19F   BTT (background tile pointers, 4000 B)
0xA100-0xA1F9   DTT (dirty bits, 250 B)
0xA000-0xA0F9   FTT (foreground bits, 250 B)
0x9800-0x9FCF   BAT (allocated but unused on CPC)
below 0x9800    your program + data; stack grows down from 0x9800
~0x1200         code origin (both ROMs off)
```

Your program and free RAM live below `0x9800`. Keep the stack modest (the
forced `REGISTER_SP=0x9800` grows down from there).

---

## 9. API quick reference

| Function | Purpose |
|----------|---------|
| `jsp_init(default_tile, attr)` | initialise the engine (attr unused on CPC) |
| `jsp_redraw()` | repaint all dirty cells — call once per frame |
| `DEFINE_SPRITE(name,rows,cols,pixels,x,y,type)` | declare a static sprite |
| `jsp_draw_sprite(sp,x,y)` / `jsp_move_sprite(sp,x,y)` | place / move (deferred) |
| `jsp_sprite_park(sp)` | stop drawing a sprite |
| `jsp_draw_background_tile(row,col,pix)` | place an 8-byte background tile |
| `jsp_delete_background_tile(row,col)` | restore the default tile |
| `jsp_draw_foreground_tile(row,col,pix)` | tile that sprites pass behind |
| `jsp_sprite_pool_init` / `jsp_sprite_alloc` / `jsp_sprite_free` | dynamic sprites |
| `jsp_sprite_set_clip(sp,rect)` | clip a sprite to a cell rectangle |
| `jsp_move_sprite_frame(sp,frame,x,y)` | move + swap the pixel frame (animation) |

`jsp_*_color` / `jsp_apply_sprite_color` and the text/print API are ZX-oriented
(attribute colour / ROM font) and have no effect on the current CPC build.

A complete, runnable example is `tests/cpc/test_cpc_sprite.c` (Mode 2) — copy it
as a starting skeleton; it sets the mode + palette, inits, paints a background and
animates several masked sprites.

---

## 10. See also

- [ENGINE.md](ENGINE.md) — engine model + the CPC memory/screen/colour notes.
- [CPC-ASSETS-FORMAT.md](CPC-ASSETS-FORMAT.md) — exact per-mode tile/sprite byte
  formats (authoritative).
- [CPC-TARGET-PLAN.md](CPC-TARGET-PLAN.md) — full design rationale.
- `tests/cpc/*.c` — working examples for every mode.
