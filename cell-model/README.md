# CPC test binary archive — per cell model

Reference `.dsk` builds of the full CPC test set in **both** cell models
(`make cell-model-archive`), so the byte-cell and pixel-cell outputs can be
compared/run without rebuilding. See `doc/CPC-TILE-SIZE-DESIGN.md`.

- `byte/`  — Model A (byte-cell), built with `JSP_CELL_MODEL=byte`
- `pixel/` — Model B (pixel-cell, the default), `JSP_CELL_MODEL=pixel`

Each holds the 7-config sprite matrix (CPCSPR2 Mode 2, CPCSPR1 Mode 1, CPCSPR1M
Mode 1 MONO, CPCSPR0 Mode 0, CPCSPR2F/0F/1F FAST) plus the Mode-2 utility tests
(CPCBG background, CPCFG foreground, CPCTILE btt-redraw).  Run e.g.
`cap32 -a 'run"CPCSPR1.' cell-model/pixel/CPCSPR1.dsk`.
