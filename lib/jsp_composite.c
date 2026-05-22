#include <stdint.h>

#include "jsp.h"

///////////////////////////////////////////////////////////
// Per-frame sprite compositing tables
//
// jsp_frame_sprites[] holds, for every active sprite, the constants the
// per-cell compositor needs.  It is filled once per frame by
// jsp_redraw_begin() — converted to assembly in Task 4.2, see
// lib/jsp_frame.asm.  The per-covered-cell compositor itself is
// lib/jsp_covered.asm (Task 3.3).  This file now only owns the storage.
///////////////////////////////////////////////////////////

struct jsp_sprite_frame jsp_frame_sprites[ JSP_SPRITE_REGISTRY_SIZE ];
uint8_t                 jsp_frame_count;
