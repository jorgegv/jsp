# JSP top-level Makefile.
#
# Deliberately small, curated target set (see `make` / `make help`):
#   help                     this list
#   default                  incremental ZX build (build/main)
#   build / build-zx         clean ZX rebuild -> build/main.tap  (build is an alias)
#   clean                    remove build/ + per-source intermediates
#   zx-run / zx-run-jnext    launch build/main.tap in FUSE / JNEXT
#   zx-profile               headless T-state heatmap of build/main.tap
#   zx-tests                 build every ZX test + run the ZX regressions
#   zx-run-test  TEST=…      build + launch one ZX test in FUSE
#   zx-bench[-mask2]         JSP redraw benchmarks (headless JNEXT)
#   zx-bench-sp1[-mask2]     SP1 comparison benchmarks
#   cpc-tests                build every CPC test + run the CPC regressions
#   cpc-run-test TEST=… [MODE=…]   build + screenshot ONE CPC test
#
# The whole CPC mode matrix is collapsed into cpc-run-test (parametrised by
# TEST + MODE) and cpc-tests; per-mode lookup tables drive it (see "CPC matrix"
# below).  Three further CPC maintenance/measurement targets (cpc-artifact-check,
# cpc-perf-matrix, cpc-cell-model-archive) round out the set.  All artifacts land
# in build/ (see `clean`).

ZCC		= zcc +zx -compiler=sdcc
CFLAGS		= -vn -SO3 --opt-code-size --max-allocs-per-node200000 --list -s --c-code-in-asm -I$(INCLUDE_DIR)
LDFLAGS		= -lndos -m

BIN		= main
FUSE		= fuse

# All final build artifacts (ZX main.tap, CPC .dsk + named binaries, test taps,
# host unit-test binaries, emulator screenshots) are emitted into $(BUILD_DIR).
# Per-source z88dk intermediates (.o/.lis/.lst/.sym/.map) stay beside sources.
BUILD_DIR	= build
# Order-only stamp ensuring $(BUILD_DIR) exists (a target literally named `build`
# would collide with the phony `build` target, so we depend on a file inside it).
BUILD_STAMP	= $(BUILD_DIR)/.stamp
TAP		= $(BUILD_DIR)/$(BIN).tap

# Headless cap32 screenshots land in $(BUILD_DIR) too (cap32-shot.sh honours
# CAP32_SHOT_OUT; exported so every cpc screenshot recipe inherits it).
export CAP32_SHOT_OUT = $(CURDIR)/$(BUILD_DIR)/shot.png

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
# layer in lib/$(JSP_TARGET)/.  Defaults to the ZX target.
JSP_TARGET	?= zx
PLATDIR		= lib/$(JSP_TARGET)

