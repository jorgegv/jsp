ZCC		= zcc +zx -compiler=sdcc
CFLAGS		= -vn -SO3 --opt-code-size --max-allocs-per-node200000 --list -s --c-code-in-asm -I$(INCLUDE_DIR)
#CFLAGS		= -E -SO3 --opt-code-size --max-allocs-per-node200000 --list -s --c-code-in-asm -I$(INCLUDE_DIR)
LDFLAGS		= -lndos -m

# for a minimal size, replace the above by these:
#ZCC		= zcc +zx -compiler=sdcc -clib=sdcc_iy
#CFLAGS		= -vn -SO3 --opt-code-size --max-allocs-per-node200000 --list -s --c-code-in-asm
#LDFLAGS	= -clib=sdcc_iy -startup=31 -m

BIN		= main
FUSE		= fuse
TAP		=$(BIN).tap

# JNEXT emulator (override on the command line if installed elsewhere)
JNEXT		= $(HOME)/src/spectrum/jnext/build/gui-release/jnext
JNEXT_SD	= $(HOME)/src/spectrum/jnext/roms/nextzxos-1gb-fat32fix.img
JNEXT_MACHINE	= 48k
JNEXT_HEATMAP	= $(HOME)/src/spectrum/jnext/tools/get-function-heatmap.pl

# CPU T-state profiler tunables (override on the command line)
PROFILE_DAT	= /tmp/$(BIN)_profile.dat
PROFILE_EXIT	= 8
PROFILE_TOP	= 25

INCLUDE_DIR	= include

# Platform selection: compile lib/ (platform-independent) plus the platform
# layer in lib/$(JSP_TARGET)/.  Defaults to the ZX target.  See §1.3 of
# doc/CPC-TARGET-PLAN.md.
JSP_TARGET	?= zx
PLATDIR		= lib/$(JSP_TARGET)

