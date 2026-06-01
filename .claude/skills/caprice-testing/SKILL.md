---
name: caprice-testing
description: Build and visually test Amstrad CPC programs in the Caprice32 (cap32) emulator, headless. Use when running, screenshotting, or eyeball-verifying a JSP-CPC .dsk/.cdt build, driving cap32 in this environment, or building a CPC test with z88dk +cpc. The CPC analogue of the jnext-emulation (ZX) skill.
---

You are operating the **JSP Caprice32 (CPC) test workflow**: build a CPC
program with z88dk's `+cpc` target, run it headless in the `cap32` emulator,
and capture a PNG of the emulated screen for eyeball / pixel verification.

This is the **CPC analogue of the JNEXT ZX workflow** (the `jnext-emulation`
skill). It is an **interim driver** — `tools/cap32-shot.sh` is the way to get a
CPC screenshot in this dev environment until a formal headless regression
harness exists. It was adapted into JSP from the RAGE1 multiplatform port
(where it was proven in Phase 4); see `doc/CPC-TARGET-PLAN.md` §11 for how it
fits the JSP-CPC build matrix.

## The screenshot driver: `tools/cap32-shot.sh`

```bash
cd <dir containing the .dsk>
/path/to/jsp/tools/cap32-shot.sh [DISKFILE] [CPC_RUN_NAME]
#   DISKFILE     defaults to poc.dsk
#   CPC_RUN_NAME defaults to POC (the AMSDOS binary name on the disk)
# -> writes ./shot.png (full emulator framebuffer grab)
```

What it does, and **why each step is needed in this environment**:

- Starts a **dedicated Xvfb** (`:99`, rootful X) and runs cap32 inside it.
  The live desktop session here is **Wayland** (`WAYLAND_DISPLAY=wayland-0`,
  rootless Xwayland on `:0`): grabbing the `:0` root returns **all black**, and
  GNOME's D-Bus screenshot is **access-denied**. A private Xvfb is the only
  reliable capture surface.
- Forces SDL's X11 backend for cap32: `SDL_VIDEODRIVER=x11 WAYLAND_DISPLAY=`.
  Without this, SDL2 follows `WAYLAND_DISPLAY` to the live compositor and the
  Xvfb root stays black.
- Waits for Xvfb with `xdotool getdisplaygeometry` (this box has **no
  `xdpyinfo`**; `Xvfb`, `xdotool`, `import` from ImageMagick **are** installed).
- Launches `cap32 -c <cfg> -a 'run"NAME.' DISK`, sleeps for boot, then
  `import -window root shot.png`. Also sends **F3** via xdotool (cap32's own
  clean-framebuffer dump to its `sdump_dir`) as a secondary capture.

## cap32 essentials (this machine)

- Binary: `~/src/cpc/caprice32/cap32`. The interactive `cap32` shell function is
  `"$CAP32DIR/cap32" -c "$CAP32DIR/cap32.cfg" "$@"` with
  `CAP32DIR=/home/jorgegv/src/cpc/caprice32` (a precondition of this environment;
  `cap32-shot.sh` honours a `CAP32DIR` env override if the install moves).
- **Always pass `-c <cap32.cfg>`** or cap32 can't find its ROMs
  (`rom/cpc6128.rom not found`). The cfg also sets `model=2` (CPC6128) and
  `sdump_dir` (where F3 dumps land).
- Useful flags: `-a/--autocmd '<BASIC cmd>'` runs a command after boot (injected
  into the firmware, so it bypasses the host keymap — quotes are safe);
  `-c <cfg>`; loads `.dsk` / `.cdt` / `.sna` / `.cpr` / `.zip` (**not** the raw
  z88dk `.cpc`). In-emulator: **F3** = save screenshot, **F10** = quit.

## Building a CPC test program (z88dk `+cpc`)

**The Makefile is the source of truth** for which sources are linked — do not
hand-glob `lib/*.asm`: that pulls in the **ZX-only** kernels (`sp1_draw_*`,
`jsp_screen.asm`, `jsp_redraw.asm` with hard-coded `0x4000`/`0x5800`/+0x100 ZX
addressing) that the `JSP_TARGET_CPC` seam excludes/replaces
(`doc/CPC-TARGET-PLAN.md` §1.2, §7, Phase 0). Build through the Makefile matrix:

```bash
make JSP_TARGET=cpc JSP_CPC_MODE=2 <test>        # selects the CPC source set + guard
# illustrative direct form (the Makefile selects the real file list):
zcc +cpc -compiler=sdcc -create-app -subtype=dsk -DCPC_MODE2 -o NAME \
    <test>.c <CPC platform-layer .c/.asm, NOT the ZX-only kernels>
```

