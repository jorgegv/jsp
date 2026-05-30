---
name: jnext-emulation
description: Run ZX Spectrum / ZX Spectrum Next programs in the JNEXT emulator — GUI runs, headless PNG screenshots for visual verification, input injection, raw-binary injection, recording and debugging. Use whenever a build (.tap/.sna/.nex/.tzx) must be run, screenshotted, or visually verified, or when driving JNEXT for automated testing.
---

# JNEXT emulation

JNEXT is a ZX Spectrum Next emulator. It can also emulate plain 48K / 128K /
+3 machines. Its big advantage for automated work is **headless mode with a
delayed PNG screenshot**: build a program, run it headless, capture the
screen at a chosen emulated frame, and inspect or pixel-diff the image —
host-CPU-independent and scriptable.

## Binary and SD card

- **Binary** (prefer the release build):
  `~/src/spectrum/jnext/build/gui-release/jnext`
  Fallbacks if absent: `build/gui-debug/jnext`, then `build/jnext`.
- **SD card image — REQUIRED for every invocation.** JNEXT silicon-bakes
  only the FPGA boot ROM; DivMMC, NextZXOS and the 48K/128K/+3 BASIC ROMs
  are read from the SD-card image, exactly like real Next hardware:
  `~/src/spectrum/jnext/roms/nextzxos-1gb-fat32fix.img`

Override either with a leading variable assignment or by editing the
command. `jnext --version` / `jnext --help` print version and option help.

## Quick start

GUI run of a tape (this is what `make run-jnext` does):

```bash
~/src/spectrum/jnext/build/gui-release/jnext \
  --sd-card ~/src/spectrum/jnext/roms/nextzxos-1gb-fat32fix.img \
  --machine 48k --load main.tap
```

Headless screenshot at a chosen frame (the standard verification workflow):

```bash
~/src/spectrum/jnext/build/gui-release/jnext --headless --machine 48k \
  --sd-card ~/src/spectrum/jnext/roms/nextzxos-1gb-fat32fix.img \
  --load tests/test_pool_and_colour.tap \
  --delayed-screenshot /tmp/shot.png --delayed-screenshot-frames 250 \
  --delayed-automatic-exit 8
```

Then read `/tmp/shot.png`. Output is 640×512 (JNEXT's native resolution
for ZX Spectrum modes) — do not scale or convert it.

## Loading programs

- `--load FILE` — load a program; format auto-detected by extension.
  Supported: `.nex`, `.sna`, `.szx`, `.tap`, `.tzx`, `.wav`.
  Tapes auto-load (JNEXT auto-types `LOAD ""` for you).
- `--inject FILE` — load a raw binary blob straight into RAM.
  - `--inject-org ADDR` — load address (hex, default `8000`).
  - `--inject-pc ADDR` — entry point (hex, default = `--inject-org`).
  - `--inject-delay N` — wait N frames before injecting; use ~100 if the
    binary calls ROM routines that need system variables set up first.
- `--tape-realtime` — load tapes at true (slow) tape speed instead of the
  fast trap loader. Normally leave off; the fast loader is fine.

## Machine type

- `--machine TYPE` — `48k`, `128k`, `plus3`, or `next` (default `next`).
  Pick the target the program was built for. For JSP test taps that is
  `48k`.

## Headless mode and screenshots

- `--headless` — run with no display/audio. Required for automated runs;
  the emulator runs at full host speed (no vsync throttle).
- `--delayed-screenshot FILE` — write a PNG screenshot once, after a delay.
- `--delayed-screenshot-time N` — delay in **wall-clock seconds** (default 10).
- `--delayed-screenshot-frames N` — delay in **emulated frames** (overrides
  the `-time` form). Prefer this: it is host-CPU-independent and lets you
  target a precise program state.
- `--delayed-automatic-exit N` — exit the emulator after N **seconds**.
  Always set this in headless runs so the process terminates; make it
  comfortably larger than the wall-clock time needed to reach the
  screenshot frame, or the run exits before the screenshot is written.

### Boot frame budget

`--delayed-screenshot-frames` counts from emulator start, so it includes
the ROM boot + auto-load. Minimum frames before a loaded program is
actually running:

- **48K**: ~150 frames
- **128K**: ~500 frames (boot menu)
- **+3 (plus3)**: ~700 frames (disk-probe pause)

Below these you capture a `LOAD ""` mid-type or a mid-load screen. Add the
number of program frames you want on top of the floor. If the screenshot
shows BASIC text or a loading screen, raise the frame count.

If the program animates at the capture point, two captures may differ —
pick a delay before the animation starts, or drive the program to a
deterministic state with keypresses.

## Driving input (menus, "press any key", …)

- `--delayed-keypress SECS KEY` — press KEY after SECS wall-clock seconds.
- `--delayed-keypress-frames N KEY` — press KEY after N emulated frames
  (overrides the SECS form). Both are repeatable.
- `KEY` is a single character, or symbolic `ENTER` / `RETURN` / `SPACE`
  (case-insensitive).

```bash
... --delayed-keypress-frames 200 SPACE --delayed-keypress-frames 260 ENTER
```

## Speed and timing

- `--speed PERCENT` — emulation speed (`50` = half, `100` = normal,
  `200` = 2×, `400` = 4×). Affects GUI runs; headless already runs flat out.
- `--rewind-buffer-size N` — frame snapshots kept for rewind (default 500,
  `0` disables).

## Debugging

