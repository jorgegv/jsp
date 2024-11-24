ZCC		= zcc +zx -compiler=sdcc
CFLAGS		= -vn -SO3 --opt-code-size --max-allocs-per-node200000 --list -s -m --c-code-in-asm
LDFLAGS		= -lndos -m

# for a minimal size, replace the above by these:
#ZCC		= zcc +zx -compiler=sdcc -clib=sdcc_iy
#CFLAGS		= -vn -SO3 --opt-code-size --max-allocs-per-node200000 --list -s -m --c-code-in-asm
#LDFLAGS	= -clib=sdcc_iy -startup=31

BIN		= main
TAP		=$(BIN).tap

C_SRCS		= $(wildcard *.c)
ASM_SRCS	= $(wildcard *.asm)

C_OBJS		= $(C_SRCS:.c=.o)
ASM_OBJS	= $(ASM_SRCS:.asm=.o)

.SILENT:

# generic rules
%.o: %.c
	echo Compiling $*.c...
	$(ZCC) $(CFLAGS) -c $*.c

%.o: %.asm
	echo Assembling $*.asm...
	$(ZCC) $(CFLAGS) -c $*.asm

# full build
build: clean $(BIN).bin
	echo Build successful

# clean
clean:
	echo Cleaning up...
	-rm -f $(BIN) $(TAP) *.map *.lst *.o *.lis *.sym *.bin 2>/dev/null

# binary
$(BIN).bin: $(ASM_OBJS) $(C_OBJS)
	echo Linking $@...
	$(ZCC) $(LDFLAGS) $(ASM_OBJS) $(C_OBJS) -o $(BIN) -create-app
	echo Created $(TAP)

# run it
run:
	fuse $(TAP)
