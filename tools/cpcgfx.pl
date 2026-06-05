#!/usr/bin/env perl
#
# cpcgfx.pl — JSP-CPC sprite/tile asset emitter (in-repo CPC counterpart of the
# ZX-only ../zxtools/bin/gfxgen.pl, per doc/CPC-TARGET-PLAN.md §10).
#
# Reuses the ZXGfx library (PNG load + cell extraction) from ../zxtools so the
# source art and colour handling are shared with the ZX pipeline, and emits the
# per-mode CPC byte format documented in doc/CPC-ASSETS-FORMAT.md.
#
# Mode 1 (this tool's initial target): 4 px/byte, two interleaved nibble-planes.
# An 8-px-wide ZX cell becomes TWO 4-px Mode-1 cells (left half -> high 4 source
# pixels, right half -> low 4), so a W-cell-wide sprite emits 2*W Mode-1 columns.
# The source art is 2-colour (pen 0 = background, pen 1 = foreground), so each
# source pixel maps to Mode-1 pen 0/1: plane-0 bit = the pixel, plane-1 bit = 0.
# (Full 4-pen art is a future extension; the shift kernels already handle every
# byte value — proved exhaustively by make cpc-shift-test-mode1.)
#
# Pixel encoding (CPC Mode 1): pixel p (0 = leftmost) of a byte has its plane-0
# bit at position (7-p) (high nibble) and plane-1 bit at (3-p) (low nibble).  For
# pen 0/1 art the low nibble is always 0, so:
#     graph_left  = src_graph & 0xF0          ; source px 7..4 -> this byte px 0..3
#     graph_right = (src_graph & 0x0F) << 4    ; source px 3..0 -> this byte px 0..3
# A Mode-1 mask keeps the background where both planes are set, so a transparent
# source pixel -> both nibbles set:
#     mask_left   = (src_mask & 0xF0) | ((src_mask & 0xF0) >> 4)
#     mask_right  = ((src_mask & 0x0F) << 4) | (src_mask & 0x0F)
#
# Layout matches the ZX sprite convention (columns-major, 7 transparent pre-rows
# before the label).  For safe sub-cell Y, each column is followed by 7 (NOT 8)
# blank scanlines: the vertical shift reads at most 7 lines beyond the data, and a
# column's trailing 7 blanks serve as the next column's leading 7 (they overlap).
# So the engine column stride is rows*cs + 7*(cs/8) = (rows+1)*cs - (cs/8); the
# matching `- (cs>>3)` correction lives in jsp_frame.asm (base + pdc*rowstride + i*cs).

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";	# vendored ZXGfx.pm (tools/lib) — JSP self-contained

use Getopt::Long;
use GD;
use ZXGfx;

my ($opt_input, $opt_xpos, $opt_ypos, $opt_width, $opt_height,
    $opt_mask, $opt_foreground, $opt_background, $opt_symbol_name,
    $opt_gfx_type, $opt_extra_bottom_row, $opt_extra_top_rows, $opt_mode,
    $opt_multicolor, $opt_palette_symbol);

Getopt::Long::Configure("no_auto_abbrev", "bundling");
GetOptions(
    'input|i=s'        => \$opt_input,
    'xpos|x:i'         => \$opt_xpos,
    'ypos|y:i'         => \$opt_ypos,
    'width=i'          => \$opt_width,
    'height=i'         => \$opt_height,
    'mask|m:s'         => \$opt_mask,
    'foreground|f:s'   => \$opt_foreground,
    'background|b:s'   => \$opt_background,
    'symbol-name|s=s'  => \$opt_symbol_name,
    'gfx-type|g=s'     => \$opt_gfx_type,
    'extra-bottom-row' => \$opt_extra_bottom_row,
    'extra-top-rows'   => \$opt_extra_top_rows,
    'mode=i'           => \$opt_mode,
    'multicolor'       => \$opt_multicolor,
    'palette-symbol=s' => \$opt_palette_symbol,
) or die "bad options\n";

defined($opt_input) && defined($opt_width) && defined($opt_height) &&
    defined($opt_symbol_name) && defined($opt_gfx_type)
    or die "usage: cpcgfx.pl -i PNG -x X -y Y --width W --height H -s SYM -g sprite_mask|sprite_load|tile [--mode 0|1] [--extra-bottom-row] [--extra-top-rows] [-m/-f/-b RRGGBB] [--multicolor [--palette-symbol SYM]]\n";

