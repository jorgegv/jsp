#include <stdint.h>

#include "jsp.h"

///////////////////////////////////////////////////////////
// P1-5: Dynamic sprite pool allocation
///////////////////////////////////////////////////////////

static struct jsp_sprite_s  *_pool;
static uint8_t              *_pdbs;
static uint8_t               _pool_size;
static uint8_t               _max_rows;
static uint8_t               _max_cols;
static uint8_t               _pdb_stride;   // bytes per slot: (max_rows+1)*(max_cols+1)*8

// Register the caller-supplied storage for the sprite pool.
// Must be called once before any jsp_sprite_alloc.
void jsp_sprite_pool_init( struct jsp_sprite_s *pool, uint8_t *pdbs,
                           uint8_t pool_size,
                           uint8_t max_rows, uint8_t max_cols ) {
    uint8_t i;
    _pool      = pool;
    _pdbs      = pdbs;
    _pool_size = pool_size;
    _max_rows  = max_rows;
    _max_cols  = max_cols;
    _pdb_stride = (uint8_t)( (uint16_t)(max_rows + 1) * (max_cols + 1) * 8 );

    // Mark all slots as free (initialized = 0)
    for ( i = 0; i < pool_size; i++ )
        _pool[i].flags.initialized = 0;
}

// Claim a sprite slot from the pool.
// Initialises rows, cols, pdbuf, type_ptr, flags, color, color_mask.
// Returns NULL if the pool is exhausted.
struct jsp_sprite_s *jsp_sprite_alloc( uint8_t rows, uint8_t cols ) {
    uint8_t i;
    struct jsp_sprite_s *sp;

    for ( i = 0; i < _pool_size; i++ ) {
        if ( !_pool[i].flags.initialized ) {
            sp = &_pool[i];
            sp->rows             = rows;
            sp->cols             = cols;
            sp->xpos             = 0;
            sp->ypos             = 0;
            sp->flags.initialized = 1;
            sp->flags.parked     = 0;
            sp->pixels           = 0;
            sp->pdbuf            = _pdbs + (uint16_t)i * _pdb_stride;
            sp->type_ptr         = JSP_TYPE_MASK2;
            sp->color            = 0;
            sp->color_mask       = 0;
            return sp;
        }
    }
    return 0;
}

// Return a sprite slot to the pool.
void jsp_sprite_free( struct jsp_sprite_s *sp ) {
    sp->flags.initialized = 0;
}
