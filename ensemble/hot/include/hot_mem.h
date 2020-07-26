/**************************************************************/
/*
 *  Ensemble, (Version 0.70p1)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
#ifndef __HOT_MEM_H__
#define __HOT_MEM_H__
 
typedef struct hot_mem* hot_mem_t;

//#define HOT_MEM_CHANNELS

void* hot_mem_Alloc(hot_mem_t ch, unsigned size);
void* hot_mem_Realloc(void *mem, unsigned size);
void hot_mem_Free(void *mem);
hot_mem_t hot_mem_AddChannel(const char *name);

#endif /*__HOT_MEM_H__*/