- **`-compiler=sdcc`** is mandatory: it matches the SDCC ABI JSP's
  `__z88dk_callee`/`__z88dk_fastcall` kernels are written against (same as ZX).
- **Link org / memory map**: use the JSP-CPC designed memory map (the data block
  must sit **below the 0xC000 screen**, see `doc/CPC-TARGET-PLAN.md` §9) — set it
  via the Makefile / `-zorg`, don't hardcode a stray address. JSP renders from
  its **own** tile/sprite data (not the firmware ROM font), so it should not need
  to page in the lower ROM (0x0000–0x3FFF).
- **JSP writes its own CPC kernels** (per-mode shift tables + `sp1_draw_*`
  composite kernels, `doc/CPC-TARGET-PLAN.md` §4/§5). Unlike RAGE1 it does **not**
  translate or link cpctelera — the CPC platform layer is native JSP asm.
- `-subtype=dsk` → `.dsk` (cap32-loadable). `-subtype=none` → tape/`.cpc`.

### The `-o NAME` → `RUN"NAME.` contract

The `-o NAME` becomes the AMSDOS catalog entry: **uppercased, ≤8 chars, empty
extension**. That is the name the screenshot driver's second arg (and a manual
`RUN"NAME.`) must match. JSP test files are `tests/test_*.c`; pick an `-o` name
within the 8-char AMSDOS limit (e.g. `-o SPRMOVE` for `test_sprite_move`) — the
ZX test name does not fit, so the disk/run name is chosen at build time, not
derived from the `.c` filename. `cap32-shot.sh` defaults `RUNNAME` to the `.dsk`
basename uppercased+truncated, so naming the `.dsk` after the `-o` name keeps
the launch automatic.

## Launch gotcha: AMSDOS blank extension

z88dk writes the disk file with an **empty extension** (catalog shows
`POC     .`). `RUN"POC` fails (AMSDOS auto-appends `.BAS`/`.BIN` and finds
nothing) — launch with **`RUN"POC.`** (trailing dot = explicit empty ext).
`cap32-shot.sh` already appends the dot.

## Analysing the capture (ImageMagick)

```bash
convert shot.png -format "mean=%[fx:mean]\n" info:                 # 0 = all black (capture failed)
convert shot.png -depth 8 -format %c histogram:info: | sort -rn | head   # dominant colours
convert shot.png -crop WxH+X+Y +repage -scale 200% crop.png        # zoom a region
```

The **firmware always boots in Mode 1** (bright yellow on dark blue),
*regardless* of your program's target mode — don't mistake that boot banner for
your program's output. If you see the
`Amstrad 128K Microcomputer … BASIC 1.1 … Ready` banner, your program **didn't
run** (or crashed back to firmware). To bisect a crash, build staged versions
that end in `__asm di __endasm; for(;;){}` after each call and check whether the
screen shows your output (ran) vs the banner (crashed/never ran).

## A JSP CPC test must set mode + palette before it renders

The CPC has **no attribute RAM** — colour is in the pixel bits, interpreted
through the gate-array palette. So a JSP CPC test cannot just call `jsp_redraw`
and expect meaningful colour: **before any draw it must (1) set the screen mode**
(the `CPC_MODE*` the binary was built for — the firmware boots in Mode 1, so a
Mode-0/2 build must switch) **and (2) program the palette** so the baked pixel
indices (`doc/CPC-TARGET-PLAN.md` §6) map to the intended inks. A screenshot is
only interpretable relative to that palette. Mode 2 (1 bpp) is the closest to the
ZX reference and the lowest-risk first target, but it still needs the mode set
and the 2-colour ink/paper programmed. (Mode/palette setup is firmware-call or
direct gate-array `out`; keep it in the test harness, not the library.)

## JSP-CPC specifics

- Build one disk per compilation mode (`CPC_MODE0/1/2`, `_MONO`, `_FAST`) via the
  `JSP_TARGET=cpc JSP_CPC_MODE=<mode>` Makefile matrix
  (`doc/CPC-TARGET-PLAN.md` §11). Screenshot each and eyeball-verify.
- The mode-2 (1 bpp) screen is the closest to the ZX reference, so a ZX vs CPC
  side-by-side of the same test is the most direct correctness check for the
  first phases.
- There is **no headless T-state profiler** for CPC equivalent to the JNEXT
  magic-port/heatmap path — performance is eyeballed / wall-clock-timed until a
  CPC profiling path exists (`doc/CPC-TARGET-PLAN.md` §11, risk 5).
