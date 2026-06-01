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

.PHONY: help default build clean run run-jnext profile tests run-test bench bench-mask2 bench-sp1 bench-sp1-mask2 clean-tests cpc-bg run-cpc-bg cpc-sprite run-cpc-sprite

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

# Build and launch main.tap in the FUSE emulator
run: $(TAP)
	$(FUSE) $(TAP)

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
		  -SO2 --max-allocs-per-node200000 -I$(INCLUDE_DIR)
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

## CPC (Phase 3) — masked, sub-byte-shifted Mode 2 sprites over a background.
## Same toolchain as cpc-bg; additionally links the (1bpp) mask2 sprite asset
## and exercises the lib/cpc kernels + covered-cell compositor.
CPC_SPR_NAME	= CPCSPR

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

## extras

$(TESTS_DIR)/test_sprite_mask2.asm:
	../zxtools/bin/gfxgen.pl -i assets/ball.png -x 0 -y 0 --width 16 --height 16 \
		-m FF0000 -f FFFFFF -b 000000 \
		--code-type asm -s _test_sprite_mask2_pixels \
		-g sprite_mask -l columns --extra-bottom-row --extra-top-rows > $@

$(TESTS_DIR)/test_sprite_load1.asm:
	../zxtools/bin/gfxgen.pl -i assets/ball.png -x 0 -y 0 --width 16 --height 16 \
		-m FF0000 -f FFFFFF -b 000000 \
		--code-type asm -s _test_sprite_load1_pixels \
		-g sprite_load -l columns --extra-bottom-row --extra-top-rows > $@
