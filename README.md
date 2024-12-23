# JSP Sprite Library

JSP is an experimental sprite library for the ZX Spectrum using the [Z88DK toolchain](https://www.z88dk.org). It is based on the same algorithms as the [SP1 Sprite Library](https://github.com/z88dk/z88dk/wiki/LIBRARY-SP1-Software-Sprites-(sp1.h)) by Alvin Albrecht but with a much smaller memory footprint. Some of its internal routines have been derived from SP1 ones (thanks Alvin!).

See [SP1-COMPARISON.md](doc/SP1-COMPARISON.md) for a comparison between SP1 and JSP memory footprints, and [ENGINE.md](doc/ENGINE.md) for a description of how JSP works and manages to use less memory than SP1.

Copyright 2024 ZXjogv <zx@jogv.es> (Jorge Gonzalez Villalonga), based on SP1 works by Alvin Albrecht

## Test Program

Testing code is on the base directory. The library sources are in `lib` and `include` directories.

Ensure you have a recent Z88DK build and you have configured your environment to use it (i.e. `zcc` works!).

Edit `main.c` and comment/uncomment the desired test to be run, then do a `make build` to create the `main.tap` file which can be run on any ZX Spectrum emulator.

Do a `make run` to build and run the `main.tap` file on [FUSE emulator](https://fuse-emulator.sourceforge.net/) (which you must have installed).