- `--magic-port PORT` — enable a "magic" debug output port at PORT (hex,
  e.g. `0x00FF`). Writes by the emulated program to that port are printed
  by the emulator — a cheap `printf`/trace channel.
- `--magic-port-mode MODE` — how port writes are printed: `hex`, `dec`,
  `ascii`, `line` (default `hex`).
- `--magic-breakpoint` — enable magic breakpoints: the byte sequences
  `ED FF` or `DD 01` in the emulated code trigger the debugger.
- `--log-level SPEC` — per-subsystem log levels, e.g.
  `--log-level cpu=trace,video=warn`.
- `--compositor-trace FILE` — dump a per-pixel compositor trace (CSV) for
  one frame; `--compositor-trace-frame N` selects the frame (default 250).

## Profiling (CPU T-state profiler)

`--profile` enables a per-instruction CPU profiler that accumulates the
**T-states** spent at each executed address — the canonical way to find
JSP's hot code and decide what to optimize next. Cost is branch-gated, so
runs without `--profile` pay nothing.

- `--profile` — enable the profiler. On exit it writes the histogram to
  `--profile-output`.
- `--profile-output FILE` — output path (default `profile.dat`).

The output is a plain-text histogram, one line per touched byte, sorted by
physical key ascending:

```
<phys_hex_6digit> <log_hex_4digit> <tstates_decimal>
```

`phys_hex` is the 21-bit physical SRAM address; `log_hex` is the last
logical PC seen executing from that byte (for 48K code these match the
familiar logical addresses). Join the **logical** column against a z88dk
`.map` file with the bundled Perl tool to get a per-function heatmap:

```bash
~/src/spectrum/jnext/tools/get-function-heatmap.pl -m FILE.map < profile.dat
```

It keeps only `type=addr` symbols in `code*` sections, attributes each
sample's T-states to the enclosing function, and prints
`<function> <accumulated_tstates>` sorted hottest-first. T-states from PCs
below the first code label (ROM, CRT0 boot) are summed and reported on
stderr as a `# skipped …` line — that's normal, not an error.

The JSP build already emits `main.map` (the `zcc -m` flag); test taps get
their map alongside the tap. Full JSP workflow:

```bash
make build          # produces main.tap + main.map
~/src/spectrum/jnext/build/gui-release/jnext --headless --machine 48k \
  --sd-card ~/src/spectrum/jnext/roms/nextzxos-1gb-fat32fix.img \
  --load main.tap \
  --profile --profile-output /tmp/jsp_profile.dat \
  --delayed-automatic-exit 8
~/src/spectrum/jnext/tools/get-function-heatmap.pl -m main.map \
  < /tmp/jsp_profile.dat | head -20
# top lines are the functions burning the most T-states this run
```

Notes:
- The histogram accumulates over the **whole run** (boot + load + program),
  so let the program reach and exercise the code path you care about before
  the automatic exit; drive it with `--delayed-keypress-frames` if needed.
- The tool needs core Perl 5 only (no CPAN).
- Physical-address joins (`bbNNNN` map format) are deferred; v1 joins on the
  logical column, which is what 48K JSP code uses.

## Recording

- `--record FILE` — record video+audio to an MP4 (needs `ffmpeg`).
- `--rzx-record FILE` — record input to an RZX file.
- `--rzx-play FILE` — play back an RZX recording.

## Next / NextZXOS specifics

- `--bypass-tbblue-fw` — skip the `tbblue.fw` firmware boot; load NextZXOS
  directly from the SD image, commit +3 machine type, start the Z80 with
  NextZXOS already in place (no SPACEBAR menu, no firmware loader).
- `--esxdos-stub` — intercept `RST $08`; lets NEX games that expect
  esxdos boot through stubbed file I/O without NextZXOS-loaded esxdos.

## Worked examples (this project)

Screenshot a JSP test tap mid-run and inspect it:

```bash
make tests/test_sprite_move.tap
~/src/spectrum/jnext/build/gui-release/jnext --headless --machine 48k \
  --sd-card ~/src/spectrum/jnext/roms/nextzxos-1gb-fat32fix.img \
  --load tests/test_sprite_move.tap \
  --delayed-screenshot /tmp/move.png --delayed-screenshot-frames 400 \
  --delayed-automatic-exit 10
# then: read /tmp/move.png
```

Sweep several frames to study an animation or a slow redraw:

```bash
for f in 165 200 300 400; do
  ~/src/spectrum/jnext/build/gui-release/jnext --headless --machine 48k \
    --sd-card ~/src/spectrum/jnext/roms/nextzxos-1gb-fat32fix.img \
    --load tests/test_pool_and_colour.tap \
    --delayed-screenshot /tmp/f$f.png --delayed-screenshot-frames $f \
    --delayed-automatic-exit 12 >/dev/null 2>&1
done
```

GUI run of the main harness: `make run-jnext` (see the Makefile).

## Pitfalls

- **`--sd-card` is mandatory** — JNEXT will not boot without it.
- **Set `--delayed-automatic-exit` generously** in headless runs. If it
  fires before the emulator reaches `--delayed-screenshot-frames`, no PNG
  is written. A missing output file usually means the exit was too short.
- **Mind the boot floor.** A blank/`LOAD ""`/loading-stripes screenshot
  means the frame count is below the boot budget for that machine.
- **Match `--machine`** to the program's build target, or it will not run
  (or runs wrong). JSP test taps are `48k`.
- **Screenshots are 640×512.** Inspect them as-is; do not rescale.
- Headless screenshots are the reliable capture path; do not rely on X11
  screen-grab tools (they fail under Wayland/Xwayland).
