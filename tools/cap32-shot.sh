#!/usr/bin/env bash
# Headless cap32 screenshot driver.
#
# Runs cap32 inside a dedicated Xvfb (a rootful X server) — NOT the live
# Wayland/:0 session, where root-window grabs come back black. Inside Xvfb,
# `import -window root` reliably captures the emulator, and xdotool can drive
# cap32's own F3 screen dump.
#
# Usage:  cd <dir with the .dsk> && /path/to/jsp/tools/cap32-shot.sh [DISKFILE] [CPC_RUN_NAME]
#   DISKFILE     the .dsk to load (defaults to the only *.dsk in $PWD if unambiguous)
#   CPC_RUN_NAME the AMSDOS binary name on the disk (defaults to the .dsk basename,
#                uppercased and truncated to 8 chars — the AMSDOS catalog name)
#   CAP32DIR     env override for the caprice32 install (default ~/src/cpc/caprice32)
set -euo pipefail

DISP=:99
RES="${CAP32_SHOT_RES:-1024x768x24}"

# Default DISK to the single *.dsk in the current dir when not given explicitly.
if [ "${1:-}" ]; then
  DISK="$1"
else
  shopt -s nullglob; dsks=( *.dsk ); shopt -u nullglob
  [ "${#dsks[@]}" -eq 1 ] || { echo "Specify a DISKFILE (found ${#dsks[@]} *.dsk in $PWD)"; exit 1; }
  DISK="${dsks[0]}"
fi
# Default RUNNAME to the .dsk basename, uppercased and truncated to AMSDOS's 8 chars.
RUNNAME="${2:-$(basename "$DISK" .dsk | tr 'a-z' 'A-Z' | cut -c1-8)}"
# Output PNG path: defaults to ./shot.png; the Makefile exports CAP32_SHOT_OUT to
# route it into the build/ directory (cleaner-build layout).
ROOT_SHOT="${CAP32_SHOT_OUT:-$PWD/shot.png}"
LOG=/tmp/cap32-run.log
# cap32's F3 dump lands here (its own clean framebuffer = the FULL CPC raster
# incl. the border in all directions, 768x540 — no Xvfb window/letterbox/scaling
# ambiguity).  This is the artifact we prefer for shot.png; the root grab is a
# fallback if F3 produced nothing.
SDUMP="$(mktemp -d)"

# --- cap32 lives outside PATH and the interactive `cap32` is a shell function
#     ("$CAP32DIR/cap32" -c "$CAP32DIR/cap32.cfg" "$@"). Replicate that here so
#     the emulator finds its ROMs via the cfg.
CAP32DIR="${CAP32DIR:-$HOME/src/cpc/caprice32}"
CAP32_BIN="$CAP32DIR/cap32"
CAP32_CFG="$CAP32DIR/cap32.cfg"

for f in "$CAP32_BIN" "$CAP32_CFG" "$DISK"; do
  [ -e "$f" ] || { echo "MISSING: $f"; exit 1; }
done
for bin in Xvfb xdotool import; do
  command -v "$bin" >/dev/null || { echo "MISSING tool: $bin"; exit 1; }
done

cleanup() { kill "${CAP_PID:-}" "${XVFB_PID:-}" 2>/dev/null || true; rm -rf "$SDUMP"; }
trap cleanup EXIT

# --- 1. Clear any stale server/lock on this display from a previous run.
if [ -e "/tmp/.X${DISP#:}-lock" ]; then
  echo "Display $DISP busy; clearing stale server."
  pkill -f "Xvfb $DISP" 2>/dev/null || true
  sleep 0.5
  rm -f "/tmp/.X${DISP#:}-lock"
fi

# --- 2. Start Xvfb and WAIT until it accepts connections (probe with xdotool,
#        since xdpyinfo isn't installed here).
Xvfb "$DISP" -screen 0 "$RES" >/dev/null 2>&1 &
XVFB_PID=$!
up=
for _ in $(seq 1 50); do
  if DISPLAY="$DISP" xdotool getdisplaygeometry >/dev/null 2>&1; then up=1; break; fi
  sleep 0.1
done
[ -n "$up" ] || { echo "Xvfb never came up"; exit 1; }

# --- 4. Launch the emulator (with its cfg, so ROMs resolve). Keep stderr.
#        Force SDL's X11 backend onto our Xvfb: SDL2 would otherwise follow
#        WAYLAND_DISPLAY to the live compositor (leaving the Xvfb root black).
# NOTE the trailing '.' after the name: z88dk writes the AMSDOS file with an
# EMPTY extension, so `RUN"NAME` (which AMSDOS expands to NAME.BAS/NAME.BIN)
# finds nothing — `RUN"NAME.` selects the empty-extension file explicitly.
# CAP32_SHOT_OPTS lets callers pass extra cap32 flags, e.g.
# CAP32_SHOT_OPTS='-O system.limit_speed=0' to run unlimited-speed — used when
# screenshotting a settling test (for(;;) freeze) so the slower cell model still
# reaches the frozen final frame within CAP32_SHOT_WAIT.
DISPLAY="$DISP" SDL_VIDEODRIVER=x11 WAYLAND_DISPLAY= \
  "$CAP32_BIN" -c "$CAP32_CFG" -O file.sdump_dir="$SDUMP" ${CAP32_SHOT_OPTS:-} \
    -a "run\"$RUNNAME." "$DISK" >"$LOG" 2>&1 &
CAP_PID=$!

# --- 5. Give it time to boot + load (CPC6128 boot is a few seconds).  Override
#        with CAP32_SHOT_WAIT for animated tests that settle at a fixed frame:
#        the two cell models run at different speeds, so the grab must wait until
#        BOTH have reached the frozen final frame for a reproducible comparison.
sleep "${CAP32_SHOT_WAIT:-8}"
if ! kill -0 "$CAP_PID" 2>/dev/null; then
  echo "cap32 exited early. Log:"; cat "$LOG"; exit 1
fi

# --- 6a. Trigger cap32's F3 clean-framebuffer dump — the FULL CPC raster incl.
#         border (768x540), into our $SDUMP.  XSendEvent is ignored by SDL, so
#         focus the window then send F3 via XTEST.
WID=$(DISPLAY="$DISP" xdotool search --name Caprice 2>/dev/null | head -n1 || true)
if [ -n "${WID:-}" ]; then
  DISPLAY="$DISP" xdotool windowactivate --sync "$WID" 2>/dev/null || \
    DISPLAY="$DISP" xdotool windowfocus "$WID" 2>/dev/null || true
  DISPLAY="$DISP" xdotool key --clearmodifiers F3
  sleep 1
fi

# --- 6b. Prefer the F3 dump (clean full-screen framebuffer); fall back to a root
#         grab only if F3 produced nothing.
F3="$(ls -t "$SDUMP"/screenshot_*.png 2>/dev/null | head -n1 || true)"
if [ -n "$F3" ]; then
  cp -f "$F3" "$ROOT_SHOT"
  echo "Wrote $ROOT_SHOT (cap32 F3 framebuffer dump, full screen + border)"
else
  DISPLAY="$DISP" import -window root "$ROOT_SHOT"
  echo "Wrote $ROOT_SHOT (root grab fallback — F3 dump not found)"
fi