$opt_xpos       //= 0;
$opt_ypos       //= 0;
$opt_mask       //= 'FF0000';
$opt_foreground //= 'FFFFFF';
$opt_background //= '000000';
$opt_mode       //= 1;
$opt_mask       = uc($opt_mask);
$opt_foreground = uc($opt_foreground);
$opt_background = uc($opt_background);

( $opt_mode == 1 || $opt_mode == 0 )
    or die "cpcgfx.pl: --mode must be 0 or 1\n";
$opt_gfx_type = 'sprite_mask' if $opt_gfx_type eq 'sprite';
$opt_gfx_type =~ /^(sprite_(mask|load)|tile)$/
    or die "--gfx-type must be sprite_mask, sprite_load or tile\n";
my $is_mask = ($opt_gfx_type eq 'sprite_mask');
my $is_tile = ($opt_gfx_type eq 'tile');

# ---- per-mode geometry -----------------------------------------------------
# Each 8-px ZX source column splits into $subcols Mode-N cells of $ppc pixels:
#   Mode 1 = 4 px/byte -> 2 cells;  Mode 0 = 2 px/byte -> 4 cells.
# The CPC byte interleaves $nplanes planes; cell-pixel cp's plane q bit sits at
# (7-cp) - q*$ppc.  For 2-colour (pen 0/1) art only plane 0 (pen 1) is set;
# a transparent mask pixel sets ALL planes (so the AND keeps the background).
my $ppc     = ($opt_mode == 1) ? 4 : 2;
my $subcols = 8 / $ppc;                  # cells per 8-px source column (2 or 4)
my $nplanes = 8 / $ppc;                  # planes per byte (2 for M1, 4 for M0)

# Render $ppc cell pixels for a graphic/mask byte's comment (plane-0 set = '#').
sub pixstr {
    my $b = shift;
    my $s = '';
    foreach my $cp (0 .. $ppc - 1) { $s .= (($b >> (7 - $cp)) & 1) ? '#' : '.'; }
    return $s;
}

