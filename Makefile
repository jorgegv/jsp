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

C_SRCS		= $(wildcard lib/*.c) $(wildcard *.c)
ASM_SRCS	= $(wildcard lib/*.asm) $(wildcard *.asm)

C_OBJS		= $(C_SRCS:.c=.o)
ASM_OBJS	= $(ASM_SRCS:.asm=.o)

# sprite pixel data referenced by the main.c test harness; these .asm files
# live under tests/ (generated from PNGs) so they are not picked up by the
# wildcards above and must be linked into the main binary explicitly.
BIN_ASSET_ASMS	= tests/test_sprite_mask2.asm tests/test_sprite_load1.asm
BIN_ASSET_OBJS	= $(BIN_ASSET_ASMS:.asm=.o)

.SILENT:
MAKEFLAGS 	+= --no-print-directory -j4

.PHONY: help default build clean run run-jnext profile tests run-test bench bench-mask2 bench-sp1 bench-sp1-mask2 clean-tests

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

TESTS_DIR	= tests
LIB_SRCS	= $(wildcard lib/*.c) $(wildcard lib/*.asm)

SPRITE_MASK2_ASM = $(TESTS_DIR)/test_sprite_mask2.asm
SPRITE_LOAD1_ASM = $(TESTS_DIR)/test_sprite_load1.asm

TESTS		= test_dtt test_btt_contents test_btt_redraw test_sprite_draw \
		  test_sprite_move test_pool_and_colour test_tiles_and_print \
		  test_foreground_tiles test_redraw_bench
TEST_TAPS	= $(TESTS:%=$(TESTS_DIR)/%.tap)

# Build all test taps
tests: $(TEST_TAPS)

## Pattern rule: compile test + all lib sources in one zcc invocation
$(TESTS_DIR)/%.tap: $(TESTS_DIR)/%.c $(LIB_SRCS)
	echo Building $@...
	$(ZCC) $(CFLAGS) $(LDFLAGS) $^ -o $(@:.tap=.bin) -create-app

## Extra sprite data prerequisites for tests that use sprites
$(TESTS_DIR)/test_sprite_draw.tap: $(SPRITE_MASK2_ASM)
$(TESTS_DIR)/test_sprite_move.tap: $(SPRITE_MASK2_ASM) $(SPRITE_LOAD1_ASM)
$(TESTS_DIR)/test_pool_and_colour.tap: $(SPRITE_MASK2_ASM)
$(TESTS_DIR)/test_foreground_tiles.tap: $(SPRITE_MASK2_ASM)
$(TESTS_DIR)/test_redraw_bench.tap: $(SPRITE_MASK2_ASM) $(SPRITE_LOAD1_ASM)

# Build and launch one test in FUSE (usage: make run-test TEST=test_dtt)
run-test: $(TESTS_DIR)/$(TEST).tap
	fuse $(TESTS_DIR)/$(TEST).tap

# Build and run the redraw speed benchmark headless in JNEXT
bench: $(TESTS_DIR)/test_redraw_bench.tap
	$(JNEXT) --headless --machine $(JNEXT_MACHINE) --sd-card $(JNEXT_SD) \
		--load $< --magic-port 0x00FF --magic-port-mode ascii \
		--delayed-automatic-exit 300 2>&1 | grep -E '^(A0?=|B=|END)'

# Run the JSP redraw benchmark with an all-MASK2 sprite workload
bench-mask2: $(SPRITE_MASK2_ASM)
	echo Building all-MASK2 JSP benchmark...
	$(ZCC) $(CFLAGS) $(LDFLAGS) -DBENCH_ALL_MASK2 \
		$(TESTS_DIR)/test_redraw_bench.c $(LIB_SRCS) $(SPRITE_MASK2_ASM) \
		-o $(TESTS_DIR)/test_redraw_bench_mask2.bin -create-app
	$(JNEXT) --headless --machine $(JNEXT_MACHINE) --sd-card $(JNEXT_SD) \
		--load $(TESTS_DIR)/test_redraw_bench_mask2.tap \
		--magic-port 0x00FF --magic-port-mode ascii \
		--delayed-automatic-exit 300 2>&1 | grep -E '^(A0?=|B=|END)'

## SP1 benchmark — standalone SP1 program, built with the z88dk new C
## library (-clib=sdcc_iy): sdcc then uses IY as its frame pointer, so
## SP1's asm (which trashes IX) does not corrupt C frames.  No JSP sources.
$(TESTS_DIR)/bench_sp1.tap: $(TESTS_DIR)/bench_sp1.c
	echo Building $@...
	$(ZCC) -vn -SO3 --max-allocs-per-node200000 -startup=31 -clib=sdcc_iy -m \
		$< -o $(@:.tap=.bin) -create-app

# Build and run the SP1 redraw benchmark headless (JSP-vs-SP1 comparison)
bench-sp1: $(TESTS_DIR)/bench_sp1.tap
	$(JNEXT) --headless --machine $(JNEXT_MACHINE) --sd-card $(JNEXT_SD) \
		--load $< --magic-port 0x00FF --magic-port-mode ascii \
		--delayed-automatic-exit 600 2>&1 | grep -E '^(A0?=|B=|END)'

# Run the SP1 redraw benchmark with an all-MASK2 sprite workload
bench-sp1-mask2:
	echo Building all-MASK2 SP1 benchmark...
	$(ZCC) -vn -SO3 --max-allocs-per-node200000 -startup=31 -clib=sdcc_iy -m \
		-DBENCH_ALL_MASK2 $(TESTS_DIR)/bench_sp1.c \
		-o $(TESTS_DIR)/bench_sp1_mask2.bin -create-app
	$(JNEXT) --headless --machine $(JNEXT_MACHINE) --sd-card $(JNEXT_SD) \
		--load $(TESTS_DIR)/bench_sp1_mask2.tap \
		--magic-port 0x00FF --magic-port-mode ascii \
		--delayed-automatic-exit 600 2>&1 | grep -E '^(A0?=|B=|END)'

clean-tests:
	echo Cleaning tests...
	-rm -f $(TEST_TAPS) $(TESTS:%=$(TESTS_DIR)/%.bin) 2>/dev/null
	-rm -f $(TESTS_DIR)/bench_sp1.tap $(TESTS_DIR)/bench_sp1_mask2.tap 2>/dev/null
	-rm -f $(TESTS_DIR)/test_redraw_bench_mask2.tap 2>/dev/null
	-rm -f $(TESTS_DIR)/*.{map,lst,o,lis,sym,bin} 2>/dev/null

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
