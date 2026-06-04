#!/usr/bin/env bash
# Headless cap32 wall-clock timing runner (performance harness).
#
# Companion to cap32-shot.sh: instead of screenshotting, it runs a TIME_LIMITED
# build (one that executes a fixed number of redraw cycles then `rst 0`) at
# UNLIMITED emulator speed and reports the wall-clock seconds cap32 spent from
# launch until the program reached address 0.
#
# Mechanism (caprice32 autocmd virtual events, see src/cap32.cpp):
#   run"NAME.   -> start the program
#   CAP32_WAITBREAK -> set a Z80 breakpoint at address 0 and pause further
#                      virtual events until it is hit (the program's `rst 0`)
#   CAP32_EXIT  -> quit the emulator (fires once the breakpoint is reached)
# Speed limiting is disabled (-O system.limit_speed=0) so wall-clock time is
# proportional to the emulated CPU work, not pinned to the 50 fps CPC rate.
#
# Usage:  cd <dir with the .dsk> && /path/to/jsp/tools/cap32-time.sh [DISKFILE] [CPC_RUN_NAME]
#   Prints: "ELAPSED <seconds>" on stdout (plus diagnostics on stderr).
#   CAP32DIR  env override for the caprice32 install (default ~/src/cpc/caprice32)
set -euo pipefail

DISP=:99
RES=1024x768x24

if [ "${1:-}" ]; then
  DISK="$1"
else
  shopt -s nullglob; dsks=( *.dsk ); shopt -u nullglob
  [ "${#dsks[@]}" -eq 1 ] || { echo "Specify a DISKFILE (found ${#dsks[@]} *.dsk in $PWD)" >&2; exit 1; }
  DISK="${dsks[0]}"
fi
RUNNAME="${2:-$(basename "$DISK" .dsk | tr 'a-z' 'A-Z' | cut -c1-8)}"
LOG=/tmp/cap32-time.log

CAP32DIR="${CAP32DIR:-$HOME/src/cpc/caprice32}"
CAP32_BIN="$CAP32DIR/cap32"
CAP32_CFG="$CAP32DIR/cap32.cfg"

for f in "$CAP32_BIN" "$CAP32_CFG" "$DISK"; do
  [ -e "$f" ] || { echo "MISSING: $f" >&2; exit 1; }
done
for bin in Xvfb xdotool; do
  command -v "$bin" >/dev/null || { echo "MISSING tool: $bin" >&2; exit 1; }
done

cleanup() { kill "${CAP_PID:-}" "${XVFB_PID:-}" 2>/dev/null || true; }
trap cleanup EXIT

# Clear any stale server/lock from a previous run.
if [ -e "/tmp/.X${DISP#:}-lock" ]; then
  pkill -f "Xvfb $DISP" 2>/dev/null || true
  sleep 0.5
  rm -f "/tmp/.X${DISP#:}-lock"
fi

Xvfb "$DISP" -screen 0 "$RES" >/dev/null 2>&1 &
XVFB_PID=$!
up=
for _ in $(seq 1 50); do
  if DISPLAY="$DISP" xdotool getdisplaygeometry >/dev/null 2>&1; then up=1; break; fi
  sleep 0.1
done
[ -n "$up" ] || { echo "Xvfb never came up" >&2; exit 1; }

# Launch cap32 unlimited-speed with the WAITBREAK/EXIT virtual-event sequence,
# and time how long it stays alive (= boot + load + the timed run, until rst 0).
START=$(date +%s.%N)
DISPLAY="$DISP" SDL_VIDEODRIVER=x11 WAYLAND_DISPLAY= \
  "$CAP32_BIN" -c "$CAP32_CFG" -O system.limit_speed=0 \
    -a "run\"$RUNNAME." -a "CAP32_WAITBREAK" -a "CAP32_EXIT" \
    "$DISK" >"$LOG" 2>&1 &
CAP_PID=$!

# Wait for cap32 to exit on its own (CAP32_EXIT after the breakpoint). Guard with
# a hard timeout so a crash/hang doesn't wedge the runner forever.
TIMEOUT=${CAP32_TIME_TIMEOUT:-120}
waited=0
while kill -0 "$CAP_PID" 2>/dev/null; do
  sleep 0.2
  waited=$(awk "BEGIN{print $waited+0.2}")
  if awk "BEGIN{exit !($waited > $TIMEOUT)}"; then
    echo "TIMEOUT after ${TIMEOUT}s — program never reached rst 0. Log:" >&2
    cat "$LOG" >&2
    exit 2
  fi
done
END=$(date +%s.%N)
ELAPSED=$(awk "BEGIN{printf \"%.3f\", $END-$START}")
echo "ELAPSED $ELAPSED"
