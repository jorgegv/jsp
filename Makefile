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

INCLUDE_DIR	= include

C_SRCS		= $(wildcard lib/*.c) $(wildcard *.c)
ASM_SRCS	= $(wildcard lib/*.asm) $(wildcard *.asm)

C_OBJS		= $(C_SRCS:.c=.o)
ASM_OBJS	= $(ASM_SRCS:.asm=.o)

.SILENT:
MAKEFLAGS 	+= --no-print-directory -j4

# generic rules
%.o: %.c
	echo Compiling $*.c...
	$(ZCC) $(CFLAGS) -c $*.c

%.o: %.asm
	echo Assembling $*.asm...
	$(ZCC) $(CFLAGS) -c $*.asm

default: $(BIN)

# full build
build:
	make clean
	make $(TAP)
	echo Build successful

# clean
clean: clean-tests
	echo Cleaning up...
	-rm -f $(BIN) $(TAP) *.{map,lst,o,lis,sym,bin} 2>/dev/null
	-rm -f lib/*.{map,lst,o,lis,sym,bin} 2>/dev/null

# binary
$(BIN): $(ASM_OBJS) $(C_OBJS)
	echo Linking $@...
	$(ZCC) $(LDFLAGS) $(ASM_OBJS) $(C_OBJS) -o $(BIN) -create-app
	echo Created $(TAP)

$(TAP): $(BIN)

# run it
run: $(TAP)
	$(FUSE) $(TAP)

## tests

TESTS_DIR	= tests
LIB_SRCS	= $(wildcard lib/*.c) $(wildcard lib/*.asm)

SPRITE_MASK2_ASM = test_sprite_mask2.asm
SPRITE_LOAD1_ASM = test_sprite_load1.asm

TESTS		= test_dtt test_btt_contents test_btt_redraw test_sprite_draw \
		  test_sprite_move test_pool_and_colour test_tiles_and_print
TEST_TAPS	= $(TESTS:%=$(TESTS_DIR)/%.tap)

.PHONY: tests
tests: $(TEST_TAPS)

# Pattern rule: compile test + all lib sources in one zcc invocation
$(TESTS_DIR)/%.tap: $(TESTS_DIR)/%.c $(LIB_SRCS)
	echo Building $@...
	$(ZCC) $(CFLAGS) $(LDFLAGS) $^ -o $(@:.tap=.bin) -create-app

# Extra sprite data prerequisites for tests that use sprites
$(TESTS_DIR)/test_sprite_draw.tap: $(SPRITE_MASK2_ASM)
$(TESTS_DIR)/test_sprite_move.tap: $(SPRITE_MASK2_ASM) $(SPRITE_LOAD1_ASM)
$(TESTS_DIR)/test_pool_and_colour.tap: $(SPRITE_MASK2_ASM)

# run a single test (usage: make run-test TEST=test_dtt)
run-test: $(TESTS_DIR)/$(TEST).tap
	fuse $(TESTS_DIR)/$(TEST).tap

clean-tests:
	echo Cleaning tests...
	-rm -f $(TEST_TAPS) $(TESTS:%=$(TESTS_DIR)/%.bin) 2>/dev/null
	-rm -f $(TESTS_DIR)/*.{map,lst,o,lis,sym,bin} 2>/dev/null

## extras

test_sprite_mask2.asm:
	../zxtools/bin/gfxgen.pl -i assets/ball.png -x 0 -y 0 --width 16 --height 16 \
		-m FF0000 -f FFFFFF -b 000000 \
		--code-type asm -s _test_sprite_mask2_pixels \
		-g sprite_mask -l columns --extra-bottom-row > test_sprite_mask2.asm

test_sprite_load1.asm:
	../zxtools/bin/gfxgen.pl -i assets/ball.png -x 0 -y 0 --width 16 --height 16 \
		-m FF0000 -f FFFFFF -b 000000 \
		--code-type asm -s _test_sprite_load1_pixels \
		-g sprite_load -l columns --extra-bottom-row > test_sprite_load1.asm
