# Reference screenshots (visual regression baseline)

Committed PNG references for the JSP test programs, for eyeball / pixel
comparison after changes. All captured at a **deterministic frame** so they are
reproducible.

## Layout

- `cpc/byte/`  — CPC tests, byte-cell model (`JSP_CELL_MODEL=byte`)
- `cpc/pixel/` — CPC tests, pixel-cell model (the default), `JSP_CELL_MODEL=pixel`
- `zx/`        — ZX Spectrum tests (48K)

The CPC `byte/` and `pixel/` images are **pixel-identical per test** (the cell
model is internal) — both are kept to document that parity. CPC files are named
after the AMSDOS run name (CPCSPR = Mode 2 sprite, CPCSPR1 = Mode 1, CPCSPRM =
Mode 1 MONO, CPCSPR0 = Mode 0, CPCSPR2F/0F/1F = FAST, CPCBG/CPCFG/CPCTILE = the
Mode-2 background / foreground / btt-redraw utilities).

## Regenerating

**CPC** (768×540 — cap32's own F3 framebuffer dump = the full CPC raster
*including the border in all directions*, no Xvfb window/letterbox/scaling).
Build the **default** (non-`TIME_LIMITED`) test — it ends in `for(;;)`, a tight
spin that *holds* the rendered frame — and run cap32 at **unlimited speed** so the
slower cell model also reaches the frozen final frame (240 for the animated tests)
within the wait. (Do NOT use a `TIME_LIMITED` build for screenshots: its `rst 0`
is the CPC firmware reset, which blanks the screen to blue.)

```sh
make <cpc-target> JSP_CELL_MODEL=<byte|pixel>
CAP32_SHOT_OPTS='-O system.limit_speed=0' CAP32_SHOT_WAIT=10 \
  tools/cap32-shot.sh <NAME>.dsk <NAME>          # shot.png = the F3 dump
cp shot.png tests/refs/cpc/<model>/<NAME>.png
```

**ZX** (640×512 JNEXT headless dump at frame 300):

```sh
make tests/zx/<test>.tap
~/src/spectrum/jnext/build/gui-release/jnext --headless --machine 48k \
  --sd-card ~/src/spectrum/jnext/roms/nextzxos-1gb-fat32fix.img \
  --load tests/zx/<test>.tap \
  --delayed-screenshot tests/refs/zx/<test>.png --delayed-screenshot-frames 300 \
  --delayed-automatic-exit 10
```
