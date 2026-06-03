# JSP-CPC — Tile-Size Model Performance Study

Measured comparison of the **byte-cell** (Model A, current) vs **pixel-cell**
(Model B) cell models, to decide which JSP should use per mode. Companion to
`doc/CPC-TILE-SIZE-ANALYSIS.md` (the qualitative analysis, which deferred the
decision to "measure, not argue"). This file is the measurement record.

## Method

- **Harness:** each sprite test is built with `-DTIME_LIMITED=N` (Makefile
  `CPC_EXTRA_CFLAGS`), which runs exactly N `jsp_redraw()` cycles then `di; rst 0`.
- **Runner:** `tools/cap32-time.sh` runs the `.dsk` headless in cap32 at
  **unlimited speed** (`-O system.limit_speed=0`) with the autocmd sequence
  `run"NAME.` → `CAP32_WAITBREAK` (Z80 breakpoint at addr 0) → `CAP32_EXIT`.
  cap32 stops itself at the `rst 0`; the script reports wall-clock launch→exit
  seconds.
- **Driver:** `make cpc-perf-matrix CYCLES=N` rebuilds + times all 7 sprite
  configs in sequence.
- **Metric meaning:** elapsed = `~1.0s constant boot + k·N`. The constant boot
  overhead **cancels when comparing two models for the same config**, so the
  valid comparison is byte-cell-vs-pixel-cell within one config — *not* across
  configs (which differ in sprite count and motion range). Lower = faster.
- **Caveats:** wall-clock on a loaded host carries ~1–2% noise; timing runs are
  kept **serial** (parallel runs would contend for CPU and corrupt the numbers).
  The cycle counters are `uint16_t`, so `CYCLES` must be **≤ 65535** (a build-time
  `#error` guards this). `test_cpc_sprite_demo.c` also honours `TIME_LIMITED` for
  ad-hoc Mode-2 timing, but it is **not** part of `cpc-perf-matrix` — the 7 matrix
  configs are all built from the 4 bounded sprite tests via `CPC_MODE`.

## Baseline — Model A (byte-cell, current), 1000 cycles

Measured 2026-06-03, `make cpc-perf-matrix CYCLES=1000`.

| Config        | Disk      | Sprites | Elapsed (s) |
|---------------|-----------|--------:|------------:|
| Mode 2        | CPCSPR    | 5       | 7.767       |
| Mode 1        | CPCSPR1   | 5       | 11.236      |
| Mode 1 MONO   | CPCSPRM   | 5       | 16.120      |
| Mode 0        | CPCSPR0   | 4       | 14.294      |
| Mode 2 FAST   | CPCSPR2F  | 5       | 6.741       |
| Mode 0 FAST   | CPCSPR0F  | 4       | 12.866      |
| Mode 1 FAST   | CPCSPR1F  | 5       | 10.023      |

(Mode 0 uses 4 sprites vs 5 elsewhere — do not read across rows; each row is
its own model-vs-model baseline.)

## Model B (pixel-cell) — TBD

_Pending: develop the pixel-cell model, then re-run `cpc-perf-matrix` and fill a
matching table here._

## Comparison & decision — TBD

_Pending: side-by-side table; the official-model choice is the user's after
seeing the comparison._
