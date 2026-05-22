#include <stdint.h>

#include "jsp.h"

///////////////////////////////////////////////////////////
// Dynamic sprite pool allocation
//
// The recompositing model needs no per-sprite drawing buffer, so the
// pool is simply caller-supplied storage for jsp_sprite_s descriptors.
///////////////////////////////////////////////////////////

static struct jsp_sprite_s  *_pool;
static uint8_t               _pool_size;

// Register the caller-supplied storage for the sprite pool.
// Must be called once before any jsp_sprite_alloc.
void jsp_sprite_pool_init( struct jsp_sprite_s *pool, uint8_t pool_size ) {
    uint8_t i;
    _pool      = pool;
    _pool_size = pool_size;

    // Mark all slots as free (initialized = 0)
    for ( i = 0; i < pool_size; i++ )
        _pool[i].flags.initialized = 0;
}

// Claim a sprite slot from the pool.
// Returns NULL if the pool is exhausted.
struct jsp_sprite_s *jsp_sprite_alloc( uint8_t rows, uint8_t cols ) {
    uint8_t i;
    struct jsp_sprite_s *sp;

    for ( i = 0; i < _pool_size; i++ ) {
        if ( !_pool[i].flags.initialized ) {
            sp = &_pool[i];
            sp->rows              = rows;
            sp->cols              = cols;
            sp->xpos              = 0;
            sp->ypos              = 0;
            sp->flags.initialized = 1;
            sp->flags.active      = 0;
            sp->flags.registered  = 0;
            sp->pixels            = 0;
            sp->type_ptr          = JSP_TYPE_MASK2;
            sp->color             = 0;
            sp->color_mask        = 0;
            sp->clip              = 0;
            return sp;
        }
    }
    return 0;
}

// Return a sprite slot to the pool.
void jsp_sprite_free( struct jsp_sprite_s *sp ) __z88dk_fastcall {
    jsp_unregister_sprite( sp );
    sp->flags.initialized = 0;
    sp->flags.active      = 0;
}
