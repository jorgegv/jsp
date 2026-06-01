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
# before the label, optional extra blank bottom cell-row per column) so the
# engine's rowstride math (base + pdc*rowstride + i*cs) is unchanged.

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../zxtools/lib";

use Getopt::Long;
use ZXGfx;

my ($opt_input, $opt_xpos, $opt_ypos, $opt_width, $opt_height,
    $opt_mask, $opt_foreground, $opt_background, $opt_symbol_name,
    $opt_gfx_type, $opt_extra_bottom_row, $opt_extra_top_rows, $opt_mode);

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
) or die "bad options\n";

defined($opt_input) && defined($opt_width) && defined($opt_height) &&
    defined($opt_symbol_name) && defined($opt_gfx_type)
    or die "usage: cpcgfx.pl -i PNG -x X -y Y --width W --height H -s SYM -g sprite_mask|sprite_load [--mode 1] [--extra-bottom-row] [--extra-top-rows] [-m/-f/-b RRGGBB]\n";

$opt_xpos       //= 0;
$opt_ypos       //= 0;
$opt_mask       //= 'FF0000';
$opt_foreground //= 'FFFFFF';
$opt_background //= '000000';
$opt_mode       //= 1;
$opt_mask       = uc($opt_mask);
$opt_foreground = uc($opt_foreground);
$opt_background = uc($opt_background);

$opt_mode == 1 or die "cpcgfx.pl: only --mode 1 is implemented so far\n";
$opt_gfx_type = 'sprite_mask' if $opt_gfx_type eq 'sprite';
$opt_gfx_type =~ /^sprite_(mask|load)$/
    or die "--gfx-type must be sprite_mask or sprite_load\n";
my $is_mask = ($opt_gfx_type eq 'sprite_mask');

# ---- Mode-1 per-byte conversion (2-colour pen0/pen1) -----------------------
sub g_left  { return  $_[0] & 0xF0; }
sub g_right { return ($_[0] & 0x0F) << 4; }
sub m_left  { my $h = $_[0] & 0xF0; return $h | ($h >> 4); }
sub m_right { my $l = $_[0] & 0x0F; return ($l << 4) | $l; }

sub byte2graph_m1 {
    # render 4 Mode-1 pixels for the comment (pen value 0..3 per pixel)
    my $b = shift;
    my $s = '';
    foreach my $p (0..3) {
        my $pen = ((($b >> (7 - $p)) & 1)) | ((($b >> (3 - $p)) & 1) << 1);
        $s .= ('.','#',':','@')[$pen];
    }
    return $s;
}

# ---- extract cells via ZXGfx (shared with gfxgen) --------------------------
my $gfx = zxgfx_extract_from_png($opt_input, $opt_xpos, $opt_ypos,
                                 $opt_width, $opt_height, 0, 0);
my $errors = zxgfx_validate_cell_colors($gfx, 3);
die join("\n", "Error: incompatible colours in source image:", @$errors)."\n" if @$errors;
zxgfx_extract_sprite_cells($gfx, $opt_foreground, $opt_background, $opt_mask);

my $wcells = zxgfx_get_width_cells($gfx);
my $hcells = zxgfx_get_height_cells($gfx);
my $m1cols = 2 * $wcells;       # each 8-px cell -> two 4-px Mode-1 columns
my $cs     = $is_mask ? 16 : 8; # bytes per Mode-1 cell-row
my $bottom = $opt_extra_bottom_row ? 1 : 0;
my $body_bytes = $m1cols * ($hcells + $bottom) * $cs;

# ---- emit a single cell-row of `half` (0=left,1=right) of original column ---
sub emit_cell {
    my ($col, $row, $half) = @_;
    my $bytes = $gfx->{'cells'}[$row][$col]{'bytes'};
    my $masks = $gfx->{'cells'}[$row][$col]{'masks'};
    foreach my $line (0..7) {
        my $g = $bytes->[$line];
        if ($is_mask) {
            my $msk = $masks->[$line];
            my ($mg, $mm) = $half == 0 ? (g_left($g),  m_left($msk))
                                       : (g_right($g), m_right($msk));
            printf "\tdb\t\$%02x,\$%02x\t\t;; mask %s pix %s\n",
                $mm, $mg, byte2graph_m1($mm), byte2graph_m1($mg);
        } else {
            my $mg = $half == 0 ? g_left($g) : g_right($g);
            printf "\tdb\t\$%02x\t\t;; pix %s\n", $mg, byte2graph_m1($mg);
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
printf ";; CPC Mode 1 sprite '%s' (%s)\n", $opt_symbol_name, $opt_gfx_type;
printf ";; source %s region (%d,%d) %dx%d px -> %d Mode-1 cols x %d rows%s\n",
    $opt_input, $opt_xpos, $opt_ypos, $opt_width, $opt_height,
    $m1cols, $hcells, ($bottom ? " (+extra bottom row)" : "");
printf ";; %s: %d body bytes (cs=%d)\n", $opt_symbol_name, $body_bytes, $cs;

if ($opt_extra_top_rows) {
    print "\t;; 7 transparent pre-rows before label (safe sub-cell Y)\n";
    emit_blank_lines(7);
}
printf "PUBLIC %s\n%s:\n", $opt_symbol_name, $opt_symbol_name;

foreach my $mc (0 .. $m1cols - 1) {
    my $col  = $mc >> 1;        # original 8-px column
    my $half = $mc & 1;         # 0 = left 4 px, 1 = right 4 px
    printf "\t;; Mode-1 col %d (orig col %d, %s half)\n",
        $mc, $col, ($half ? 'right' : 'left');
    foreach my $row (0 .. $hcells - 1) {
        emit_cell($col, $row, $half);
    }
    emit_blank_lines(8 * $bottom);  # extra blank bottom cell-row
}
print ";;;;;;\n";
