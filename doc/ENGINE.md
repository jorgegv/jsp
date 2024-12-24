# ENGINE NOTES

A "tile" is an 8x8 UDG stored top to down in memory (8 consecutive bytes)

## ENGINE MEMORY AREAS

- BTT: Background tiles table: a table of 768 pointers to the background tiles
  (only background, no sprites) for each screen cell - 1536 bytes

- DRT: Drawing records table: a table of 768 pointers to the final tile that will
  be drawn (including sprites), for each screen cell - 1536 bytes

- DTT: Dirty tiles table: a table of 768 bits (_not_ bytes), indicating what
  tiles need to be redrawn on each frame - 96 bytes

## SPRITE DEFINITIONS

- Normal graphic definition ( M x N chars )

- Additionally, a private drawing buffer (PDB) of (M+1) x (N+1) chars. 
  Since we can move about 10 simultaneous 16x16 sprites, that's 90 cells to
  be drawn, so maximum overhead of 90 x 8 = 720 bytes

## WORKFLOW FOR DRAWING BACKGROUND TILES

- For drawing a tile, copy it's address (pointer to 8-byte data) in its corresponding
  position in the BTT

- For removing a tile, set the corresponding position in the BTT to NULL (0)

## WORKFLOW FOR DRAWING SPRITES

- DTT must be fully set to 0 (this is done by the drawing function after
  drawing everything)

- DRT must contain the same pointers as BTT (this is done by the drawing
  function after drawing everything)

- For each sprite:

  - Mark as dirty the cells corresponding to the previous position

  - Save the new coordinates

  - Copy the background tiles for that sprite from the DRT cells to the
    sprite's PDB

  - Draw the sprite on the PDB over the previous contents, with your
    preferred method (masked, or, xor, etc.), preshifted, rotated, etc.

  - Update the DRT cells corresponding to the sprite position to point to
    this sprite's PDB cells.  Doing this, sprites can be drawn over another
    and everything looks ok

  - Mark as dirty the DTT cells corresponding to the sprite position

At this point, the sprites have been drawn in order (whatever your order
is), the DTT contains the dirty cells that need to be redrawn, and the DRT
contains the pointers to the contents to be drawn.

## WORKFLOW FOR REDRAWING THE SCREEN

- Walk the DTT byte by byte. This can be done very quickly, since we skip
  bytes that are 0 (which means those 8 cells need not be redrawn), and most
  cells will _not_ be redrawn (i.e. will be 0).

- When some DTT byte is not zero, process the bits. For each bit:
  - If it is 0, skip to next bit
  - If it is 1:
    - Get the address of the final tile to draw from the DRT an the position
      of this cell
    - Draw the tile to screen
    - Reset the bit to 0
    - Copy the pointer from BTT to DRT on the same position
    - These last two operations are much faster if done inside the drawing
    loop (max ~900T for DTT) than fully resetting DTT and DRT after the
    drawing loop (~2000T for LDIR, ~2500T for LD (HL),A, for DTT)
    
At this point, all dirty cells have been redrawn, and the DTT and DRT have
been reset for the next drawing cycle.

## MEMORY MAPS

Be careful when using JSP with the standard ROM interrupt routine, some of its routines use the IY register!

**48K MODE**

| Range     | Contents                                          |
|-----------|---------------------------------------------------|
| F200-FFFF | Rotation tables (3.5 kB, 256-aligned)             |
| EC00-F199 | Background Tiles Table, BTT (1.5 kB, 256-aligned) |
| E600-EB99 | Drawing Records Table, DRT (1.5 kB, 256-aligned)  |
| E5A0-E5FF | Dirty Tiles Table, DTT (96 bytes)                 |
| 5D00-E59F | free for program code and data (34976 bytes)      |

- These structures should not be in contended memory, since they must be checked at top speed.

**128K MODE**

The layout is similar to 48K mode, but down 16K, in order to free up the C000-FFFF range for banking:

| Range     | Contents                                          |
|-----------|---------------------------------------------------|
| B200-BFFF | Rotation tables (3.5 kB, 256-aligned)             |
| AC00-B199 | Background Tiles Table, BTT (1.5 kB, 256-aligned) |
| A600-AB99 | Drawing Records Table, DRT (1.5 kB, 256-aligned)  |
| A5A0-A5FF | Dirty Tiles Table, DTT (96 bytes)                 |
| 5D00-A59F | free for program code and data (18592 bytes)      |

- These structures should not be in contended memory, since they must be checked at top speed.
