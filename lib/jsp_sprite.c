#include <stdint.h>

#include "jsp.h"

void jsp_init_sprite( struct jsp_sprite_s *sp, uint8_t *pixels ) __smallc __z88dk_callee {
    sp->pixels = pixels;
    sp->xpos = sp-> ypos = 255;
    sp->flags.initialized = 1;
}

void jsp_draw_sprite( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) __smallc __z88dk_callee {
}

void jsp_move_sprite( struct jsp_sprite_s *sp, uint8_t xpos, uint8_t ypos ) __smallc __z88dk_callee {
}
