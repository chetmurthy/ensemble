/**************************************************************/
/*
 *  Ensemble, 1_42
 *  Copyright 2003 Cornell University, Hebrew University
 *           IBM Israel Science and Technology
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
/**************************************************************/
/* MM.H */
/* Author: Ohad Rodeh 9/2001 */
/**************************************************************/

#ifndef __MM_H__
#define __MM_H__

#include "mm_basic.h"

value mm_Raw_of_len_buf(int, char*);
char *mm_Cbuf_val(value);

/* An empty iovec.
 */
value mm_empty(void);

/* Marshaling/unmarshaling from/to C buffers
 */
value mm_output_val(value obj_v, value iov_v, value flags_v);
value mm_input_val(value iov_v);

#endif