# ============================================================================
# CPC hardware palette (the 27 colours).  Each entry is [ hw_ink, R, G, B ]:
# hw_ink is the 6-bit Gate-Array colour number (the byte written to program a
# pen is 0x40 | hw_ink); RGB uses the CPC's three levels per channel
# (0 / 128 / 255).  Values from cpctelera src/video/colours.h + the standard
# CPCWiki RGB table.  Used by --multicolor to map each PNG pixel to the nearest
# CPC ink and to emit the palette (--palette-symbol).
# ============================================================================
my @cpc_palette = (
    [ 0x14,   0,   0,   0 ],  # BLACK
    [ 0x04,   0,   0, 128 ],  # BLUE
    [ 0x15,   0,   0, 255 ],  # BRIGHT_BLUE
    [ 0x1C, 128,   0,   0 ],  # RED
    [ 0x18, 128,   0, 128 ],  # MAGENTA
    [ 0x1D, 128,   0, 255 ],  # MAUVE
    [ 0x0C, 255,   0,   0 ],  # BRIGHT_RED
    [ 0x05, 255,   0, 128 ],  # PURPLE
    [ 0x0D, 255,   0, 255 ],  # BRIGHT_MAGENTA
    [ 0x16,   0, 128,   0 ],  # GREEN
    [ 0x06,   0, 128, 128 ],  # CYAN
    [ 0x17,   0, 128, 255 ],  # SKY_BLUE
    [ 0x1E, 128, 128,   0 ],  # YELLOW
    [ 0x00, 128, 128, 128 ],  # WHITE (grey)
    [ 0x1F, 128, 128, 255 ],  # PASTEL_BLUE
    [ 0x0E, 255, 128,   0 ],  # ORANGE
    [ 0x07, 255, 128, 128 ],  # PINK
    [ 0x0F, 255, 128, 255 ],  # PASTEL_MAGENTA
    [ 0x12,   0, 255,   0 ],  # BRIGHT_GREEN
    [ 0x02,   0, 255, 128 ],  # SEA_GREEN
    [ 0x13,   0, 255, 255 ],  # BRIGHT_CYAN
    [ 0x1A, 128, 255,   0 ],  # LIME
    [ 0x19, 128, 255, 128 ],  # PASTEL_GREEN
    [ 0x1B, 128, 255, 255 ],  # PASTEL_CYAN
    [ 0x0A, 255, 255,   0 ],  # BRIGHT_YELLOW
    [ 0x03, 255, 255, 128 ],  # PASTEL_YELLOW
    [ 0x0B, 255, 255, 255 ],  # BRIGHT_WHITE
);
my %cpc_ink_name = (
    0x14=>'BLACK',0x04=>'BLUE',0x15=>'BRIGHT_BLUE',0x1C=>'RED',0x18=>'MAGENTA',
    0x1D=>'MAUVE',0x0C=>'BRIGHT_RED',0x05=>'PURPLE',0x0D=>'BRIGHT_MAGENTA',
    0x16=>'GREEN',0x06=>'CYAN',0x17=>'SKY_BLUE',0x1E=>'YELLOW',0x00=>'WHITE',
    0x1F=>'PASTEL_BLUE',0x0E=>'ORANGE',0x07=>'PINK',0x0F=>'PASTEL_MAGENTA',
    0x12=>'BRIGHT_GREEN',0x02=>'SEA_GREEN',0x13=>'BRIGHT_CYAN',0x1A=>'LIME',
    0x19=>'PASTEL_GREEN',0x1B=>'PASTEL_CYAN',0x0A=>'BRIGHT_YELLOW',
    0x03=>'PASTEL_YELLOW',0x0B=>'BRIGHT_WHITE',
);
# Nearest CPC hw ink for an 'rrggbb' hex colour (Euclidean RGB distance, cached).
my %ink_cache;
sub nearest_cpc_ink {
    my $hex = lc shift;
    return $ink_cache{$hex} if exists $ink_cache{$hex};
    $hex =~ /^([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/
        or die "cpcgfx.pl: bad colour '$hex'\n";
    my ($r,$g,$b) = (hex $1, hex $2, hex $3);
    my ($best, $bestd);
    foreach my $e (@cpc_palette) {
        my $d = ($e->[1]-$r)**2 + ($e->[2]-$g)**2 + ($e->[3]-$b)**2;
        ($best, $bestd) = ($e->[0], $d) if !defined($bestd) || $d < $bestd;
    }
    return $ink_cache{$hex} = $best;
}

# ---- source data: a per-pixel pen grid (@PEN) + transparency grid (@TRANSP) -
# Both paths fill these; emit_cell reads them.  In --multicolor we read the raw
# PNG RGB (NO ZX-palette snap) and map every pixel to a CPC pen; otherwise we
# reuse the 2-colour ZXGfx extractor (pen 0 = background, pen 1 = foreground).
my (@PEN, @TRANSP);         # [y][x] -> pen index / 1 if transparent (mask)
my @ink_of_pen;             # pen index -> CPC hw ink (multicolor; for palette)
my $npens = 0;
my ($wcells, $hcells);

if ($opt_multicolor) {
    ($opt_width % 8 == 0 && $opt_height % 8 == 0)
        or die "cpcgfx.pl: --multicolor needs width/height multiples of 8\n";
    my $png = GD::Image->newFromPng($opt_input)
        or die "cpcgfx.pl: cannot load PNG '$opt_input'\n";
    my $maxpens  = ($opt_mode == 1) ? 4 : 16;
    my $mask_ink = nearest_cpc_ink($opt_mask);
    my %pen_of_ink;
    # pen 0 is always the background ink (paper), like the 2-colour convention.
    my $bg_ink = nearest_cpc_ink($opt_background);
    $pen_of_ink{$bg_ink} = 0; $ink_of_pen[0] = $bg_ink; $npens = 1;
    foreach my $y (0 .. $opt_height - 1) {
        foreach my $x (0 .. $opt_width - 1) {
            my $hex = sprintf('%02x%02x%02x', $png->rgb($png->getPixel($opt_xpos+$x, $opt_ypos+$y)));
            my $ink = nearest_cpc_ink($hex);
            if ($is_mask && $ink == $mask_ink) { $TRANSP[$y][$x] = 1; $PEN[$y][$x] = 0; next; }
            if (!exists $pen_of_ink{$ink}) {
                $pen_of_ink{$ink} = $npens; $ink_of_pen[$npens] = $ink; $npens++;
            }
            $TRANSP[$y][$x] = 0;
            $PEN[$y][$x]    = $pen_of_ink{$ink};
        }
    }
    $npens <= $maxpens or die sprintf(
        "cpcgfx.pl: %s uses %d opaque colours but Mode %d allows only %d pens\n",
        $opt_input, $npens, $opt_mode, $maxpens);
    $wcells = $opt_width / 8;
    $hcells = $opt_height / 8;
} else {
    # ---- 2-colour path: extract via ZXGfx (shared with gfxgen) -------------
    my $gfx = zxgfx_extract_from_png($opt_input, $opt_xpos, $opt_ypos,
                                     $opt_width, $opt_height, 0, 0);
    my $errors = zxgfx_validate_cell_colors($gfx, 3);
    die join("\n", "Error: incompatible colours in source image:", @$errors)."\n" if @$errors;
    zxgfx_extract_sprite_cells($gfx, $opt_foreground, $opt_background, $opt_mask);
    $wcells = zxgfx_get_width_cells($gfx);
    $hcells = zxgfx_get_height_cells($gfx);
    # Flatten the 1bpp fg/mask cell data into the pen/transparency grids so the
    # single emit path below is shared with --multicolor (pen 1 = foreground).
    foreach my $cr (0 .. $hcells - 1) {
        foreach my $cc (0 .. $wcells - 1) {
            my $cell = $gfx->{'cells'}[$cr][$cc];
            foreach my $line (0 .. 7) {
                my $g = $cell->{'bytes'}[$line];
                my $m = $is_mask ? $cell->{'masks'}[$line] : 0;
                foreach my $px (0 .. 7) {
                    my $y = $cr*8 + $line; my $x = $cc*8 + $px;
                    if ($is_mask && (($m >> (7-$px)) & 1)) { $TRANSP[$y][$x] = 1; $PEN[$y][$x] = 0; }
                    else { $TRANSP[$y][$x] = 0; $PEN[$y][$x] = (($g >> (7-$px)) & 1); }
                }
            }
        }
    }
}

my $ncols  = $subcols * $wcells;  # each 8-px source column -> $subcols Mode-N cells
my $cs     = $is_mask ? 16 : 8;   # bytes per Mode-N cell-row
my $bottom = $opt_extra_bottom_row ? 1 : 0;
# Only 7 blank scanlines (not a full 8-line cell) are needed for sub-cell Y: the
# vertical shift reads at most 7 lines past the data, and a column's trailing 7
# blanks double as the next column's leading 7 (they overlap).  So each column is
# rows*cs + 7*(cs/8) bytes apart, matching the engine rowstride (see jsp_frame.asm).
my $body_bytes = $ncols * ($hcells * $cs + ($bottom ? 7 * ($cs / 8) : 0));

# Graphic + mask byte for cell (col,row), sub-column $sub, scanline $line, built
# from the per-pixel pen grid.  Plane q of cell-pixel cp sits at bit (7-cp)-q*ppc
# (matches the engine's m0_cell / the rotating kernels); a transparent pixel sets
# every plane in the mask so the AND keeps the background.  For 2-colour input
# (pen 1 = foreground) only plane 0 is ever set, so the bytes are identical to
# the previous graph_sub/mask_sub output.
sub cell_bytes {
    my ($col, $row, $sub, $line) = @_;
    my $y  = $row * 8 + $line;
    my $xb = $col * 8 + $sub * $ppc;
    my ($g, $m) = (0, 0);
    foreach my $cp (0 .. $ppc - 1) {
        my $x = $xb + $cp;
        if ($TRANSP[$y][$x]) {
            foreach my $q (0 .. $nplanes - 1) { $m |= 1 << ((7 - $cp) - $q * $ppc); }
        } else {
            my $pen = $PEN[$y][$x];
            foreach my $q (0 .. $nplanes - 1) {
                $g |= 1 << ((7 - $cp) - $q * $ppc) if ($pen >> $q) & 1;
            }
        }
    }
    return ($g, $m);
}
# Pen digit per cell-pixel for multicolor comments ('.' = transparent).
sub penstr {
    my ($col, $row, $sub, $line) = @_;
    my $y  = $row * 8 + $line;
    my $xb = $col * 8 + $sub * $ppc;
    my $s  = '';
    foreach my $cp (0 .. $ppc - 1) {
        my $x = $xb + $cp;
        $s .= $TRANSP[$y][$x] ? '.' : sprintf('%x', $PEN[$y][$x]);
    }
    return $s;
}

# ---- emit one Mode-N cell ($sub = sub-column 0..$subcols-1 of source col) ---
sub emit_cell {
    my ($col, $row, $sub) = @_;
    foreach my $line (0..7) {
        my ($mg, $mm) = cell_bytes($col, $row, $sub, $line);
        my $pix = $opt_multicolor ? penstr($col, $row, $sub, $line) : pixstr($mg);
        if ($is_mask) {
            printf "\tdb\t\$%02x,\$%02x\t\t;; mask %s pix %s\n", $mm, $mg, pixstr($mm), $pix;
        } else {
            printf "\tdb\t\$%02x\t\t;; pix %s\n", $mg, $pix;
        }
    }
}

sub emit_blank_lines {
    my $n = shift;
    foreach (1..$n) {
        if ($is_mask) { print "\tdb\t\$ff,\$00\n"; }
        else          { print "\tdb\t\$00\n"; }
    }
}

# ---- output ----------------------------------------------------------------
print "\tsection data_compiler\n\n";

if ($is_tile) {
    # PIXEL-CELL TILE (Model B): each 8x8 source cell -> one pixel-cell =
    # $subcols byte-columns x 8 lines, COLUMN-MAJOR (col0's 8 bytes, then col1's,
    # ...), graph-only, NO sub-cell padding (tiles sit on cell boundaries).  This
    # is exactly the JSP_CELL_BYTES (16 for M1, 32 for M0) layout the pixel-cell
    # wide-cell blit / BTT expects; pass the symbol to jsp_draw_background_tile.
    my $cellbytes = $subcols * 8;
    printf ";; CPC Mode %d pixel-cell TILE '%s'\n", $opt_mode, $opt_symbol_name;
    printf ";; source %s region (%d,%d) %dx%d px -> %d x %d cells, %d bytes/cell\n",
        $opt_input, $opt_xpos, $opt_ypos, $opt_width, $opt_height,
        $hcells, $wcells, $cellbytes;
    printf "PUBLIC %s\n%s:\n", $opt_symbol_name, $opt_symbol_name;
    foreach my $row (0 .. $hcells - 1) {
        foreach my $col (0 .. $wcells - 1) {
            printf "\t;; tile cell (row %d, col %d) -> %d-byte pixel-cell (column-major)\n",
                $row, $col, $cellbytes;
            foreach my $sub (0 .. $subcols - 1) {   # byte-columns, left -> right
                emit_cell($col, $row, $sub);        # 8 graph lines (is_mask=0)
            }
        }
    }
    print ";;;;;;\n";
} else {
    printf ";; CPC Mode %d sprite '%s' (%s)\n", $opt_mode, $opt_symbol_name, $opt_gfx_type;
    printf ";; source %s region (%d,%d) %dx%d px -> %d Mode-%d cols x %d rows%s\n",
        $opt_input, $opt_xpos, $opt_ypos, $opt_width, $opt_height,
        $ncols, $opt_mode, $hcells, ($bottom ? " (+extra bottom row)" : "");
    printf ";; %s: %d body bytes (cs=%d, %d px/cell)\n", $opt_symbol_name, $body_bytes, $cs, $ppc;

    if ($opt_extra_top_rows) {
        print "\t;; 7 transparent pre-rows before label (safe sub-cell Y)\n";
        emit_blank_lines(7);
    }
    printf "PUBLIC %s\n%s:\n", $opt_symbol_name, $opt_symbol_name;

    foreach my $mc (0 .. $ncols - 1) {
        my $col = int($mc / $subcols);  # original 8-px source column
        my $sub = $mc % $subcols;       # which $ppc-px slice of it (left -> right)
        printf "\t;; Mode-%d col %d (src col %d, slice %d)\n", $opt_mode, $mc, $col, $sub;
        foreach my $row (0 .. $hcells - 1) {
            emit_cell($col, $row, $sub);
        }
        emit_blank_lines(7 * $bottom);  # 7-line bottom/inter-column gap (see header)
    }
    print ";;;;;;\n";
}

# ---- palette source (multicolor, --palette-symbol) -------------------------
# Emit a Gate-Array ink byte (0x40 | hw_ink) per pen, padded to the mode's full
# pen count (4 for Mode 1, 16 for Mode 0) so a test harness can program every
# pen unconditionally; unused pens repeat pen 0 (the background).  The C harness
# declares `extern uint8_t <sym>[];` and writes each byte straight to the GA.
if ($opt_palette_symbol) {
    $opt_multicolor or die "cpcgfx.pl: --palette-symbol requires --multicolor\n";
    my $penmax = ($opt_mode == 1) ? 4 : 16;
    printf "\n;; CPC Mode %d palette for '%s' : %d used pen(s), padded to %d\n",
        $opt_mode, $opt_symbol_name, $npens, $penmax;
    printf "PUBLIC %s\n%s:\n", $opt_palette_symbol, $opt_palette_symbol;
    foreach my $pen (0 .. $penmax - 1) {
        my $ink  = defined($ink_of_pen[$pen]) ? $ink_of_pen[$pen] : $ink_of_pen[0];
        my $used = defined($ink_of_pen[$pen]) ? $cpc_ink_name{$ink} : "unused (= pen 0)";
        printf "\tdb\t\$%02x\t\t;; pen %2d = %s\n", (0x40 | $ink), $pen, $used;
    }
    print ";;;;;;\n";
}
