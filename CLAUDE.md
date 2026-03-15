# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

JSP (Jorge's Sprite Library) is an experimental sprite and background tile management library for the ZX Spectrum, built with the Z88DK toolchain (C + Z80 Assembly). It implements the same algorithms as SP1 but with ~6 KB less memory overhead. See `doc/SP1-COMPARISON.md` and `doc/ENGINE.md` for design rationale.

## Build Commands

```bash
make build   # Clean rebuild → produces main.tap
make run     # Build and launch in FUSE emulator
make clean   # Remove all build artifacts
```

Requires: Z88DK with `zcc` in PATH, and FUSE emulator for `make run`.

Asset generation (regenerate sprite ASM from PNG):
```bash
make test_sprite_mask2.asm
make test_sprite_load1.asm
```

## Running Tests

Tests are integration tests that run visually on the ZX Spectrum emulator — there is no automated test runner. Each test is a self-contained program in `tests/`.

```bash
make tests                        # Build all test taps
make tests/test_NAME.tap          # Build a single test
make run-test TEST=test_NAME      # Build and launch a single test in FUSE
```

Available tests: `test_dtt`, `test_btt_contents`, `test_btt_redraw`, `test_sprite_draw`, `test_sprite_move`, `test_pool_and_colour`, `test_tiles_and_print`, `test_foreground_tiles`.

## Code Structure

- `lib/` — Library source files (C and Z80 ASM)
- `include/jsp.h` — Public API (single header)
- `main.c` — Test harness
- `doc/ENGINE.md` — Core algorithm reference (read this before modifying rendering)
- `assets/` — PNG source images for sprites/tiles

## Architecture

The engine manages five memory tables:

| Table | Size | Purpose |
|-------|------|---------|
| BTT (Background Tiles Table) | 1536 B | 768 pointers to background tile data (one per screen cell) |
| DRT (Drawing Records Table) | 1536 B | 768 pointers to what will actually be drawn (includes sprite overlays) |
| DTT (Dirty Tiles Table) | 96 B | Bit per cell: 1 = needs redraw this frame |
| FTT (Foreground Tiles Table) | 96 B | Bit per cell: 1 = foreground tile, drawn above sprites and never overwritten by them |
| BAT (Background Attribute Table) | 768 B | One attribute byte per cell; restored after sprite passes through |

**Draw cycle** (per frame):
1. For each sprite: mark old cells dirty → copy background tiles from DRT to sprite's PDB → draw sprite into PDB → update DRT to point at PDB cells → mark new cells dirty
2. `jsp_redraw()`: walk DTT & FTT byte-by-byte; for each group of 8 cells, compute `DTT & ~FTT` and redraw those cells from DRT (non-foreground dirty cells only); for any remaining dirty FTT cells, restore DRT=BTT and clear DTT without drawing (keeps foreground tiles visible)

**Foreground tiles**: drawn directly to screen at placement time via `jsp_draw_foreground_tile()`. The FTT bit then permanently protects the cell — sprites pass behind it. `jsp_apply_sprite_color()` also skips FTT cells to preserve foreground tile attributes. Use `jsp_draw_background_tile()` to demote a foreground tile back to background.

**Sprite Private Drawing Buffer (PDB)**: each sprite has its own `(M+1)×(N+1)` char buffer where it composites background + sprite pixels. This is what allows overlapping sprites to work correctly.

**Memory layout (48K)**:
```
F200-FFFF  Rotation tables (3.5 kB, 256-aligned)
EC00-F199  BTT (1.5 kB)
E600-EB99  DRT (1.5 kB)
E5A0-E5FF  DTT (96 bytes)
E540-E59F  FTT (96 bytes)
E240-E53F  BAT (768 bytes)
5D00-E23F  Program code/data (~34 KB free)
```

**Key implementation files**:
- `lib/jsp_redraw.asm` — Screen refresh loop (hot path, performance-critical); handles FTT protection and DRT/DTT restoration for foreground cells
- `lib/jsp_sprite.asm` — Sprite draw dispatch
- `lib/jsp_sprite_c.c` — C wrappers for move/draw with parking and color support
- `lib/jsp_color.c` — `jsp_apply_sprite_color()`: writes sprite attributes, skipping FTT-protected cells
- `lib/jsp_pool.c` — Dynamic sprite allocation
- `lib/jsp_init.c` — Engine initialization
- `lib/sp1_draw_mask2*.asm` — Masked sprite draw (4 variants: normal, left-border, right-border, no-rotate)
- `lib/sp1_draw_load1*.asm` — Load-mode sprite draw (4 variants, overwrites background)

## Development Requirements

- Refactor or make changes in a way that each change can be tested if possible
- Do small commits, ideally one per task
- Keep commit messages concise but informative
- Ask for feedback when verification of visual/emulator behavior is needed
- Work autonomously but avoid large untested modifications
- Do not add Co-authored-by in commit messages
- Beware when calling functions between C and ASM. SDCC may use IX register as a base pointer, and some ASM functions may use it and corrupt it. Take this interactions into account, errors with this are quite difficult to track.