C_SRCS		= $(wildcard lib/*.c) $(wildcard $(PLATDIR)/*.c) $(wildcard *.c)
ASM_SRCS	= $(wildcard lib/*.asm) $(wildcard $(PLATDIR)/*.asm) $(wildcard *.asm)

C_OBJS		= $(C_SRCS:.c=.o)
ASM_OBJS	= $(ASM_SRCS:.asm=.o)

# sprite pixel data referenced by the main.c test harness; these .asm files
# live under tests/ (generated from PNGs) so they are not picked up by the
# wildcards above and must be linked into the main binary explicitly.
BIN_ASSET_ASMS	= tests/test_sprite_mask2.asm tests/test_sprite_load1.asm
BIN_ASSET_OBJS	= $(BIN_ASSET_ASMS:.asm=.o)

.SILENT:
MAKEFLAGS 	+= --no-print-directory -j4

.PHONY: help default build clean run run-jnext profile tests run-test bench bench-mask2 bench-sp1 bench-sp1-mask2 clean-tests cpc-bg run-cpc-bg cpc-sprite run-cpc-sprite cpc-sprite-demo-mode2 cpc-shift-test-mode2 cpc-shift-test-mode1 cpc-shift-test-mode1-mono cpc-shift-test-mode0 cpc-sprite-mode1 run-cpc-sprite-mode1 cpc-sprite-mode1-mono run-cpc-sprite-mode1-mono cpc-sprite-mode0 run-cpc-sprite-mode0 cpc-sprite-mode2-fast run-cpc-sprite-mode2-fast cpc-sprite-mode0-fast run-cpc-sprite-mode0-fast cpc-sprite-mode1-fast run-cpc-sprite-mode1-fast cpc-matrix run-cpc-matrix cpc-perf-matrix cpc-bg-mode1-pixcell run-cpc-bg-mode1-pixcell cpc-foreground run-cpc-foreground cpc-btt-redraw run-cpc-btt-redraw

## Self-documenting help — `make` with no target lists every target that has
## a `#` comment on the line immediately above it (names print in bold red).
.DEFAULT_GOAL := help

# Show this help
help:
	@if [ -t 1 ] && [ -z "$$NO_COLOR" ]; then c='\033[1;31m'; r='\033[0m'; else c=; r=; fi; \
	awk -v c="$$c" -v r="$$r" 'BEGIN { FS = ":" } \
		/^# / { desc = substr($$0, 3); next } \
		/^[a-zA-Z0-9][a-zA-Z0-9_.-]*:($$|[^=])/ { \
			if (desc != "") { printf "  %s%-18s%s %s\n", c, $$1, r, desc; desc = "" } \
			next \
		} \
		{ desc = "" }' $(MAKEFILE_LIST)

## generic rules
%.o: %.c
	echo Compiling $*.c...
	$(ZCC) $(CFLAGS) -c $*.c

%.o: %.asm
	echo Assembling $*.asm...
	$(ZCC) $(CFLAGS) -c $*.asm

# Build main.tap incrementally
default: $(BIN)

# Clean rebuild — produces main.tap
build:
	make clean
	make $(TAP)
	echo Build successful

# Remove all build artifacts
clean: clean-tests
	echo Cleaning up...
	-rm -f $(BIN) $(TAP) *.{map,lst,o,lis,sym,bin} 2>/dev/null
	-rm -f lib/*.{map,lst,o,lis,sym,bin} 2>/dev/null
	-rm -f lib/zx/*.{map,lst,o,lis,sym,bin} lib/cpc/*.{map,lst,o,lis,sym,bin} 2>/dev/null

## binary
$(BIN): $(ASM_OBJS) $(C_OBJS) $(BIN_ASSET_OBJS)
	echo Linking $@...
	$(ZCC) $(LDFLAGS) $(ASM_OBJS) $(C_OBJS) $(BIN_ASSET_OBJS) -o $(BIN) -create-app
	echo Created $(TAP)

$(TAP): $(BIN)

# JSP_CPC_MODE selects which CPC config `make run JSP_TARGET=cpc` builds and
# screenshots.  Tokens match the CPC_MODE guard suffix: 2 1 0 1_MONO 2_FAST
# 0_FAST 1_FAST (see the build matrix below).  Default: Mode 2 (closest to ZX).
JSP_CPC_MODE		?= 2
CPC_RUNTGT_2		= run-cpc-sprite
CPC_RUNTGT_1		= run-cpc-sprite-mode1
CPC_RUNTGT_1_MONO	= run-cpc-sprite-mode1-mono
CPC_RUNTGT_0		= run-cpc-sprite-mode0
CPC_RUNTGT_2_FAST	= run-cpc-sprite-mode2-fast
CPC_RUNTGT_0_FAST	= run-cpc-sprite-mode0-fast
CPC_RUNTGT_1_FAST	= run-cpc-sprite-mode1-fast

ifeq ($(JSP_TARGET),cpc)
run:
	$(MAKE) $(CPC_RUNTGT_$(JSP_CPC_MODE))
else
# Launch in FUSE (ZX); with JSP_TARGET=cpc [JSP_CPC_MODE=N] build+screenshot in cap32
run: $(TAP)
	$(FUSE) $(TAP)
endif

# Build and launch main.tap in the JNEXT emulator (GUI)
run-jnext: $(TAP)
	$(JNEXT) --sd-card $(JNEXT_SD) --machine $(JNEXT_MACHINE) --load $(TAP)

# Profile main.tap headless and print the hottest functions (T-state heatmap)
profile: $(TAP)
	echo Profiling $(TAP) for $(PROFILE_EXIT)s...
	$(JNEXT) --headless --machine $(JNEXT_MACHINE) --sd-card $(JNEXT_SD) \
		--load $(TAP) --profile --profile-output $(PROFILE_DAT) \
		--delayed-automatic-exit $(PROFILE_EXIT) >/dev/null 2>&1
	echo "Top $(PROFILE_TOP) functions by T-states:"
	$(JNEXT_HEATMAP) -m $(BIN).map < $(PROFILE_DAT) 2>/dev/null | head -$(PROFILE_TOP)

## tests

# Test programs are split by platform, mirroring the lib/ layout: shared
# generated sprite assets live in tests/ (like lib/*.asm), ZX test programs in
# tests/zx/, CPC test programs in tests/cpc/.
TESTS_DIR	= tests
ZXTEST_DIR	= tests/zx
CPCTEST_DIR	= tests/cpc
LIB_SRCS	= $(wildcard lib/*.c) $(wildcard lib/*.asm) \
		  $(wildcard $(PLATDIR)/*.c) $(wildcard $(PLATDIR)/*.asm)

SPRITE_MASK2_ASM = $(TESTS_DIR)/test_sprite_mask2.asm
SPRITE_LOAD1_ASM = $(TESTS_DIR)/test_sprite_load1.asm
SPRITE_MASK2_M1_ASM = $(TESTS_DIR)/test_sprite_mask2_m1.asm
SPRITE_LOAD1_M1_ASM = $(TESTS_DIR)/test_sprite_load1_m1.asm
SPRITE_MASK2_M0_ASM = $(TESTS_DIR)/test_sprite_mask2_m0.asm
SPRITE_LOAD1_M0_ASM = $(TESTS_DIR)/test_sprite_load1_m0.asm

TESTS		= test_dtt test_btt_contents test_btt_redraw test_sprite_draw \
		  test_sprite_move test_pool_and_colour test_tiles_and_print \
		  test_foreground_tiles test_redraw_bench
TEST_TAPS	= $(TESTS:%=$(ZXTEST_DIR)/%.tap)

# Build all (ZX) test taps
tests: $(TEST_TAPS)

## Pattern rule: compile test + all lib sources in one zcc invocation
$(ZXTEST_DIR)/%.tap: $(ZXTEST_DIR)/%.c $(LIB_SRCS)
	echo Building $@...
	$(ZCC) $(CFLAGS) $(LDFLAGS) $^ -o $(@:.tap=.bin) -create-app

## Extra sprite data prerequisites for tests that use sprites
$(ZXTEST_DIR)/test_sprite_draw.tap: $(SPRITE_MASK2_ASM)
$(ZXTEST_DIR)/test_sprite_move.tap: $(SPRITE_MASK2_ASM) $(SPRITE_LOAD1_ASM)
$(ZXTEST_DIR)/test_pool_and_colour.tap: $(SPRITE_MASK2_ASM)
$(ZXTEST_DIR)/test_foreground_tiles.tap: $(SPRITE_MASK2_ASM)
$(ZXTEST_DIR)/test_redraw_bench.tap: $(SPRITE_MASK2_ASM) $(SPRITE_LOAD1_ASM)

# Build and launch one test in FUSE (usage: make run-test TEST=test_dtt)
run-test: $(ZXTEST_DIR)/$(TEST).tap
	fuse $(ZXTEST_DIR)/$(TEST).tap

# Build and run the redraw speed benchmark headless in JNEXT
bench: $(ZXTEST_DIR)/test_redraw_bench.tap
	$(JNEXT) --headless --machine $(JNEXT_MACHINE) --sd-card $(JNEXT_SD) \
		--load $< --magic-port 0x00FF --magic-port-mode ascii \
		--delayed-automatic-exit 300 2>&1 | grep -E '^(A0?=|B=|END)'

# Run the JSP redraw benchmark with an all-MASK2 sprite workload
bench-mask2: $(SPRITE_MASK2_ASM)
	echo Building all-MASK2 JSP benchmark...
	$(ZCC) $(CFLAGS) $(LDFLAGS) -DBENCH_ALL_MASK2 \
		$(ZXTEST_DIR)/test_redraw_bench.c $(LIB_SRCS) $(SPRITE_MASK2_ASM) \
		-o $(ZXTEST_DIR)/test_redraw_bench_mask2.bin -create-app
	$(JNEXT) --headless --machine $(JNEXT_MACHINE) --sd-card $(JNEXT_SD) \
		--load $(ZXTEST_DIR)/test_redraw_bench_mask2.tap \
		--magic-port 0x00FF --magic-port-mode ascii \
		--delayed-automatic-exit 300 2>&1 | grep -E '^(A0?=|B=|END)'

## SP1 benchmark — standalone SP1 program, built with the z88dk new C
## library (-clib=sdcc_iy): sdcc then uses IY as its frame pointer, so
## SP1's asm (which trashes IX) does not corrupt C frames.  No JSP sources.
$(ZXTEST_DIR)/bench_sp1.tap: $(ZXTEST_DIR)/bench_sp1.c
	echo Building $@...
	$(ZCC) -vn -SO3 --max-allocs-per-node200000 -startup=31 -clib=sdcc_iy -m \
		$< -o $(@:.tap=.bin) -create-app

# Build and run the SP1 redraw benchmark headless (JSP-vs-SP1 comparison)
bench-sp1: $(ZXTEST_DIR)/bench_sp1.tap
	$(JNEXT) --headless --machine $(JNEXT_MACHINE) --sd-card $(JNEXT_SD) \
		--load $< --magic-port 0x00FF --magic-port-mode ascii \
		--delayed-automatic-exit 600 2>&1 | grep -E '^(A0?=|B=|END)'

# Run the SP1 redraw benchmark with an all-MASK2 sprite workload
bench-sp1-mask2:
	echo Building all-MASK2 SP1 benchmark...
	$(ZCC) -vn -SO3 --max-allocs-per-node200000 -startup=31 -clib=sdcc_iy -m \
		-DBENCH_ALL_MASK2 $(ZXTEST_DIR)/bench_sp1.c \
		-o $(ZXTEST_DIR)/bench_sp1_mask2.bin -create-app
	$(JNEXT) --headless --machine $(JNEXT_MACHINE) --sd-card $(JNEXT_SD) \
		--load $(ZXTEST_DIR)/bench_sp1_mask2.tap \
		--magic-port 0x00FF --magic-port-mode ascii \
		--delayed-automatic-exit 600 2>&1 | grep -E '^(A0?=|B=|END)'

clean-tests:
	echo Cleaning tests...
	-rm -f $(TEST_TAPS) $(TESTS:%=$(ZXTEST_DIR)/%.bin) 2>/dev/null
	-rm -f $(ZXTEST_DIR)/bench_sp1.tap $(ZXTEST_DIR)/bench_sp1_mask2.tap 2>/dev/null
	-rm -f $(ZXTEST_DIR)/test_redraw_bench_mask2.tap 2>/dev/null
	-rm -f $(TESTS_DIR)/*.{map,lst,o,lis,sym,bin} 2>/dev/null
	-rm -f $(ZXTEST_DIR)/*.{map,lst,o,lis,sym,bin} 2>/dev/null
	-rm -f $(CPCTEST_DIR)/*.{map,lst,o,lis,sym,bin} 2>/dev/null

## CPC (Phase 2) — build the Mode 2 background test as a .dsk (zcc +cpc).
## Compiles lib/ (shared) + lib/cpc/ (CPC platform layer), per JSP_TARGET dir
## selection (§1.3). JSP_TARGET_CPC + CPC_MODE2 passed to both C (-D) and asm
## (-Ca-D). A fuller JSP_TARGET/JSP_CPC_MODE build matrix is Phase 9.
CPC_BG_NAME	= CPCBG
CPC_MODE	?= 2
# REGISTER_SP=0x9800 places the stack just below the JSP data block (BAT base,
# see lib/jsp_data.c): the firmware default SP sits high (~0xB000-0xBFFF) and
# would overlap the rottbl (0xB200-0xBFFF), corrupting it — invisible until
# sprites read the rottbl (Phase 3); the phase-7 carry page 0xBF00-0xBFFF is
# right where the stack grows, so only xrot=7 sprites streaked.
CPC_CFLAGS	= -DJSP_TARGET_CPC -Ca-DJSP_TARGET_CPC \
		  -DCPC_MODE$(CPC_MODE) -Ca-DCPC_MODE$(CPC_MODE) \
		  -pragma-define:REGISTER_SP=0x9800 \
		  -SO2 --max-allocs-per-node200000 -I$(INCLUDE_DIR) \
		  $(CPC_EXTRA_CFLAGS)
# Appended to CPC_CFLAGS for ad-hoc/perf builds (e.g. CPC_EXTRA_CFLAGS=-DTIME_LIMITED=1000).
CPC_EXTRA_CFLAGS ?=

# Cell model: "byte" (default, Model A — 8-byte cells, 80x25 every mode) or
# "pixel" (Model B — 8x8-PIXEL cells: 20/40/80 cols, 32/16/8-byte cells for
# M0/M1/M2; M2 identical to byte).  Defines the single global JSP_CELL_MODEL_PIXEL
# switch for both the C compiler and the asm (-Ca).  Used by every CPC build/perf
# target, e.g.:  make cpc-perf-matrix JSP_CELL_MODEL=pixel
JSP_CELL_MODEL ?= byte
ifeq ($(JSP_CELL_MODEL),pixel)
CPC_CFLAGS += -DJSP_CELL_MODEL_PIXEL -Ca-DJSP_CELL_MODEL_PIXEL
endif
CPC_LIB_SRCS	= $(wildcard lib/*.c) $(wildcard lib/*.asm) $(wildcard lib/cpc/*.asm)

# Build the CPC Mode 2 background test (.dsk)
cpc-bg:
	echo Building CPC Mode $(CPC_MODE) background test...
	zcc +cpc -compiler=sdcc $(CPC_CFLAGS) -create-app -subtype=dsk \
		$(CPCTEST_DIR)/test_cpc_bg.c $(CPC_LIB_SRCS) -o $(CPC_BG_NAME) -m
	echo "Created $(CPC_BG_NAME).dsk"

# Build and screenshot the CPC background test headless in cap32
run-cpc-bg: cpc-bg
	./tools/cap32-shot.sh $(CPC_BG_NAME).dsk $(CPC_BG_NAME)

## Model-B (pixel-cell) Phase-1 verification: Mode-1 background, 40x25 grid,
## 16-byte column-major box tiles tiled edge-to-edge.  Forces the pixel-cell
## switch in the recipe (not via JSP_CELL_MODEL, so it builds standalone).
CPC_BGP1_NAME	= CPCBGP1
cpc-bg-mode1-pixcell: CPC_MODE := 1
cpc-bg-mode1-pixcell:
	echo Building CPC Mode 1 PIXEL-CELL background test...
	zcc +cpc -compiler=sdcc $(CPC_CFLAGS) -DJSP_CELL_MODEL_PIXEL -Ca-DJSP_CELL_MODEL_PIXEL \
		-create-app -subtype=dsk \
		$(CPCTEST_DIR)/test_cpc_bg_mode1_pixcell.c $(CPC_LIB_SRCS) -o $(CPC_BGP1_NAME) -m
	echo "Created $(CPC_BGP1_NAME).dsk"

# Build and screenshot the Model-B Mode-1 background test headless in cap32
run-cpc-bg-mode1-pixcell: cpc-bg-mode1-pixcell
	./tools/cap32-shot.sh $(CPC_BGP1_NAME).dsk $(CPC_BGP1_NAME)

## CPC (Phase 3) — masked, sub-byte-shifted Mode 2 sprites over a background.
## Same toolchain as cpc-bg; additionally links the (1bpp) mask2 sprite asset
## and exercises the lib/cpc kernels + covered-cell compositor.
CPC_SPR_NAME	= CPCSPR
CPC_SPRD_NAME	= CPCSPRD

# Build the CPC Mode 2 sprite test (.dsk) — settles to a still frame
cpc-sprite: $(SPRITE_MASK2_ASM)
	echo Building CPC Mode $(CPC_MODE) sprite test...
	zcc +cpc -compiler=sdcc $(CPC_CFLAGS) -create-app -subtype=dsk \
		$(CPCTEST_DIR)/test_cpc_sprite.c $(SPRITE_MASK2_ASM) $(CPC_LIB_SRCS) \
		-o $(CPC_SPR_NAME) -m
	echo "Created $(CPC_SPR_NAME).dsk"

# Build and screenshot the CPC sprite test headless in cap32
run-cpc-sprite: cpc-sprite
	./tools/cap32-shot.sh $(CPC_SPR_NAME).dsk $(CPC_SPR_NAME)

## CPC (Phase 6) — Mode 1 (4-colour, ppb=4) sprite test.  Same engine as Mode 2;
## links the Mode-1 two-nibble-plane ball asset (cols=4) and builds with
## CPC_MODE=1 (passes CPC_MODE1 to C + asm -> ppb=4 split, 3-phase rottbl).
CPC_SPR_M1_NAME	= CPCSPR1

# Build the CPC Mode 1 sprite test (.dsk) — settles to a still frame
cpc-sprite-mode1: CPC_MODE := 1
cpc-sprite-mode1: $(SPRITE_MASK2_M1_ASM)
	echo Building CPC Mode 1 sprite test...
	zcc +cpc -compiler=sdcc $(CPC_CFLAGS) -create-app -subtype=dsk \
		$(CPCTEST_DIR)/test_cpc_sprite_mode1.c $(SPRITE_MASK2_M1_ASM) $(CPC_LIB_SRCS) \
		-o $(CPC_SPR_M1_NAME) -m
	echo "Created $(CPC_SPR_M1_NAME).dsk"

# Build and screenshot the CPC Mode 1 sprite test headless in cap32
run-cpc-sprite-mode1: cpc-sprite-mode1
	./tools/cap32-shot.sh $(CPC_SPR_M1_NAME).dsk $(CPC_SPR_M1_NAME)

## CPC (Phase 6.1) — Mode 1 MONO: 1bpp (Mode-2 format) sprites on a Mode-1
## screen, expanded to Mode-1 in the covered-cell compositor (jsp_covered_mono).
## Links the UNCHANGED 1bpp ball asset (cols=2); builds with CPC_MODE=1_MONO ->
## -DCPC_MODE1_MONO to C + asm.
CPC_SPR_M1M_NAME = CPCSPRM

# Build the CPC Mode 1 MONO sprite test (.dsk) — settles to a still frame
cpc-sprite-mode1-mono: CPC_MODE := 1_MONO
cpc-sprite-mode1-mono: $(SPRITE_MASK2_ASM)
	echo Building CPC Mode 1 MONO sprite test...
	zcc +cpc -compiler=sdcc $(CPC_CFLAGS) -create-app -subtype=dsk \
		$(CPCTEST_DIR)/test_cpc_sprite_mode1_mono.c $(SPRITE_MASK2_ASM) $(CPC_LIB_SRCS) \
		-o $(CPC_SPR_M1M_NAME) -m
	echo "Created $(CPC_SPR_M1M_NAME).dsk"

# Build and screenshot the CPC Mode 1 MONO sprite test headless in cap32
run-cpc-sprite-mode1-mono: cpc-sprite-mode1-mono
	./tools/cap32-shot.sh $(CPC_SPR_M1M_NAME).dsk $(CPC_SPR_M1M_NAME)

## CPC (Phase 7) — Mode 0 (16-colour, ppb=2) sprite test.  Same engine as M1/M2
## (byte-cell model); links the Mode-0 interleaved ball asset (cols=8) and builds
## with CPC_MODE=0 (passes CPC_MODE0 to C + asm -> ppb=2, single-phase rottbl).
CPC_SPR_M0_NAME	= CPCSPR0

# Build the CPC Mode 0 sprite test (.dsk) — settles to a still frame
cpc-sprite-mode0: CPC_MODE := 0
cpc-sprite-mode0: $(SPRITE_MASK2_M0_ASM)
	echo Building CPC Mode 0 sprite test...
	zcc +cpc -compiler=sdcc $(CPC_CFLAGS) -create-app -subtype=dsk \
		$(CPCTEST_DIR)/test_cpc_sprite_mode0.c $(SPRITE_MASK2_M0_ASM) $(CPC_LIB_SRCS) \
		-o $(CPC_SPR_M0_NAME) -m
	echo "Created $(CPC_SPR_M0_NAME).dsk"

# Build and screenshot the CPC Mode 0 sprite test headless in cap32
run-cpc-sprite-mode0: cpc-sprite-mode0
	./tools/cap32-shot.sh $(CPC_SPR_M0_NAME).dsk $(CPC_SPR_M0_NAME)

## CPC (Phase 8) — FAST variants: byte-aligned sprites (xrot forced to 0), no
## shift table, NR kernel only.  Built from the SAME Mode 0/1 sprite tests +
## assets with CPC_MODE=0_FAST / 1_FAST -> -DCPC_MODE0_FAST / -DCPC_MODE1_FAST.
## The geom include forces JSP_XROT_MASK=0 (xrot always 0) and JSP_SHIFT_PHASES=0
## (jsp_init_rottbl builds no table); the lb/middle kernels already redirect the
## aligned case (rottbl_msb == jsp_rottbl/256 - 2) to the NR kernel, so FAST needs
## no new kernels — only the compile-time guards.  Visibly: sprite0 (1 px/frame)
## snaps to 8-px (M2) / 2-px (M0) / 4-px (M1) byte boundaries instead of sub-pixel
## stepping.  Mode 2 FAST claws back the most RAM (the M2 rottbl is the largest).
CPC_SPR_M2F_NAME = CPCSPR2F
CPC_SPR_M0F_NAME = CPCSPR0F
CPC_SPR_M1F_NAME = CPCSPR1F

# Build the CPC Mode 2 FAST sprite test (.dsk) — byte-aligned (8-px) sprites
cpc-sprite-mode2-fast: CPC_MODE := 2_FAST
cpc-sprite-mode2-fast: $(SPRITE_MASK2_ASM)
	echo Building CPC Mode 2 FAST sprite test...
	zcc +cpc -compiler=sdcc $(CPC_CFLAGS) -create-app -subtype=dsk \
		$(CPCTEST_DIR)/test_cpc_sprite.c $(SPRITE_MASK2_ASM) $(CPC_LIB_SRCS) \
		-o $(CPC_SPR_M2F_NAME) -m
	echo "Created $(CPC_SPR_M2F_NAME).dsk"

# Build and screenshot the CPC Mode 2 FAST sprite test headless in cap32
run-cpc-sprite-mode2-fast: cpc-sprite-mode2-fast
	./tools/cap32-shot.sh $(CPC_SPR_M2F_NAME).dsk $(CPC_SPR_M2F_NAME)

# Build the CPC Mode 0 FAST sprite test (.dsk) — byte-aligned (2-px) sprites
cpc-sprite-mode0-fast: CPC_MODE := 0_FAST
cpc-sprite-mode0-fast: $(SPRITE_MASK2_M0_ASM)
	echo Building CPC Mode 0 FAST sprite test...
	zcc +cpc -compiler=sdcc $(CPC_CFLAGS) -create-app -subtype=dsk \
		$(CPCTEST_DIR)/test_cpc_sprite_mode0.c $(SPRITE_MASK2_M0_ASM) $(CPC_LIB_SRCS) \
		-o $(CPC_SPR_M0F_NAME) -m
	echo "Created $(CPC_SPR_M0F_NAME).dsk"

# Build and screenshot the CPC Mode 0 FAST sprite test headless in cap32
run-cpc-sprite-mode0-fast: cpc-sprite-mode0-fast
	./tools/cap32-shot.sh $(CPC_SPR_M0F_NAME).dsk $(CPC_SPR_M0F_NAME)

# Build the CPC Mode 1 FAST sprite test (.dsk) — byte-aligned (4-px) sprites
cpc-sprite-mode1-fast: CPC_MODE := 1_FAST
cpc-sprite-mode1-fast: $(SPRITE_MASK2_M1_ASM)
	echo Building CPC Mode 1 FAST sprite test...
	zcc +cpc -compiler=sdcc $(CPC_CFLAGS) -create-app -subtype=dsk \
		$(CPCTEST_DIR)/test_cpc_sprite_mode1.c $(SPRITE_MASK2_M1_ASM) $(CPC_LIB_SRCS) \
		-o $(CPC_SPR_M1F_NAME) -m
	echo "Created $(CPC_SPR_M1F_NAME).dsk"

# Build and screenshot the CPC Mode 1 FAST sprite test headless in cap32
run-cpc-sprite-mode1-fast: cpc-sprite-mode1-fast
	./tools/cap32-shot.sh $(CPC_SPR_M1F_NAME).dsk $(CPC_SPR_M1F_NAME)

## CPC (Phase 9) — the full build matrix.  The eight JSP_CPC_MODE configs
## (Mode 2/1/0 + Mode 1 MONO + Mode 2/0/1 FAST) over the one engine.  Each is
## the SAME sprite test recompiled with its mode guard; cpc-matrix builds them
## all serially (via recursive $(MAKE) so the shared lib objects are not raced
## by -j4), run-cpc-matrix additionally screenshots each into screenshot_<tgt>.png.
CPC_BUILD_TARGETS = cpc-sprite cpc-sprite-mode1 cpc-sprite-mode1-mono \
		    cpc-sprite-mode0 cpc-sprite-mode2-fast cpc-sprite-mode0-fast \
		    cpc-sprite-mode1-fast
CPC_RUN_TARGETS	  = run-cpc-sprite run-cpc-sprite-mode1 run-cpc-sprite-mode1-mono \
		    run-cpc-sprite-mode0 run-cpc-sprite-mode2-fast \
		    run-cpc-sprite-mode0-fast run-cpc-sprite-mode1-fast

# Build every CPC config's sprite test (the full mode matrix; no emulator)
cpc-matrix:
	for t in $(CPC_BUILD_TARGETS); do $(MAKE) $$t || exit 1; done
	echo "CPC build matrix complete ($(words $(CPC_BUILD_TARGETS)) configs)."

# Build + screenshot every CPC config (screenshot_<target>.png per mode)
run-cpc-matrix:
	for t in $(CPC_RUN_TARGETS); do \
		$(MAKE) $$t || exit 1; \
		cp -f shot.png screenshot_$$t.png; \
	done
	echo "CPC run matrix complete; see screenshot_run-cpc-*.png."

## CPC performance harness — wall-clock redraw timing for the tile-size-model
## study.  Each of the 7 sprite configs is rebuilt with -DTIME_LIMITED=$(CYCLES)
## (runs exactly CYCLES redraw cycles then `rst 0`) and run headless at unlimited
## emulator speed via tools/cap32-time.sh, which stops cap32 at the `rst 0` and
## reports wall-clock launch->exit seconds.  Override CYCLES (default 1000).
## Format: "<build-target>:<AMSDOS/disk name>"; build pairs map to CPC_SPR_*_NAME.
CYCLES		?= 1000
CPC_PERF_PAIRS	= cpc-sprite:$(CPC_SPR_NAME) \
		  cpc-sprite-mode1:$(CPC_SPR_M1_NAME) \
		  cpc-sprite-mode1-mono:$(CPC_SPR_M1M_NAME) \
		  cpc-sprite-mode0:$(CPC_SPR_M0_NAME) \
		  cpc-sprite-mode2-fast:$(CPC_SPR_M2F_NAME) \
		  cpc-sprite-mode0-fast:$(CPC_SPR_M0F_NAME) \
		  cpc-sprite-mode1-fast:$(CPC_SPR_M1F_NAME)

# Time the redraw of every CPC sprite config (TIME_LIMITED=$(CYCLES)); prints a table
cpc-perf-matrix:
	@echo "CPC redraw timing — $(CYCLES) cycles/config (wall-clock s, lower is faster)"
	@for pair in $(CPC_PERF_PAIRS); do \
		t="$${pair%%:*}"; n="$${pair##*:}"; \
		$(MAKE) $$t CPC_EXTRA_CFLAGS="-DTIME_LIMITED=$(CYCLES)" >/dev/null || { echo "BUILD FAILED: $$t (stderr above)"; exit 1; }; \
		printf "%-24s " "$$n"; \
		./tools/cap32-time.sh $$n.dsk $$n 2>/dev/null || echo "RUN FAILED"; \
	done

# Build the CPC Mode 2 sprite DEMO (.dsk) — balls bounce continuously (watch live: cap32 -a 'run"CPCSPRD.' CPCSPRD.dsk)
cpc-sprite-demo-mode2: $(SPRITE_MASK2_ASM)
	echo Building CPC Mode 2 sprite demo...
	zcc +cpc -compiler=sdcc $(CPC_CFLAGS) -create-app -subtype=dsk \
		$(CPCTEST_DIR)/test_cpc_sprite_demo.c $(SPRITE_MASK2_ASM) $(CPC_LIB_SRCS) \
		-o $(CPC_SPRD_NAME) -m
	echo "Created $(CPC_SPRD_NAME).dsk  (run:  cap32 -a 'run\"$(CPC_SPRD_NAME).' $(CPC_SPRD_NAME).dsk)"

HOSTCC		?= cc
# Mode 2 shift/mask unit test (host cc, no emulator): validates the jsp_rottbl masks + combine vs a true 16-bit shift
cpc-shift-test-mode2: $(SPRITE_MASK2_ASM)
	$(HOSTCC) -O2 -Wall -I$(INCLUDE_DIR) -o $(CPCTEST_DIR)/shift_test_mode2 $(CPCTEST_DIR)/shift_test_mode2.c
	$(CPCTEST_DIR)/shift_test_mode2 $(SPRITE_MASK2_ASM)

# Mode 1 shift/mask unit test (host cc): validates the Mode-1 nibble-plane masks vs an independent pixel-array shift
cpc-shift-test-mode1: $(SPRITE_MASK2_M1_ASM)
	$(HOSTCC) -O2 -Wall -DCPC_MODE1 -I$(INCLUDE_DIR) -o $(CPCTEST_DIR)/shift_test_mode1 $(CPCTEST_DIR)/shift_test_mode1.c
	$(CPCTEST_DIR)/shift_test_mode1 $(SPRITE_MASK2_M1_ASM)

# Mode 1 MONO unit test (host cc): validates the 1bpp->Mode-1 nibble expansion + combine vs a true monochrome shift
cpc-shift-test-mode1-mono: $(SPRITE_MASK2_ASM)
	$(HOSTCC) -O2 -Wall -DCPC_MODE1_MONO -I$(INCLUDE_DIR) -o $(CPCTEST_DIR)/shift_test_mode1_mono $(CPCTEST_DIR)/shift_test_mode1_mono.c
	$(CPCTEST_DIR)/shift_test_mode1_mono $(SPRITE_MASK2_ASM)

# Mode 0 shift/mask unit test (host cc): validates the Mode-0 odd/even interleave masks vs an independent pixel-array shift
cpc-shift-test-mode0: $(SPRITE_MASK2_M0_ASM)
	$(HOSTCC) -O2 -Wall -DCPC_MODE0 -I$(INCLUDE_DIR) -o $(CPCTEST_DIR)/shift_test_mode0 $(CPCTEST_DIR)/shift_test_mode0.c
	$(CPCTEST_DIR)/shift_test_mode0 $(SPRITE_MASK2_M0_ASM)

## CPC (Phase 5) — Mode 2 ports of the ZX functional tests (same layout, CPC
## mode setup, geometric tiles).  printf-console tests (dtt, btt_contents) and
## the font/text test (tiles_and_print) are ZX-only for now — see the tasklist.
CPC_FG_NAME	= CPCFG
CPC_TILE_NAME	= CPCTILE

# Build the CPC Mode 2 foreground-tiles + sprite-pool test (sprites pass behind)
cpc-foreground: $(SPRITE_MASK2_ASM)
	echo Building CPC Mode 2 foreground test...
	zcc +cpc -compiler=sdcc $(CPC_CFLAGS) -create-app -subtype=dsk \
		$(CPCTEST_DIR)/test_cpc_foreground.c $(SPRITE_MASK2_ASM) $(CPC_LIB_SRCS) \
		-o $(CPC_FG_NAME) -m
	echo "Created $(CPC_FG_NAME).dsk"

# Build and screenshot the CPC foreground test headless in cap32
run-cpc-foreground: cpc-foreground
	./tools/cap32-shot.sh $(CPC_FG_NAME).dsk $(CPC_FG_NAME)

# Build the CPC Mode 2 background-tile draw/delete/redraw test
cpc-btt-redraw:
	echo Building CPC Mode 2 BTT redraw test...
	zcc +cpc -compiler=sdcc $(CPC_CFLAGS) -create-app -subtype=dsk \
		$(CPCTEST_DIR)/test_cpc_btt_redraw.c $(CPC_LIB_SRCS) -o $(CPC_TILE_NAME) -m
	echo "Created $(CPC_TILE_NAME).dsk"

# Build and screenshot the CPC BTT redraw test headless in cap32
run-cpc-btt-redraw: cpc-btt-redraw
	./tools/cap32-shot.sh $(CPC_TILE_NAME).dsk $(CPC_TILE_NAME)

## extras — sprite assets (generated from assets/*.png via the in-repo,
## vendored tools/gfxgen.pl + tools/lib/ZXGfx.pm — JSP is self-contained, no
## external ../zxtools dependency).  These are the ZX 1bpp mask2 (mask,graph
## pairs) / load1 (graph only) byte format, columns-major, 8 lines/cell, with 7
## transparent pre-rows + 7 trailing blank lines per column (overlapping) for
## safe sub-cell Y.  CPC Mode 2 is 1bpp-linear (8 px/byte) — IDENTICAL format —
## so the CPC Mode-2 build reuses these very files unchanged (the cpc-sprite*
## targets link test_sprite_mask2.asm directly); cpc-shift-test-mode2 validates
## the Mode-2 shift masks against these emitted bytes.  Per-mode emitter
## variants for Mode 0/1 (re-quantised planar encodings of the same source art)
## arrive with those phases (plan §10).

$(TESTS_DIR)/test_sprite_mask2.asm:
	tools/gfxgen.pl -i assets/ball.png -x 0 -y 0 --width 16 --height 16 \
		-m FF0000 -f FFFFFF -b 000000 \
		--code-type asm -s _test_sprite_mask2_pixels \
		-g sprite_mask -l columns --extra-bottom-row --extra-top-rows > $@

$(TESTS_DIR)/test_sprite_load1.asm:
	tools/gfxgen.pl -i assets/ball.png -x 0 -y 0 --width 16 --height 16 \
		-m FF0000 -f FFFFFF -b 000000 \
		--code-type asm -s _test_sprite_load1_pixels \
		-g sprite_load -l columns --extra-bottom-row --extra-top-rows > $@

## CPC Mode-1 sprite assets (two-nibble-plane planar, in-repo tools/cpcgfx.pl,
## plan §10).  Same source art as the ZX/Mode-2 assets, re-encoded to Mode 1:
## each 8-px ZX column becomes two 4-px Mode-1 columns, so a 16x16 ball is 4
## Mode-1 cols wide (the test descriptors use cols=4).  Symbol names carry a
## _m1 suffix so a build can link Mode-1 and Mode-2 assets side by side.
## (SPRITE_*_M1_ASM are defined near SPRITE_*_ASM above.)

$(TESTS_DIR)/test_sprite_mask2_m1.asm:
	tools/cpcgfx.pl -i assets/ball.png -x 0 -y 0 --width 16 --height 16 \
		-m FF0000 -f FFFFFF -b 000000 --mode 1 \
		-s _test_sprite_mask2_m1_pixels \
		-g sprite_mask --extra-bottom-row --extra-top-rows > $@

$(TESTS_DIR)/test_sprite_load1_m1.asm:
	tools/cpcgfx.pl -i assets/ball.png -x 0 -y 0 --width 16 --height 16 \
		-m FF0000 -f FFFFFF -b 000000 --mode 1 \
		-s _test_sprite_load1_m1_pixels \
		-g sprite_load --extra-bottom-row --extra-top-rows > $@

## CPC Mode-0 sprite assets (odd/even interleave, 2 px/byte, plan §10).  Same
## source art; each 8-px ZX column becomes 4 Mode-0 columns, so a 16x16 ball is
## 8 Mode-0 cols wide (the Mode-0 test descriptors use cols=8).
$(TESTS_DIR)/test_sprite_mask2_m0.asm:
	tools/cpcgfx.pl -i assets/ball.png -x 0 -y 0 --width 16 --height 16 \
		-m FF0000 -f FFFFFF -b 000000 --mode 0 \
		-s _test_sprite_mask2_m0_pixels \
		-g sprite_mask --extra-bottom-row --extra-top-rows > $@

$(TESTS_DIR)/test_sprite_load1_m0.asm:
	tools/cpcgfx.pl -i assets/ball.png -x 0 -y 0 --width 16 --height 16 \
		-m FF0000 -f FFFFFF -b 000000 --mode 0 \
		-s _test_sprite_load1_m0_pixels \
		-g sprite_load --extra-bottom-row --extra-top-rows > $@
