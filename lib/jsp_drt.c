#include <stdint.h>

#include "jsp.h"

void jsp_drt_restore_bg( uint8_t row, uint8_t col ) __smallc __z88dk_callee {
    jsp_drt[ row * 32 + col ] = jsp_btt[ row * 32 + col ];
}
