# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

JSP (Jorge's Sprite Library) is an experimental sprite and background tile management library for the ZX Spectrum, built with the Z88DK toolchain (C + Z80 Assembly). It implements the same algorithms as SP1 but with ~6 KB less memory overhead. See `doc/SP1-COMPARISON.md` and `doc/ENGINE.md` for design rationale.

## Build Commands

The Makefile is self-documenting: `make` with no target prints the list of
available targets and what each does.

The top-level Makefile keeps a small curated target set (ZX targets are
`zx-*`-prefixed; the whole CPC mode matrix is collapsed into `cpc-run-test` /
`cpc-tests`). All artifacts go to `build/`.

```bash
make build   # alias of build-zx: clean rebuild → produces build/main.tap
make zx-run  # Build and launch build/main.tap in FUSE emulator
make clean   # Remove build/ + per-source intermediates
```

Requires: Z88DK with `zcc` in PATH, and FUSE emulator for `make zx-run`.

Asset generation (regenerate sprite ASM from PNG):
```bash
make test_sprite_mask2.asm
make test_sprite_load1.asm
```

## Running Tests

Tests are integration tests run on the emulator. Both platforms have an
automated screenshot-regression suite (`make zx-tests` / `make cpc-tests`): each
test is run headless, captured at a deterministic frame and compared to a
committed reference in `tests/refs/` with `magick compare -metric AE` (0 = pass).
Test programs are split by platform, mirroring `lib/`: shared generated sprite
assets live in `tests/` (like `lib/*.asm`), ZX test programs in `tests/zx/`, CPC
test programs in `tests/cpc/`.

All build artifacts (taps, dsks, named binaries, screenshots) are emitted into
the `build/` directory; `make clean` is just `rm -rf build/`.

```bash
make zx-tests                     # Build + run every ZX test headless in JNEXT, diff vs tests/refs/zx
make build/test_NAME.tap          # Build a single ZX test
make zx-run-test TEST=test_NAME   # Build and launch a single ZX test in FUSE
```

Available ZX tests: `test_dtt`, `test_btt_contents`, `test_btt_redraw`, `test_sprite_draw`, `test_sprite_move`, `test_pool_and_colour`, `test_tiles_and_print`, `test_foreground_tiles`, `test_redraw_bench`, `test_artifact`.

CPC tests (`zcc +cpc`, headless cap32 screenshot via the `caprice-testing` skill)
are driven by one parametrized target, `cpc-run-test TEST=<name> [MODE=<token>]`,
plus `cpc-tests` which builds every config and runs the regressions:

```bash
make cpc-tests                       # build all CPC configs + shift unit tests + artifact regression
make cpc-run-test TEST=bg            # Mode 2 background-tile test (build + screenshot)
make cpc-run-test TEST=sprite        # Mode 2 sprite test (MODE defaults to 2)
make cpc-run-test TEST=sprite MODE=1_fast   # a specific sprite mode
make cpc-run-test TEST=demo          # Mode 2 sprite demo (bounces continuously);
                                     #   watch: cap32 -a 'run"CPCSPRD.' build/CPCSPRD.dsk
```

`TEST` ∈ `sprite artifact shift bg foreground btt-redraw demo`; for
`sprite`/`artifact`/`shift`, `MODE` selects the variant (sprite: `2 1 1_mono 0
2_fast 0_fast 1_fast`; artifact/shift: a subset). `SHOT=0` skips the screenshot
(build only). Three further CPC maintenance/measurement targets round out the
set (all listed by `make help`): `cpc-artifact-check` (regression AE per mode),
`cpc-perf-matrix` (wall-clock redraw timing), `cpc-cell-model-archive` (rebuild
the committed byte/pixel `.dsk` archive).

## Code Structure

- `lib/` — Library source files (C and Z80 ASM)
- `include/jsp.h` — Public API (single header)
- `main.c` — Test harness
- `doc/ENGINE.md` — Core algorithm reference (read this before modifying rendering)
- `assets/` — PNG source images for sprites/tiles

## Architecture

JSP uses a **deferred recompositing** model (see `doc/legacy/RECOMPOSITE-REDESIGN.md`):
drawing/moving a sprite only updates its descriptor and marks cells dirty;
`jsp_redraw()` recomputes the screen from the background tables plus *live*
sprite state. Nothing is baked, so overlapping/moving/animated sprites
render correctly (SP1-equivalent semantics).

The engine manages four memory tables:

| Table                            | Size   | Purpose                                                                                                       |
|----------------------------------|--------|---------------------------------------------------------------------------------------------------------------|
| BTT (Background Tiles Table)     | 1536 B | 768 pointers to background tile data (one per cell); for a foreground cell, holds the foreground tile graphic |
| DTT (Dirty Tiles Table)          | 96 B   | Bit per cell: 1 = needs redraw this frame                                                                     |
| FTT (Foreground Tiles Table)     | 96 B   | Bit per cell: 1 = foreground tile; painted from BTT, never composited over by sprites                         |
| BAT (Background Attribute Table) | 768 B  | One attribute byte per cell; painted for every dirty cell by `jsp_redraw`                                     |

Sprites have no per-sprite drawing buffers — they composite straight to the
screen during `jsp_redraw`.

**Draw cycle** (per frame):
1. Deferred ops: `jsp_draw_sprite`/`jsp_move_sprite`/`jsp_sprite_park` update
   the sprite descriptor and mark old/new footprint cells dirty. Sprites
   self-register in a bounded registry on first draw/move.
2. `jsp_redraw()` — single-pass, flicker-free. `jsp_redraw_begin()` first
   precomputes each active sprite's footprint rectangle + compositing
   constants into `jsp_frame_sprites[]`. The asm DTT-walk then visits each
   dirty cell: a foreground or uncovered cell is blitted straight from BTT +
   BAT (the common case — no scratch); a sprite-covered cell goes to the asm
   helper `jsp_redraw_covered_cell()`, which builds the final image in an
   8-byte scratch (BTT tile + every covering sprite in z-order) and writes it
   with one store. Each cell is written exactly once — no intermediate
   background-only state. Then the DTT is cleared.

**Foreground tiles**: `jsp_draw_foreground_tile()` stores the tile in BTT,
sets the FTT bit and marks the cell dirty. `jsp_redraw` blits foreground
cells from BTT and never composites sprites onto them, so sprites pass
behind. Use `jsp_draw_background_tile()` to demote a foreground tile back
to background.

**Memory layout (48K)** — the five JSP tables form one contiguous block
at the top of RAM, with the program area and free RAM contiguous below it:
```
F200-FFFF  Rotation tables (3.5 kB, 256-aligned)
EC00-F1FF  BTT (1.5 kB)
EBA0-EBFF  DTT (96 bytes)
EB40-EB9F  FTT (96 bytes)
E840-EB3F  BAT (768 bytes)
5D00-E83F  Program code/data + free
```

**Key implementation files**:
- `lib/jsp_redraw.asm` — Single-pass flicker-free redraw: the DTT-walk hot loop, with the inline background-cell blit (assembly)
- `lib/jsp_composite.c` — `jsp_redraw_begin()` (per-frame per-sprite precompute) (C)
- `lib/jsp_covered.asm` — `jsp_redraw_covered_cell()`: per-covered-cell compositing (seed scratch from BTT, composite all covering sprites in z-order, single store) (assembly)
- `lib/jsp_sprite_c.c` — Deferred draw/move/park, sprite registry, type wrappers
- `lib/jsp_tile.c` — Background/foreground tile placement (deferred)
- `lib/jsp_color.c` — `jsp_apply_sprite_color()`: writes sprite attributes, skipping FTT-protected cells
- `lib/jsp_pool.c` — Dynamic sprite allocation
- `lib/jsp_init.c` — Engine initialization
- `lib/jsp_screen.asm` — `jsp_draw_screen_tile` (8-byte cell blit; register entry `jsp_draw_screen_tile_regs`)
- `lib/sp1_draw_mask2*.asm` — Masked sprite draw (4 variants: normal, left-border, right-border, no-rotate)
- `lib/sp1_draw_load1*.asm` — Load-mode sprite draw (4 variants, overwrites background)

The redraw splits work between an assembly DTT-walk hot loop and C
(per-frame precompute, per-covered-cell compositing); the pixel
rotation/masking kernels are the original SP1 assembler. New library code
is written in C first and selectively moved to assembly once correct.

## Development Requirements

- Refactor or make changes in a way that each change can be tested if possible
- Do small commits, ideally one per task
- Keep commit messages concise but informative
- Ask for feedback when verification of visual/emulator behavior is needed
- Work autonomously but avoid large untested modifications
- Do not add Co-authored-by in commit messages
- Beware when calling functions between C and ASM. SDCC may use IX register as a base pointer, and some ASM functions may use it and corrupt it. Take this interactions into account, errors with this are quite difficult to track.
- When you need to do independent tasks, launch a team of agents in parallel, up to a maximum of 3 agents. Agents MUST work on their own worktrees, not on the regular branch. Merges should be handled by the main agent.
- After developing a task, launch an independent agent for review. Review agents should not wait to other tasks, thety should launch as soon as the task to be reviewed finishes.

## Development guidelines

- Spectrum memory maps tend to have a small stack (typically 100-150 bytes). Avoid allocating lots of variables, or big variables (e.g. arrays) on the stack. If a function needs to have several local variables, allocate them as global variables just beside the function, and initialize them manually inside the function if needed. Try to keep only counters and similar as local variables.
- If a function receives a single argument (8/16 bits) always declare it with `__z88dk_fastcall` qualifier, for speed.
- When converting a C function to assembly for efficiency, the C source shall be preserved as a comment block just above the converted ASM function, for reference.