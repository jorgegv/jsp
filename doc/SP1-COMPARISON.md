# JSP COMPARISON WITH SP1

## Introduction

The main driver for developing JSP was that SP1's memory usage is so high that I felt it hindered the development of certain games, specially when developing for the 48K Spectrum, where memory is more restricted than its younger but more powerful brothers, the 128K ones.

I really liked the algorithms in SP1, and specifically how it handles the background layer and the sprite layer in an integrated form. But using SP1 with masked sprites, a full featured background, and also allowing the sprites to move at 1-pixel accuracy without preshifting  them, forces us to dedicate a whopping 13K of the scarce Spectrum's memory to SP1's internal data structures.

So I wanted to design a new sprite library which used SP1-like algorithms, or even reuse some of SP1's highly optimized routines (with slight modifications), to achieve the most used SP1 capabilities, but with a much lighter memory footprint.

So to get a real sense of the magnitudes we are talking about, here is the standard SP1 memory map for a game using SP1 for sprites and background, and pregenerated rotation tables for speedy sprite drawing at any pixel position:

| Range     | Contents                                               |
|-----------|--------------------------------------------------------|
| F200-FFFF | horizontal rotation tables (3584 bytes)                |
| F000-F1FF | tile array (512 bytes)                                 |
| D200-EFFF | update array for full size screen 32x24 (7680 bytes)   |
| D1FF-D1FF | attribute buffer (1 byte)                              |
| D1F7-D1Fe | pixel buffer (8 bytes)                                 |
| D1ED-D1F6 | update list head (10 bytes)                            |
| D1D4-D1EC | FREE (25 bytes)                                        |
| D1D1-D1D3 | JP to IM2 service routine (3 bytes)                    |
| D101-D1D0 | FREE (208 bytes) - Can be used as stack, set SP=0xD1D1 |
| D000-D100 | IM2 vector table (257 bytes, all of them value 0xD1)   |
| 5D00-CFFF | Available for main program (29440 bytes)               |
| 5B00-5CFF | BASIC loader (512 bytes)                               |

(In the reference SP1 memory map the stack is 512 bytes long and is located at 0xCE00-0xCFFF, but I have found that the spare 208 bytes at 0xD101 are usually more than enough, so I set the stack there and enjoy 512 additional bytes)

With that memory map, we see that SP1 data structures take up 13612 bytes (3584+512+7680+1+8+10+25), which is approximately 31% of available memory.

The goal of JSP is to do away with some of the more memory intensive data structures and make that room available for the main program. The memory map will need to be a bit reorganized, but this is expected.

## Required Functionalities

The following SP1 functionalities are the subset that I deemed essential to be replicated by JSP to serve as a practical alternative. These are all the SP1 functionalities used in my RAGE1 engine (plus some more), so I take it as a good indicator that full-featured games can be developed just with this subset:

- Arbitrary sprite size
- Sprite positioning at 1px granularity
- Background preservation when moving sprites
- Sprites have colors that move with it
- Background has attributes that are preserved
- Sprite priorities which determine which one is visible over another
- Sprites that move behind some background tiles
- Allow MASKED sprites (for optimal visual effect, sprites move over the background preserving it)
- Allow LOAD sprites (for maximum speed, background is not preserved)

The following additional functionalities (not supported by SP1) are nice-to-have:

- Static definition of sprites at compile time(do away with `malloc`, `free` and the heap, and have everything statically allocated)

The following special functions are explicitly _not_ supported:

- 1-byte tile IDs (in JSP all tiles are defined by their data address)
- Shuffling of destination screen address for any tile (see SP1 exampLe `ex5e.c` for an explanation of this)
- Complex sprite priorities (in JSP you must handle the priorities instead, and draw the sprites in the order you need)
- Mixed sprite/background priorities (in JSP either the background is below _all_ sprites, or it is above _all_ sprites)

## JSP Memory Map

The detailed design of JSP sprite and background management is detailed in the [ENGINE.md](ENGINE.md) document. The biggest SP1 data structures are the ones at the top of memory (rotation tables, tile array and update array), so they are the target to be reduced/eliminated in JSP.

If we want to allow 1-pixel positioning and we want to do it quickly, we need to either use preshifted sprites, or have some pregenerated rotation tables that allow to do the shifting in realtime. Since we do not want to impose the huge memory penalty of using preshifted sprites, we will use the rotation tables method, and so we cannot do away with them.

The next structure (the Tile Array) can be discarded completely, since it is only used for the 1-byte tile IDs, and we will be using 2-byte addresses for tiles in JSP.

Finally, the biggest structure (the Update Array) has also been replaced with some more compact structures: the BTT (Background Tile Table), DRT (Drawing Record Table) and DTT (Dirty Tiles Table); see [ENGINE.md](ENGINE.md)) for the details.

So according to the previous design, the JSP memory map for a 48K program is the following one:

| Range     | Contents                                          |
|-----------|---------------------------------------------------|
| F200-FFFF | Rotation tables (3.5 kB, 256-aligned)             |
| EC00-F199 | Background Tiles Table, BTT (1.5 kB, 256-aligned) |
| E600-EB99 | Drawing Records Table, DRT (1.5 kB, 256-aligned)  |
| E5E8-E5FF | Unused (18 bytes)                                 |
| E5E5-E5E7 | "JP <isr>" opcodes (3 bytes)                      |
| E585-E5E4 | Dirty Tiles Table, DTT (96 bytes)                 |
| E501-E584 | Stack (132 bytes)                                 |
| E400-E500 | IV table with value 0xE5 (257 bytes)              |
| 5D00-E3FF | Available for main program (34560 bytes)          |
| 5B00-5CFF | BASIC loader (512 bytes)                          |

With this memory map, JSP allows a program size of 34560 bytes, versus 29440 bytes with SP1. That is 5120 additional bytes (additional 17.4% over SP1 size).
