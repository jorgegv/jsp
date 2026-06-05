# JSP Sprite Library

JSP is an experimental sprite library for the ZX Spectrum **and the Amstrad CPC** using the [Z88DK toolchain](https://www.z88dk.org). It is based on the same algorithms as the [SP1 Sprite Library](https://github.com/z88dk/z88dk/wiki/LIBRARY-SP1-Software-Sprites-(sp1.h)) by Alvin Albrecht but with a much smaller memory footprint. Some of its internal routines have been derived from SP1 ones (thanks Alvin!).

See [SP1-COMPARISON.md](doc/SP1-COMPARISON.md) for a comparison between SP1 and JSP memory footprints, and [ENGINE.md](doc/ENGINE.md) for a description of how JSP works and manages to use less memory than SP1.

## Amstrad CPC

**Building your own CPC program?** Start with the
[CPC usage guide](doc/CPC-USAGE.md) — build setup, the API call sequence, mode +
palette, and making your own sprites/tiles from PNG.

JSP also targets the Amstrad CPC, keeping the high-level engine identical and
swapping only a thin per-mode platform layer (`lib/cpc/`). Eight CPC configs are
supported: **Mode 2/1/0** (1/4/16 colours, pixel-accurate horizontal
positioning), **Mode 1 MONO** (1 bpp assets on a Mode-1 screen for memory
saving), and the **FAST** variants **Mode 2/0/1 FAST** (byte-aligned positioning,
no shift table — `Mode 2 FAST` reclaims the most RAM). Colour on the CPC is baked
into the pixels (there is no attribute RAM), so a test harness sets the screen
mode + palette before the first redraw.

Build/run the CPC matrix with the Makefile:

```
make cpc-run-test TEST=sprite                   # build + screenshot Mode 2 in cap32
make cpc-run-test TEST=sprite MODE=2_fast       # any of 2 1 1_mono 0 2_fast 0_fast 1_fast
make cpc-tests                                  # build every CPC config + run the regressions
```

CPC programs are run/screenshotted headless in the Caprice32 emulator (there is
no headless T-state profiler for the CPC yet — performance is verified visually).
See [CPC-TARGET-PLAN.md](doc/CPC-TARGET-PLAN.md) for the full design,
[CPC-ASSETS-FORMAT.md](doc/CPC-ASSETS-FORMAT.md) for the per-mode byte formats,
and the CPC section of [ENGINE.md](doc/ENGINE.md) for the memory map and the
colour divergence.

Copyright 2024 ZXjogv <zx@jogv.es> (Jorge Gonzalez Villalonga), based on SP1 works by Alvin Albrecht

## Test Program

Testing code is on the base directory. The library sources are in `lib` and `include` directories.

Ensure you have a recent Z88DK build and you have configured your environment to use it (i.e. `zcc` works!).

Edit `main.c` and comment/uncomment the desired test to be run, then do a `make build` to create the `main.tap` file which can be run on any ZX Spectrum emulator.

Do a `make zx-run` to build and run the `main.tap` file on [FUSE emulator](https://fuse-emulator.sourceforge.net/) (which you must have installed).

## Memory layout

JSP keeps its five internal tables (rotation tables, BTT, DTT, FTT, BAT) in
one contiguous block at a fixed address. Where that block sits is a
compile-time choice:

- **`JSPDATA_SLOT3`** (the default) — the block lives at `0xE840-0xFFFF`,
  in slot 3 (the top 16K, `0xC000-0xFFFF`).
- **`JSPDATA_SLOT2`** — the block lives at `0xA840-0xBFFF`, in slot 2
  (`0x8000-0xBFFF`), keeping slot 3 entirely free of JSP data.

The names refer to the Z80's four 16K memory slots. The intent of
`JSPDATA_SLOT2` is to leave slot 3 (`0xC000-0xFFFF`) free, so it stays
available for 128K bank switching — that slot is the window the 128K
machine pages its banks into. Despite the names, this flag does **not**
select a "48K" or "128K" machine mode: either setting can be used in 48K
or 128K mode without restriction — it only governs where the JSP data is
located in memory. Define the desired flag at build time (e.g.
`-DJSPDATA_SLOT2`); with no flag, `JSPDATA_SLOT3` is used. See
[ENGINE.md](doc/ENGINE.md) for the full memory maps.