C_SRCS		= $(wildcard lib/*.c) $(wildcard $(PLATDIR)/*.c) $(wildcard *.c)
ASM_SRCS	= $(wildcard lib/*.asm) $(wildcard $(PLATDIR)/*.asm) $(wildcard *.asm)
C_OBJS		= $(C_SRCS:.c=.o)
ASM_OBJS	= $(ASM_SRCS:.asm=.o)

# sprite pixel data referenced by the main.c test harness; these .asm files live
# under tests/ (generated from PNGs), not picked up by the wildcards above.
BIN_ASSET_ASMS	= tests/test_sprite_mask2.asm tests/test_sprite_load1.asm
BIN_ASSET_OBJS	= $(BIN_ASSET_ASMS:.asm=.o)

.SILENT:
MAKEFLAGS 	+= --no-print-directory -j4

.PHONY: help default build build-zx clean zx-run zx-run-jnext zx-profile \
	zx-tests zx-run-test zx-bench zx-bench-mask2 zx-bench-sp1 zx-bench-sp1-mask2 \
	cpc-tests cpc-run-test cpc-artifact-check cpc-perf-matrix cpc-cell-model-archive

## Self-documenting help — `make` with no target lists every target that has a
## `#` comment on the line immediately above it (names print in bold red).
.DEFAULT_GOAL := help

# Show this help
help:
	@if [ -t 1 ] && [ -z "$$NO_COLOR" ]; then c='\033[1;31m'; r='\033[0m'; else c=; r=; fi; \
	awk -v c="$$c" -v r="$$r" 'BEGIN { FS = ":"; n = 0; w = 0 } \
		/^# / { desc = substr($$0, 3); next } \
		/^[a-zA-Z0-9][a-zA-Z0-9_.-]*:($$|[^=])/ { \
			if (desc != "") { name[n] = $$1; text[n] = desc; \
				if (length($$1) > w) w = length($$1); n++; desc = "" } \
			next \
		} \
		{ desc = "" } \
		END { for (i = 0; i < n; i++) \
			printf "  %s%-*s%s  %s\n", c, w, name[i], r, text[i] }' $(MAKEFILE_LIST)

## generic rules

# Create the build output directory (order-only prerequisite for artifact targets).
$(BUILD_STAMP):
	mkdir -p $(BUILD_DIR)
	touch $@

%.o: %.c
	echo Compiling $*.c...
	$(ZCC) $(CFLAGS) -c $*.c

%.o: %.asm
	echo Assembling $*.asm...
	$(ZCC) $(CFLAGS) -c $*.asm

## ============================================================================
## ZX build
## ============================================================================

# Incremental ZX build (build/main)
default: $(BUILD_DIR)/$(BIN)

# Clean ZX rebuild — produces build/main.tap
build-zx:
	$(MAKE) clean
	$(MAKE) $(TAP)
	echo Build successful

# Alias for build-zx
build: build-zx

# Remove all build artifacts (build/) plus per-source z88dk intermediates
clean:
	echo Cleaning up...
	# All final artifacts live in $(BUILD_DIR) — one recursive rm does it.
	-rm -rf $(BUILD_DIR) 2>/dev/null
	# Per-source z88dk intermediates are kept beside their sources; clean them too.
	-rm -f *.{map,lst,o,lis,sym,bin,c.asm} 2>/dev/null
	-rm -f lib/*.{map,lst,o,lis,sym,bin} 2>/dev/null
	-rm -f lib/zx/*.{map,lst,o,lis,sym,bin} lib/cpc/*.{map,lst,o,lis,sym,bin} 2>/dev/null
	-rm -f $(TESTS_DIR)/*.{map,lst,o,lis,sym,bin} 2>/dev/null
	-rm -f $(ZXTEST_DIR)/*.{map,lst,o,lis,sym,bin} $(CPCTEST_DIR)/*.{map,lst,o,lis,sym,bin} 2>/dev/null

$(BUILD_DIR)/$(BIN): $(ASM_OBJS) $(C_OBJS) $(BIN_ASSET_OBJS) | $(BUILD_STAMP)
	echo Linking $@...
	$(ZCC) $(LDFLAGS) $(ASM_OBJS) $(C_OBJS) $(BIN_ASSET_OBJS) -o $(BUILD_DIR)/$(BIN) -create-app
	echo Created $(TAP)

$(TAP): $(BUILD_DIR)/$(BIN)

# Launch build/main.tap in the FUSE emulator
zx-run: $(TAP)
	$(FUSE) $(TAP)

# Launch build/main.tap in the JNEXT emulator (GUI)
zx-run-jnext: $(TAP)
	$(JNEXT) --sd-card $(JNEXT_SD) --machine $(JNEXT_MACHINE) --load $(TAP)

# Profile build/main.tap headless and print the hottest functions (T-state heatmap)
zx-profile: $(TAP)
	echo Profiling $(TAP) for $(PROFILE_EXIT)s...
	$(JNEXT) --headless --machine $(JNEXT_MACHINE) --sd-card $(JNEXT_SD) \
		--load $(TAP) --profile --profile-output $(PROFILE_DAT) \
		--delayed-automatic-exit $(PROFILE_EXIT) >/dev/null 2>&1
	echo "Top $(PROFILE_TOP) functions by T-states:"
	$(JNEXT_HEATMAP) -m $(BUILD_DIR)/$(BIN).map < $(PROFILE_DAT) 2>/dev/null | head -$(PROFILE_TOP)

## ============================================================================
## ZX tests + benchmarks
## ============================================================================

TESTS_DIR	= tests
ZXTEST_DIR	= tests/zx
CPCTEST_DIR	= tests/cpc
LIB_SRCS	= $(wildcard lib/*.c) $(wildcard lib/*.asm) \
		  $(wildcard $(PLATDIR)/*.c) $(wildcard $(PLATDIR)/*.asm)

SPRITE_MASK2_ASM    = $(TESTS_DIR)/test_sprite_mask2.asm
SPRITE_LOAD1_ASM    = $(TESTS_DIR)/test_sprite_load1.asm
SPRITE_MASK2_M1_ASM = $(TESTS_DIR)/test_sprite_mask2_m1.asm
SPRITE_LOAD1_M1_ASM = $(TESTS_DIR)/test_sprite_load1_m1.asm
SPRITE_MASK2_M0_ASM = $(TESTS_DIR)/test_sprite_mask2_m0.asm
SPRITE_LOAD1_M0_ASM = $(TESTS_DIR)/test_sprite_load1_m0.asm
# Implicit-mask balls (graph-only, pen 0 transparent; CPC _IMASK modes).
SPRITE_IMASK_M1_ASM = $(TESTS_DIR)/test_sprite_imask_m1.asm
SPRITE_IMASK_M0_ASM = $(TESTS_DIR)/test_sprite_imask_m0.asm
# Multicolour balls (4 pens Mode 1 / many pens Mode 0): pixels + emitted palette.
BALL_M1_ASM         = $(TESTS_DIR)/test_ball_m1.asm
BALL_M0_ASM         = $(TESTS_DIR)/test_ball_m0.asm

TESTS		= test_dtt test_btt_contents test_btt_redraw test_sprite_draw \
		  test_sprite_move test_pool_and_colour test_tiles_and_print \
		  test_foreground_tiles test_redraw_bench
TEST_TAPS	= $(TESTS:%=$(BUILD_DIR)/%.tap)

## ZX regression set: every test that has a committed reference screenshot in
## tests/refs/zx/.  test_artifact (the bottom-line over-render guard) is built
## by its own prereq rule below and is not part of the FUSE-runnable TESTS list.
ZXTEST_REFS	= tests/refs/zx
ZX_REGRESSION	= $(TESTS) test_artifact
ZX_REGRESSION_TAPS = $(ZX_REGRESSION:%=$(BUILD_DIR)/%.tap)
# deterministic capture frame (matches how the refs were generated)
ZX_SHOT_FRAMES	?= 300

## NOTE: --delayed-screenshot-frames is EMULATED frames; --delayed-automatic-exit is
## wall-clock SECONDS and must outlast the capture frame, else no PNG is written.
# Build every ZX test + run each headless in JNEXT, diff vs reference screenshots (AE; 0 = pass)
zx-tests: $(ZX_REGRESSION_TAPS)
	@echo "== ZX regression — frame $(ZX_SHOT_FRAMES) screenshot, AE vs $(ZXTEST_REFS) (0 = pass) =="
	@fail=0; for t in $(ZX_REGRESSION); do \
		$(JNEXT) --headless --machine $(JNEXT_MACHINE) --sd-card $(JNEXT_SD) \
			--load $(BUILD_DIR)/$$t.tap \
			--delayed-screenshot $(BUILD_DIR)/$$t.png \
			--delayed-screenshot-frames $(ZX_SHOT_FRAMES) \
			--delayed-automatic-exit 10 >/dev/null 2>&1; \
		ref="$(ZXTEST_REFS)/$$t.png"; \
		if [ -f $(BUILD_DIR)/$$t.png ] && [ -f "$$ref" ]; then \
			ae=$$(magick compare -metric AE "$$ref" $(BUILD_DIR)/$$t.png null: 2>&1); \
			printf "  %-22s AE=%s\n" "$$t" "$$ae"; \
			[ "$${ae%% *}" = "0" ] || fail=1; \
		else printf "  %-22s MISSING (shot or ref)\n" "$$t"; fail=1; fi; \
	done; \
	if [ $$fail -eq 0 ]; then echo "ZX regression: all pass"; \
	else echo "ZX regression: FAILURES"; exit 1; fi

## Pattern rule: compile test + all lib sources in one zcc invocation
$(BUILD_DIR)/%.tap: $(ZXTEST_DIR)/%.c $(LIB_SRCS) | $(BUILD_STAMP)
	echo Building $@...
	$(ZCC) $(CFLAGS) $(LDFLAGS) $^ -o $(@:.tap=.bin) -create-app

## Extra sprite-data prerequisites for tests that use sprites
$(BUILD_DIR)/test_sprite_draw.tap: $(SPRITE_MASK2_ASM)
$(BUILD_DIR)/test_sprite_move.tap: $(SPRITE_MASK2_ASM) $(SPRITE_LOAD1_ASM)
$(BUILD_DIR)/test_pool_and_colour.tap: $(SPRITE_MASK2_ASM)
$(BUILD_DIR)/test_foreground_tiles.tap: $(SPRITE_MASK2_ASM)
$(BUILD_DIR)/test_redraw_bench.tap: $(SPRITE_MASK2_ASM) $(SPRITE_LOAD1_ASM)
$(BUILD_DIR)/test_artifact.tap: $(SPRITE_LOAD1_ASM)		# bottom-line artifact regression

# Build + launch one ZX test in FUSE (usage: make zx-run-test TEST=test_dtt)
zx-run-test: $(BUILD_DIR)/$(TEST).tap
	fuse $(BUILD_DIR)/$(TEST).tap

# Build + run the JSP redraw benchmark headless in JNEXT
zx-bench: $(BUILD_DIR)/test_redraw_bench.tap
	$(JNEXT) --headless --machine $(JNEXT_MACHINE) --sd-card $(JNEXT_SD) \
		--load $< --magic-port 0x00FF --magic-port-mode ascii \
		--delayed-automatic-exit 300 2>&1 | grep -E '^(A0?=|B=|END)'

# Run the JSP redraw benchmark with an all-MASK2 sprite workload
zx-bench-mask2: $(SPRITE_MASK2_ASM) | $(BUILD_STAMP)
	echo Building all-MASK2 JSP benchmark...
	$(ZCC) $(CFLAGS) $(LDFLAGS) -DBENCH_ALL_MASK2 \
		$(ZXTEST_DIR)/test_redraw_bench.c $(LIB_SRCS) $(SPRITE_MASK2_ASM) \
		-o $(BUILD_DIR)/test_redraw_bench_mask2.bin -create-app
	$(JNEXT) --headless --machine $(JNEXT_MACHINE) --sd-card $(JNEXT_SD) \
		--load $(BUILD_DIR)/test_redraw_bench_mask2.tap \
		--magic-port 0x00FF --magic-port-mode ascii \
		--delayed-automatic-exit 300 2>&1 | grep -E '^(A0?=|B=|END)'

## SP1 benchmark — standalone SP1 program, built with the z88dk new C library
## (-clib=sdcc_iy): sdcc then uses IY as its frame pointer, so SP1's asm (which
## trashes IX) does not corrupt C frames.  No JSP sources.
$(BUILD_DIR)/bench_sp1.tap: $(ZXTEST_DIR)/bench_sp1.c | $(BUILD_STAMP)
	echo Building $@...
	$(ZCC) -vn -SO3 --max-allocs-per-node200000 -startup=31 -clib=sdcc_iy -m \
		$< -o $(@:.tap=.bin) -create-app

# Build + run the SP1 redraw benchmark headless (JSP-vs-SP1 comparison)
zx-bench-sp1: $(BUILD_DIR)/bench_sp1.tap
	$(JNEXT) --headless --machine $(JNEXT_MACHINE) --sd-card $(JNEXT_SD) \
		--load $< --magic-port 0x00FF --magic-port-mode ascii \
		--delayed-automatic-exit 600 2>&1 | grep -E '^(A0?=|B=|END)'

# Run the SP1 redraw benchmark with an all-MASK2 sprite workload
zx-bench-sp1-mask2: | $(BUILD_STAMP)
	echo Building all-MASK2 SP1 benchmark...
	$(ZCC) -vn -SO3 --max-allocs-per-node200000 -startup=31 -clib=sdcc_iy -m \
		-DBENCH_ALL_MASK2 $(ZXTEST_DIR)/bench_sp1.c \
		-o $(BUILD_DIR)/bench_sp1_mask2.bin -create-app
	$(JNEXT) --headless --machine $(JNEXT_MACHINE) --sd-card $(JNEXT_SD) \
		--load $(BUILD_DIR)/bench_sp1_mask2.tap \
		--magic-port 0x00FF --magic-port-mode ascii \
		--delayed-automatic-exit 600 2>&1 | grep -E '^(A0?=|B=|END)'

## ============================================================================
## CPC compile configuration
## ============================================================================

# REGISTER_SP=0x9800 places the stack just below the JSP data block (BAT base):
# the firmware default SP sits high and would overlap the rottbl, corrupting it.
CPC_MODE	?= 2
CPC_CFLAGS	= -DJSP_TARGET_CPC -Ca-DJSP_TARGET_CPC \
		  -DCPC_MODE$(CPC_MODE) -Ca-DCPC_MODE$(CPC_MODE) \
		  -pragma-define:REGISTER_SP=0x9800 \
		  -SO2 --max-allocs-per-node200000 -I$(INCLUDE_DIR) \
		  $(CPC_EXTRA_CFLAGS)
# Appended to CPC_CFLAGS for ad-hoc/perf builds (e.g. CPC_EXTRA_CFLAGS=-DTIME_LIMITED=1000).
CPC_EXTRA_CFLAGS ?=

# Cell model (CPC): "pixel" (DEFAULT) or "byte"; see doc/CPC-TILE-SIZE-DESIGN.md.
JSP_CELL_MODEL ?= pixel
ifeq ($(JSP_CELL_MODEL),pixel)
CPC_CFLAGS += -DJSP_CELL_MODEL_PIXEL -Ca-DJSP_CELL_MODEL_PIXEL
else ifeq ($(JSP_CELL_MODEL),byte)
CPC_CFLAGS += -DJSP_CELL_MODEL_BYTE -Ca-DJSP_CELL_MODEL_BYTE
else
$(error JSP_CELL_MODEL must be 'pixel' or 'byte' (got '$(JSP_CELL_MODEL)'))
endif
CPC_LIB_SRCS	= $(wildcard lib/*.c) $(wildcard lib/*.asm) $(wildcard lib/cpc/*.asm)
HOSTCC		?= cc

# NB: keep these comments on their own line — a `#` after a tab would be
# captured into the value (make only strips a single trailing space).
# cpc-perf-matrix cycles/config
CYCLES		?= 1000
# LOAD-sprite artifact regression test source
ARTIFACT_SRC	= test_cpc_artifact.c

# Single-mode CPC test disk names
CPC_BG_NAME	= CPCBG
CPC_FG_NAME	= CPCFG
CPC_TILE_NAME	= CPCTILE
CPC_SPRD_NAME	= CPCSPRD

## --- CPC matrix: per-mode lookup tables --------------------------------------
## cpc-run-test / cpc-tests turn a mode token into the things a CPC build needs
## (the -DCPC_MODE guard, the test .c, the sprite asset, the disk name).
## Mode tokens (also accepted as MODE=…): sprite uses all seven; artifact and
## shift-test use a subset.
MODE			?= 2
CPC_SPRITE_MODES	= 2 1 1_mono 0 2_fast 0_fast 1_fast 1_imask 0_imask
CPC_ARTIFACT_MODES	= 2 1 0 1_mono
CPC_SHIFT_MODES		= 2 1 1_mono 0
CPC_IMASK_MODES		= 1_imask 0_imask

m_def_2 = 2
m_def_1 = 1
m_def_1_mono = 1_MONO
m_def_0 = 0
m_def_2_fast = 2_FAST
m_def_0_fast = 0_FAST
m_def_1_fast = 1_FAST
m_def_1_imask = 1_IMASK
m_def_0_imask = 0_IMASK

m_src_2 = test_cpc_sprite.c
m_src_1 = test_cpc_sprite_mode1.c
m_src_1_mono = test_cpc_sprite_mode1_mono.c
m_src_0 = test_cpc_sprite_mode0.c
m_src_2_fast = test_cpc_sprite.c
m_src_0_fast = test_cpc_sprite_mode0.c
m_src_1_fast = test_cpc_sprite_mode1.c
m_src_1_imask = test_cpc_sprite_imask.c
m_src_0_imask = test_cpc_sprite_imask.c

m_mask_2 = $(SPRITE_MASK2_ASM)
m_mask_1 = $(SPRITE_MASK2_M1_ASM) $(BALL_M1_ASM)
m_mask_1_mono = $(SPRITE_MASK2_ASM)
m_mask_0 = $(SPRITE_MASK2_M0_ASM) $(BALL_M0_ASM)
m_mask_2_fast = $(SPRITE_MASK2_ASM)
m_mask_0_fast = $(SPRITE_MASK2_M0_ASM) $(BALL_M0_ASM)
m_mask_1_fast = $(SPRITE_MASK2_M1_ASM) $(BALL_M1_ASM)
m_mask_1_imask = $(SPRITE_IMASK_M1_ASM)
m_mask_0_imask = $(SPRITE_IMASK_M0_ASM)

m_load_2 = $(SPRITE_LOAD1_ASM)
m_load_1 = $(SPRITE_LOAD1_M1_ASM)
m_load_1_mono = $(SPRITE_LOAD1_ASM)
m_load_0 = $(SPRITE_LOAD1_M0_ASM)

m_name_2 = CPCSPR2
m_name_1 = CPCSPR1
m_name_1_mono = CPCSPR1M
m_name_0 = CPCSPR0
m_name_2_fast = CPCSPR2F
m_name_0_fast = CPCSPR0F
m_name_1_fast = CPCSPR1F
m_name_1_imask = CPCSPR1I
m_name_0_imask = CPCSPR0I

m_artname_2 = CPCART
m_artname_1 = CPCART1
m_artname_0 = CPCART0
m_artname_1_mono = CPCARTM

m_shiftdef_2 =
m_shiftdef_1 = -DCPC_MODE1
m_shiftdef_1_mono = -DCPC_MODE1_MONO
m_shiftdef_0 = -DCPC_MODE0

# every sprite asset (cpc-run-test depends on these so the needed .asm exists)
ALL_CPC_ASSETS = $(SPRITE_MASK2_ASM) $(SPRITE_LOAD1_ASM) \
		 $(SPRITE_MASK2_M1_ASM) $(SPRITE_LOAD1_M1_ASM) \
		 $(SPRITE_MASK2_M0_ASM) $(SPRITE_LOAD1_M0_ASM) \
		 $(SPRITE_IMASK_M1_ASM) $(SPRITE_IMASK_M0_ASM)

## ============================================================================
## CPC tests
## ============================================================================

TEST	?= sprite
SHOT	?= 1
# Build + screenshot ONE CPC test: TEST=sprite|artifact|shift|bg|foreground|btt-redraw|demo, MODE=<token> (sprite/artifact/shift), SHOT=0 to skip screenshot
cpc-run-test: CPC_MODE := $(m_def_$(MODE))
cpc-run-test: $(ALL_CPC_ASSETS) | $(BUILD_STAMP)
	@set -e; \
	case "$(TEST)" in \
	shift) \
		echo "CPC shift/mask unit test [MODE=$(MODE)]..."; \
		$(HOSTCC) -O2 -Wall $(m_shiftdef_$(MODE)) -I$(INCLUDE_DIR) \
			-o $(BUILD_DIR)/shift_test_mode$(MODE) $(CPCTEST_DIR)/shift_test_mode$(MODE).c; \
		$(BUILD_DIR)/shift_test_mode$(MODE) $(m_mask_$(MODE)); \
		exit 0 ;; \
	imask) \
		echo "CPC _IMASK LUT unit test [MODE=$(MODE)]..."; \
		$(HOSTCC) -O2 -Wall -DCPC_MODE$(m_def_$(MODE)) -I$(INCLUDE_DIR) \
			-o $(BUILD_DIR)/imask_test_$(MODE) $(CPCTEST_DIR)/imask_test.c; \
		$(BUILD_DIR)/imask_test_$(MODE); \
		exit 0 ;; \
	sprite)     src=$(m_src_$(MODE));      asset="$(m_mask_$(MODE))"; name="$(m_name_$(MODE))" ;; \
	artifact)   src=$(ARTIFACT_SRC);       asset="$(m_load_$(MODE))"; name="$(m_artname_$(MODE))" ;; \
	bg)         src=test_cpc_bg.c;         asset="";                  name="$(CPC_BG_NAME)" ;; \
	foreground) src=test_cpc_foreground.c; asset="$(SPRITE_MASK2_ASM)"; name="$(CPC_FG_NAME)" ;; \
	btt-redraw) src=test_cpc_btt_redraw.c; asset="";                  name="$(CPC_TILE_NAME)" ;; \
	demo)       src=test_cpc_sprite_demo.c; asset="$(SPRITE_MASK2_ASM)"; name="$(CPC_SPRD_NAME)" ;; \
	*) echo "unknown TEST='$(TEST)' — pick: sprite artifact shift bg foreground btt-redraw demo"; exit 1 ;; \
	esac; \
	[ -n "$$name" ] || { echo "no config for TEST=$(TEST) MODE=$(MODE)"; exit 1; }; \
	[ -n "$(CPC_MODE)" ] || { echo "invalid MODE='$(MODE)' (no CPC_MODE guard); pick: $(CPC_SPRITE_MODES)"; exit 1; }; \
	echo "Building CPC $(TEST) [MODE=$(MODE)] -> $$name.dsk"; \
	zcc +cpc -compiler=sdcc $(CPC_CFLAGS) -create-app -subtype=dsk \
		$(CPCTEST_DIR)/$$src $$asset $(CPC_LIB_SRCS) -o $(BUILD_DIR)/$$name -m; \
	if [ "$(TEST)" = demo ]; then \
		echo "Built $(BUILD_DIR)/$$name.dsk  (demo animates; run: cap32 -a 'run\"$$name.' $(BUILD_DIR)/$$name.dsk)"; \
	elif [ "$(SHOT)" = 1 ]; then \
		./tools/cap32-shot.sh $(BUILD_DIR)/$$name.dsk $$name; \
	else echo "Built $(BUILD_DIR)/$$name.dsk"; fi

# Run all CPC tests: build every config (smoke) + shift unit tests + artifact regression
cpc-tests:
	@echo "== CPC: build every sprite config + utility tests =="
	@for m in $(CPC_SPRITE_MODES); do $(MAKE) cpc-run-test TEST=sprite MODE=$$m SHOT=0 || exit 1; done
	@for t in bg foreground btt-redraw; do $(MAKE) cpc-run-test TEST=$$t SHOT=0 || exit 1; done
	@echo "== CPC: shift/mask host unit tests =="
	@for m in $(CPC_SHIFT_MODES); do $(MAKE) cpc-run-test TEST=shift MODE=$$m || exit 1; done
	@echo "== CPC: _IMASK LUT host unit tests =="
	@for m in $(CPC_IMASK_MODES); do $(MAKE) cpc-run-test TEST=imask MODE=$$m || exit 1; done
	@echo "== CPC: bottom-line artifact regression =="
	@$(MAKE) cpc-artifact-check
	@echo "CPC tests complete."

## --- CPC maintenance / measurement targets -----------------------------------

CPC_ARTIFACT_PAIRS = $(foreach m,$(CPC_ARTIFACT_MODES),$(m):$(m_artname_$(m)))
# Build the 4 artifact disks, screenshot, compare to committed refs (AE; 0 = pass, any diff fails)
cpc-artifact-check:
	@echo "CPC bottom-line artifact regression (AE vs tests/refs/cpc/artifact; 0 = pass)"
	@fail=0; for pair in $(CPC_ARTIFACT_PAIRS); do m=$${pair%%:*}; n=$${pair##*:}; \
		$(MAKE) cpc-run-test TEST=artifact MODE=$$m SHOT=0 JSP_CELL_MODEL=$(JSP_CELL_MODEL) >/dev/null 2>&1 \
			|| { echo "  $$n BUILD-FAIL"; fail=1; continue; }; \
		CAP32_SHOT_OPTS='-O system.limit_speed=0' CAP32_SHOT_WAIT=6 \
			./tools/cap32-shot.sh $(BUILD_DIR)/$$n.dsk $$n >/dev/null 2>&1; \
		ref="tests/refs/cpc/artifact/$$n.png"; \
		if [ -f $(BUILD_DIR)/shot.png ] && [ -f "$$ref" ]; then \
			ae=$$(magick compare -metric AE "$$ref" $(BUILD_DIR)/shot.png null: 2>&1); \
			printf "  %-10s AE=%s\n" "$$n" "$$ae"; \
			[ "$${ae%% *}" = "0" ] || fail=1; \
		else echo "  $$n MISSING (shot or ref)"; fail=1; fi; \
	done; \
	if [ $$fail -eq 0 ]; then echo "CPC artifact regression: all pass"; \
	else echo "CPC artifact regression: FAILURES"; exit 1; fi

CPC_SPRITE_PAIRS = $(foreach m,$(CPC_SPRITE_MODES),$(m):$(m_name_$(m)))
# Wall-clock redraw timing of every sprite config (override cycles with CYCLES=)
cpc-perf-matrix:
	@echo "CPC redraw timing — $(CYCLES) cycles/config (wall-clock s, lower is faster)"
	@for pair in $(CPC_SPRITE_PAIRS); do m=$${pair%%:*}; n=$${pair##*:}; \
		$(MAKE) cpc-run-test TEST=sprite MODE=$$m SHOT=0 CPC_EXTRA_CFLAGS="-DTIME_LIMITED=$(CYCLES)" >/dev/null \
			|| { echo "BUILD FAILED MODE=$$m"; exit 1; }; \
		printf "%-24s " "$$n"; \
		./tools/cap32-time.sh $(BUILD_DIR)/$$n.dsk $$n 2>/dev/null || echo "RUN FAILED"; \
	done

# Build every CPC test in BOTH cell models, archiving .dsk into cpc-cell-model/{byte,pixel}/
cpc-cell-model-archive:
	for cm in byte pixel; do \
		mkdir -p cpc-cell-model/$$cm; \
		rm -f $(BUILD_DIR)/*.dsk; \
		for m in $(CPC_SPRITE_MODES); do \
			$(MAKE) cpc-run-test TEST=sprite MODE=$$m SHOT=0 JSP_CELL_MODEL=$$cm >/dev/null \
				|| { echo "FAILED: sprite MODE=$$m ($$cm)"; exit 1; }; \
		done; \
		for t in bg foreground btt-redraw; do \
			$(MAKE) cpc-run-test TEST=$$t SHOT=0 JSP_CELL_MODEL=$$cm >/dev/null \
				|| { echo "FAILED: $$t ($$cm)"; exit 1; }; \
		done; \
		cp -f $(BUILD_DIR)/*.dsk cpc-cell-model/$$cm/; \
		echo "cpc-cell-model/$$cm: $$(ls cpc-cell-model/$$cm/*.dsk | wc -l) .dsk built"; \
	done

## ============================================================================
## Sprite assets (generated from assets/*.png via the unified vendored
## tools/gfxgen.pl: --platform zx for the ZX 1bpp mask2/load1 byte format,
## --platform cpc for the CPC paths).  CPC Mode 2 reuses the ZX files unchanged;
## Mode 0/1 are re-quantised planar encodings of the same art.
## ============================================================================

$(TESTS_DIR)/test_sprite_mask2.asm:
	tools/gfxgen.pl --platform zx -i assets/ball.png -x 0 -y 0 --width 16 --height 16 \
		-m FF0000 -f FFFFFF -b 000000 \
		--code-type asm -s _test_sprite_mask2_pixels \
		-g sprite_mask -l columns --extra-bottom-row --extra-top-rows > $@

$(TESTS_DIR)/test_sprite_load1.asm:
	tools/gfxgen.pl --platform zx -i assets/ball.png -x 0 -y 0 --width 16 --height 16 \
		-m FF0000 -f FFFFFF -b 000000 \
		--code-type asm -s _test_sprite_load1_pixels \
		-g sprite_load -l columns --extra-bottom-row --extra-top-rows > $@

$(TESTS_DIR)/test_sprite_mask2_m1.asm:
	tools/gfxgen.pl --platform cpc -i assets/ball.png -x 0 -y 0 --width 16 --height 16 \
		-m FF0000 -f FFFFFF -b 000000 --mode 1 \
		-s _test_sprite_mask2_m1_pixels \
		-g sprite_mask --extra-bottom-row --extra-top-rows > $@

$(TESTS_DIR)/test_sprite_load1_m1.asm:
	tools/gfxgen.pl --platform cpc -i assets/ball.png -x 0 -y 0 --width 16 --height 16 \
		-m FF0000 -f FFFFFF -b 000000 --mode 1 \
		-s _test_sprite_load1_m1_pixels \
		-g sprite_load --extra-bottom-row --extra-top-rows > $@

$(TESTS_DIR)/test_sprite_mask2_m0.asm:
	tools/gfxgen.pl --platform cpc -i assets/ball.png -x 0 -y 0 --width 16 --height 16 \
		-m FF0000 -f FFFFFF -b 000000 --mode 0 \
		-s _test_sprite_mask2_m0_pixels \
		-g sprite_mask --extra-bottom-row --extra-top-rows > $@

$(TESTS_DIR)/test_sprite_load1_m0.asm:
	tools/gfxgen.pl --platform cpc -i assets/ball.png -x 0 -y 0 --width 16 --height 16 \
		-m FF0000 -f FFFFFF -b 000000 --mode 0 \
		-s _test_sprite_load1_m0_pixels \
		-g sprite_load --extra-bottom-row --extra-top-rows > $@

## Implicit-mask balls (graph-only, pen 0 transparent): same art as mask2, half
## the size.  CPC _IMASK modes (sprite_imask gfx-type).
$(TESTS_DIR)/test_sprite_imask_m1.asm:
	tools/gfxgen.pl --platform cpc -i assets/ball.png -x 0 -y 0 --width 16 --height 16 \
		-m FF0000 -f FFFFFF -b 000000 --mode 1 \
		-s _test_sprite_imask_m1_pixels \
		-g sprite_imask --extra-bottom-row --extra-top-rows > $@

$(TESTS_DIR)/test_sprite_imask_m0.asm:
	tools/gfxgen.pl --platform cpc -i assets/ball.png -x 0 -y 0 --width 16 --height 16 \
		-m FF0000 -f FFFFFF -b 000000 --mode 0 \
		-s _test_sprite_imask_m0_pixels \
		-g sprite_imask --extra-bottom-row --extra-top-rows > $@

## Multicolour balls — same ball shape, interior recoloured with several CPC
## colours (Mode 1 = 4 pens, Mode 0 = many).  --multicolor maps each PNG pixel to
## the nearest CPC ink; --palette-symbol also emits the Gate-Array palette the
## test harness programs (red FF0000 = transparent mask, black = pen 0).
$(TESTS_DIR)/test_ball_m1.asm:
	tools/gfxgen.pl --platform cpc -i assets/ball_m1.png -x 0 -y 0 --width 16 --height 16 \
		-m FF0000 -b 000000 --mode 1 --multicolor \
		-s _ball_m1_pixels --palette-symbol _ball_m1_palette \
		-g sprite_mask --extra-bottom-row --extra-top-rows > $@

$(TESTS_DIR)/test_ball_m0.asm:
	tools/gfxgen.pl --platform cpc -i assets/ball_m0.png -x 0 -y 0 --width 16 --height 16 \
		-m FF0000 -b 000000 --mode 0 --multicolor \
		-s _ball_m0_pixels --palette-symbol _ball_m0_palette \
		-g sprite_mask --extra-bottom-row --extra-top-rows > $@
