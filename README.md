# JSP Sprite Library

JSP (Jorge's Sprite Library) is an experimental sprite and background-tile
library for the **ZX Spectrum** and the **Amstrad CPC**, built with the
[Z88DK toolchain](https://www.z88dk.org) (C + Z80 assembly). It is based on the
same algorithms as the [SP1 Sprite Library](https://github.com/z88dk/z88dk/wiki/LIBRARY-SP1-Software-Sprites-(sp1.h))
by Alvin Albrecht, but with a much smaller memory footprint (≈6 KB less). Some
of its internal routines are derived from SP1's (thanks Alvin!).

## How it works

JSP uses a **deferred recompositing** model: drawing or moving a sprite never
touches the screen — it only updates the sprite descriptor and marks the
affected cells "dirty". A single `jsp_redraw()` call per frame then recomputes
just the changed cells from the background tables plus the *live* sprite state.
Nothing is baked, so overlapping, independently moving and animated sprites all
render correctly — the same observable semantics as SP1.

The engine keeps a small set of fixed tables (background tile pointers, dirty
bits, foreground bits, and — on the ZX — a background attribute table) in one
contiguous block, with the program and free RAM below it. There are no
per-sprite drawing buffers: a sprite is a ~13-byte descriptor that composites
straight to the screen during the redraw. Sprites support arbitrary size,
1-pixel horizontal positioning (via rotation tables, no preshifting), masked
(`MASK2`) or opaque (`LOAD1`) drawing, z-ordering, and foreground tiles that
sprites pass behind.

The **high-level API is identical on both platforms** — only the screen layout,
the colour model and the coordinate width differ, because the hardware does.

Further reading:
- [doc/ENGINE.md](doc/ENGINE.md) — core algorithm reference and memory maps
  (read this before modifying rendering).
- [doc/SP1-COMPARISON.md](doc/SP1-COMPARISON.md) — feature/memory comparison with SP1.
- [doc/legacy/RECOMPOSITE-REDESIGN.md](doc/legacy/RECOMPOSITE-REDESIGN.md) — full design rationale.

## Copyright

Copyright 2024-2026 ZXjogv <zx@jogv.es> (Jorge Gonzalez Villalonga), based on SP1
works by Alvin Albrecht.

## Source layout

- `include/jsp.h` — public API (single header), plus `jsp_config.h` / `jsp_target.h`.
- `lib/` — shared, platform-independent engine sources (C and Z80 ASM).
- `lib/zx/` — ZX Spectrum platform layer.
- `lib/cpc/` — Amstrad CPC platform layer.
- `tests/` — shared generated sprite assets; `tests/zx/` and `tests/cpc/` test programs.
- `tools/` — vendored asset generators (PNG → ASM).
- `main.c` — ZX test harness.

The Makefile is self-documenting: run `make` with no target to print the list of
available targets and what each does. All build artifacts go to `build/`;
`make clean` is just `rm -rf build/` (plus per-source intermediates).

---

# ZX Spectrum

The original target. Colour uses the Spectrum's **attribute RAM**: the engine
keeps a Background Attribute Table (BAT) with one attribute byte per cell, the
`jsp_*_color` API moves a sprite's colour with it, and a text/print API is
available. The cell grid is the standard 32×24; X and Y coordinates are 8-bit.

## Building and running

```bash
make build         # clean rebuild → produces build/main.tap
make zx-run        # build and launch build/main.tap in the FUSE emulator
make zx-run-jnext  # build and launch in the JNEXT emulator (GUI)
make clean         # remove build/
```

Ensure you have a recent Z88DK build with `zcc` on `PATH`, and the
[FUSE emulator](https://fuse-emulator.sourceforge.net/) installed for `make zx-run`.
Edit `main.c` to comment/uncomment the desired test, then `make build`. The
resulting `build/main.tap` runs on any ZX Spectrum emulator.

## Tests

ZX test programs (in `tests/zx/`) are integration tests. `make zx-tests` is an
automated regression suite (the analogue of `cpc-tests`): it builds every test,
runs each headless in JNEXT, captures a screenshot at a deterministic frame and
compares it to the committed reference in `tests/refs/zx/` with `magick compare
-metric AE` (0 = pass; any pixel diff fails the run). It includes `test_artifact`,
which guards the bottom cell-row over-render bug.

```bash
make zx-tests                     # build + run every ZX test, diff vs tests/refs/zx
make build/test_NAME.tap          # build a single ZX test
make zx-run-test TEST=test_NAME   # build + launch a single ZX test in FUSE
```

Available ZX tests: `test_dtt`, `test_btt_contents`, `test_btt_redraw`,
`test_sprite_draw`, `test_sprite_move`, `test_pool_and_colour`,
`test_tiles_and_print`, `test_foreground_tiles`, `test_redraw_bench`,
`test_artifact`.

A headless T-state profiler and a JSP-vs-SP1 redraw benchmark are available
(ZX only): `make zx-profile`, `make zx-bench`, `make zx-bench-sp1`.

## Memory layout

JSP keeps its five internal tables (rotation tables, BTT, DTT, FTT, BAT) in one
contiguous block at a fixed address. Where that block sits is a **compile-time
choice**:

- **`JSPDATA_SLOT3`** (the default) — the block lives at `0xE840–0xFFFF`, in
  slot 3 (the top 16K, `0xC000–0xFFFF`).
- **`JSPDATA_SLOT2`** — the block lives at `0xA840–0xBFFF`, in slot 2
  (`0x8000–0xBFFF`), keeping slot 3 entirely free of JSP data so it stays
  available for 128K bank switching.

The names refer to the Z80's four 16K memory slots. Despite the names, this flag
does **not** select a "48K" or "128K" machine mode: either setting works in 48K
or 128K mode without restriction — it only governs where the JSP data is located.
Define the desired flag at build time (e.g. `-DJSPDATA_SLOT2`); with no flag,
`JSPDATA_SLOT3` is used. See [doc/ENGINE.md](doc/ENGINE.md) for the full memory maps.

---

# Amstrad CPC

JSP also targets the Amstrad CPC, keeping the high-level engine identical and
swapping only the thin per-mode platform layer (`lib/cpc/`).

**Building your own CPC program?** Start with the
[CPC usage guide](doc/CPC-USAGE.md) — build setup, the API call sequence,
screen mode + palette, and making your own sprites/tiles from PNG.

## Screen modes

Seven CPC configs are supported, selected by exactly one compile guard:

| Compile guard    | px/byte | colours | screen W | sprite X positioning   | notes                          |
|------------------|---------|---------|----------|------------------------|--------------------------------|
| `CPC_MODE2`      | 8       | 2       | 640 px   | 1 px                   | closest to ZX; mono ink/paper  |
| `CPC_MODE1`      | 4       | 4       | 320 px   | 1 px                   | per-pixel colour (4 pens)      |
| `CPC_MODE0`      | 2       | 16      | 160 px   | 1 px                   | per-pixel colour (16 pens)     |
| `CPC_MODE1_MONO` | 4       | 2       | 320 px   | 1 px                   | 1bpp assets on a Mode-1 screen |
| `CPC_MODE2_FAST` | 8       | 2       | 640 px   | **8 px** (byte-aligned)| no shift table — smallest/fastest |
| `CPC_MODE0_FAST` | 2       | 16      | 160 px   | **2 px** (byte-aligned)| no shift table                 |
| `CPC_MODE1_FAST` | 4       | 4       | 320 px   | **4 px** (byte-aligned)| no shift table                 |

The **FAST** variants force byte-aligned horizontal positioning, drop the
rotation table and rotating kernels, and reclaim the most RAM at a coarser
granularity. Vertical positioning is always 1 px.

## CPC-specific differences

- **No attribute RAM.** Colour is baked into the pixel bits and read through the
  gate-array palette. On CPC the BAT is dropped, and the `jsp_*_color` /
  `jsp_apply_sprite_color` API and the text/print API are no-ops — set colour via
  the palette plus the pixel data (produced by the asset converter).
- **A test harness must set the screen mode + program the palette before the
  first `jsp_redraw()`** (the firmware boots in Mode 1). This is deliberately left
  to your `main`, never the library.
- **Everything is pixel-based.** Sprite X is a pixel coordinate (16-bit, since
  Mode 2 is 640 px wide), Y is a pixel row (8-bit). Cells are 8×8 px, exactly like
  the ZX, so the tile grid is the screen width ÷ 8: **80×25 / 40×25 / 20×25** in
  Mode 2 / 1 / 0. You never deal with bytes-per-pixel or shift phases — the engine
  handles them internally.
- **Memory map / linking:** JSP's data block lives at `0x9800–0xBFFF` (just below
  the `0xC000` screen). The build forces `-pragma-define:REGISTER_SP=0x9800`
  (stack grows down below the block) and keeps both ROMs off with code placed low
  (≈`0x1200`).

### Cell model (internal perf option)

The 8×8-px grid above is JSP's default **pixel-cell** model. There is also an
internal compile-time switch, `JSP_CELL_MODEL=byte`, that lays cells out as single
screen bytes (an 80×25 grid in every mode): it is ≈7 % faster in Mode 2 but slower
in Mode 0/1 and loses the 1-cell = 1-tile fidelity. The pixel default is the
measured-best all-round choice and **does not change the pixel-based API** — most
programs never touch it. Full analysis and measurements:
[doc/CPC-TILE-SIZE-DESIGN.md](doc/CPC-TILE-SIZE-DESIGN.md).

## Building and running

The Makefile drives the whole matrix through one parametrized target plus a few
maintenance targets:

```bash
make cpc-run-test TEST=sprite              # build + screenshot Mode 2 in cap32
make cpc-run-test TEST=sprite MODE=2_fast  # MODE ∈ 2 1 1_mono 0 2_fast 0_fast 1_fast
make cpc-run-test TEST=demo                # Mode 2 sprite demo (bounces continuously)
make cpc-tests                             # build every CPC config + run the regressions
```

`TEST` ∈ `sprite artifact shift bg foreground btt-redraw demo`; for
`sprite`/`artifact`/`shift`, `MODE` selects the variant. `SHOT=0` skips the
screenshot (build only). `cpc-tests` and `cpc-artifact-check` form an **automated
regression suite**: they screenshot every mode headless and compare to committed
refs in `tests/refs/cpc/` (`magick compare -metric AE`, 0 = pass). Further
measurement targets: `cpc-perf-matrix` (wall-clock redraw timing) and
`cpc-cell-model-archive` (rebuild the committed cell-model `.dsk` archive).

CPC programs are built with `zcc +cpc` and run/screenshotted headless in the
[Caprice32 (`cap32`)](http://www.cpcwiki.eu/index.php/Caprice32) emulator via the
`caprice-testing` skill. There is **no headless T-state profiler for the CPC yet**
— performance is verified visually / wall-clock-timed.

## Assets

Two vendored, in-repo PNG → ASM generators (no external dependency):

- **`tools/cpcgfx.pl --mode 0|1`** — Mode 0 / Mode 1 planar byte format.
- **`tools/gfxgen.pl`** — the 1bpp byte format used by Mode 2 (and
  `CPC_MODE1_MONO`, `CPC_MODE2_FAST`).

See [doc/CPC-USAGE.md](doc/CPC-USAGE.md) §7 for invocation examples.

## Further CPC reading

- [doc/CPC-USAGE.md](doc/CPC-USAGE.md) — practical getting-started guide.
- [doc/CPC-TARGET-PLAN.md](doc/CPC-TARGET-PLAN.md) — full design rationale.
- [doc/CPC-ASSETS-FORMAT.md](doc/CPC-ASSETS-FORMAT.md) — exact per-mode byte formats.
- [doc/CPC-TILE-SIZE-DESIGN.md](doc/CPC-TILE-SIZE-DESIGN.md) — cell/tile-size design notes.
- The CPC section of [doc/ENGINE.md](doc/ENGINE.md) — memory map and colour divergence.
</content>
</invoke>
