#ifndef _JSP_ROTTBL_FORMULA_H
#define _JSP_ROTTBL_FORMULA_H

// Single source of truth for the Mode-2 (1bpp-linear) rotation-table entries,
// shared by lib/jsp_init.c (jsp_init_rottbl) and tests/cpc/shift_test_mode2.c
// so the production code and its unit test cannot drift apart.
//
// For shift phase i (1..7) and source byte val, a sprite byte shifted right by
// i pixels splits across a 16-bit window: the high half stays in this byte (the
// "in-byte" part), the low half spills into the next byte to the right (the
// "carry" part).  Written as the 16-bit-window shift (256*val >> i) so the
// arithmetic is visibly a right shift; equals (val >> i) and (val << (8-i))&0xFF
// respectively.
#define JSP_ROTTBL_IN(val,i)    ( ( ( 256 * (val) ) >> (i) ) / 256 )
#define JSP_ROTTBL_CARRY(val,i) ( ( ( 256 * (val) ) >> (i) ) % 256 )

#endif // _JSP_ROTTBL_FORMULA_H
