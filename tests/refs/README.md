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

**CPC** (768×540 cap32 framebuffer dump, captured at the `rst 0` breakpoint of a
`TIME_LIMITED` build — both models stop at the identical frame regardless of
speed):

```sh
make <cpc-target> JSP_CELL_MODEL=<byte|pixel> CPC_EXTRA_CFLAGS=-DTIME_LIMITED=<N>
tools/cap32-shot-break.sh <NAME>.dsk <NAME> tests/refs/cpc/<model>/<NAME>.png
#   animated sprite tests: N=240 ; static bg/foreground/btt tests: N=1
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
