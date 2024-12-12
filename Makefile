ZCC		= zcc +zx -compiler=sdcc
CFLAGS		= -vn -SO3 --opt-code-size --max-allocs-per-node200000 --list -s --c-code-in-asm -I$(INCLUDE_DIR)
LDFLAGS		= -lndos -m

# for a minimal size, replace the above by these:
#ZCC		= zcc +zx -compiler=sdcc -clib=sdcc_iy
#CFLAGS		= -vn -SO3 --opt-code-size --max-allocs-per-node200000 --list -s --c-code-in-asm
#LDFLAGS	= -clib=sdcc_iy -startup=31 -m

BIN		= main
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
clean:
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
	fuse $(TAP)

## extras

test_sprite.asm:
	../zxtools/bin/gfxgen.pl -i assets/ball.png -x 0 -y 0 --width 16 --height 16 \
		-m FF0000 -f FFFFFF -b 000000 \
		--code-type asm -s _test_sprite_pixels \
		-g sprite -l columns --extra-bottom-row > test_sprite.asm
