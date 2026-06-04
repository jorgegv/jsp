#!/usr/bin/env bash
# Deterministic screenshot of a TIME_LIMITED build (companion to cap32-time.sh).
#
# A TIME_LIMITED=N build runs exactly N redraw cycles then `di; rst 0`.  This
# runs cap32 headless at unlimited speed and uses the SAME autocmd mechanism as
# the performance harness — run"NAME. -> CAP32_WAITBREAK (Z80 breakpoint at
# addr 0) -> CAP32_SCRNSHOT (F3 framebuffer dump) -> CAP32_EXIT — so the capture
# happens exactly when the program reaches frame N, regardless of how fast the
# build runs.  Both cell models therefore screenshot the IDENTICAL frame, which
# a fixed wall-clock wait cannot guarantee (the models run at different speeds).
#
# Usage:  cd <dir with .dsk> && cap32-shot-break.sh DISK [RUNNAME] [OUTPNG]
#   OUTPNG defaults to ./shot.png
set -euo pipefail

DISP=:99
RES=1024x768x24
DISK="$1"
RUNNAME="${2:-$(basename "$DISK" .dsk | tr 'a-z' 'A-Z' | cut -c1-8)}"
OUT="${3:-$PWD/shot.png}"
LOG=/tmp/cap32-shot-break.log

CAP32DIR="${CAP32DIR:-$HOME/src/cpc/caprice32}"
CAP32_BIN="$CAP32DIR/cap32"
CAP32_CFG="$CAP32DIR/cap32.cfg"
DUMPDIR="$(mktemp -d)"

for f in "$CAP32_BIN" "$CAP32_CFG" "$DISK"; do
  [ -e "$f" ] || { echo "MISSING: $f" >&2; exit 1; }
done
command -v Xvfb >/dev/null && command -v xdotool >/dev/null || { echo "MISSING Xvfb/xdotool" >&2; exit 1; }

cleanup() { kill "${CAP_PID:-}" "${XVFB_PID:-}" 2>/dev/null || true; rm -rf "$DUMPDIR"; }
trap cleanup EXIT

if [ -e "/tmp/.X${DISP#:}-lock" ]; then
  pkill -f "Xvfb $DISP" 2>/dev/null || true; sleep 0.5; rm -f "/tmp/.X${DISP#:}-lock"
fi
Xvfb "$DISP" -screen 0 "$RES" >/dev/null 2>&1 &
XVFB_PID=$!
up=
for _ in $(seq 1 50); do
  if DISPLAY="$DISP" xdotool getdisplaygeometry >/dev/null 2>&1; then up=1; break; fi
  sleep 0.1
done
[ -n "$up" ] || { echo "Xvfb never came up" >&2; exit 1; }

# Unlimited speed + redirected dump dir; capture at the rst-0 breakpoint.
DISPLAY="$DISP" SDL_VIDEODRIVER=x11 WAYLAND_DISPLAY= \
  "$CAP32_BIN" -c "$CAP32_CFG" -O system.limit_speed=0 -O file.sdump_dir="$DUMPDIR" \
    -a "run\"$RUNNAME." -a "CAP32_WAITBREAK" -a "CAP32_SCRNSHOT" -a "CAP32_EXIT" \
    "$DISK" >"$LOG" 2>&1 &
CAP_PID=$!

TIMEOUT=${CAP32_BREAK_TIMEOUT:-120}; waited=0
while kill -0 "$CAP_PID" 2>/dev/null; do
  sleep 0.2; waited=$(awk "BEGIN{print $waited+0.2}")
  if awk "BEGIN{exit !($waited > $TIMEOUT)}"; then
    echo "TIMEOUT after ${TIMEOUT}s — never reached rst 0. Log:" >&2; cat "$LOG" >&2; exit 2
  fi
done

shot="$(ls -t "$DUMPDIR"/screenshot_*.png 2>/dev/null | head -n1 || true)"
[ -n "$shot" ] || { echo "No screenshot dumped. Log:" >&2; cat "$LOG" >&2; exit 3; }
cp -f "$shot" "$OUT"
echo "Wrote $OUT (captured at the frame-N breakpoint)"
