# lib/cpc — Amstrad CPC platform layer

CPC-only implementations of the JSP platform primitives (screen addressing,
redraw walk, per-frame precompute, deferred-op grid math, shift/composite
kernels, `jsp_rowcolindex`). Compiled only when `JSP_TARGET=cpc` (the Makefile
selects `lib/$(JSP_TARGET)/`). Populated from Phase 2 onward — see
`doc/CPC-TARGET-PLAN.md` §1.3 and §12.
