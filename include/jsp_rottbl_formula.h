#ifndef _JSP_ROTTBL_FORMULA_H
#define _JSP_ROTTBL_FORMULA_H

// Single source of truth for the rotation-table entries, shared by
// lib/jsp_init.c (jsp_init_rottbl) and the host shift unit tests
// (tests/cpc/shift_test_mode*.c) so the production code and its tests cannot
// drift apart.
//
// For shift phase i and source byte val, a sprite byte shifted right by i
// pixels splits across a 16-bit (two-byte) window: the "in-byte" part stays in
// this byte, the "carry" part spills into the next byte to the right.  The
// compositor combines this column's in-byte with the LEFT column's carry:
//
//     out_byte = JSP_ROTTBL_IN( this ) | JSP_ROTTBL_CARRY( left )
//
// The split is mode-dependent (it must be a true 1-pixel-per-step horizontal
// shift in the mode's pixel encoding), so the IN/CARRY macros are selected by
// the active CPC mode guard; ZX / Mode 2 is the default 1bpp-linear form.

#if defined( CPC_MODE1 ) || defined( CPC_MODE1_MONO )

// ---- Mode 1: 4 px/byte, two interleaved nibble-planes ----------------------
// A Mode-1 byte holds 4 pixels (2 bits each).  Pixel p (0 = leftmost) has its
// plane-0 bit at position (7-p) in the high nibble and its plane-1 bit at
// position (3-p) in the low nibble.  A 1-pixel right shift moves every pixel
// one slot right; phase i (1..3) shifts by i pixels.  The (4-i) leftmost
// pixels of each nibble stay in-byte; the i rightmost pixels spill as carry.
//
//   in-byte mask  = the (4-i) high bits of each nibble  = ((0x0F<<i)&0x0F)*0x11
//   carry   mask  = the i      low  bits of each nibble = ((0x0F>>(4-i))&0x0F)*0x11
//   in    = (val & in-mask) >> i        ; pixels move i slots right, within byte
//   carry = (val & carry-mask) << (4-i) ; spilled pixels land in the left slots
//
// Closed forms: i=1 in=(v&0xEE)>>1 carry=(v&0x11)<<3; i=2 in=(v&0xCC)>>2
// carry=(v&0x33)<<2; i=3 in=(v&0x88)>>3 carry=(v&0x77)<<1.  Verified bit-exact
// against an independent pixel-array shift by make cpc-shift-test-mode1.
#define JSP_ROTTBL_IN(val,i)    ( ( (val) & ( ( ( 0x0F << (i) ) & 0x0F ) * 0x11 ) ) >> (i) )
#define JSP_ROTTBL_CARRY(val,i) ( ( (val) & ( ( ( 0x0F >> ( 4 - (i) ) ) & 0x0F ) * 0x11 ) ) << ( 4 - (i) ) )

#else

// ---- ZX / Mode 2: 1 bpp linear (8 px/byte) ---------------------------------
// Written as the 16-bit-window shift (256*val >> i) so the arithmetic is
// visibly a right shift; equals (val >> i) and (val << (8-i))&0xFF.
#define JSP_ROTTBL_IN(val,i)    ( ( ( 256 * (val) ) >> (i) ) / 256 )
#define JSP_ROTTBL_CARRY(val,i) ( ( ( 256 * (val) ) >> (i) ) % 256 )

#endif

#endif // _JSP_ROTTBL_FORMULA_H
