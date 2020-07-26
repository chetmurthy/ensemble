/**************************************************************/
/* MM_BASIC.C */
/* Author: Ohad Rodeh, 9/2001 */
/* The basic memory management functions. */
/**************************************************************/

#ifndef __MM_BASIC_H__
#define __MM_BASIC_H__

/* The type of user-space allocation and de-allocation functions. 
 */
typedef void* (*mm_alloc_t)(int);
typedef void  (*mm_free_t)(char*);

/* These functions can be set and reset.
 * They are static variables defined in mm.c
 */
extern mm_alloc_t mm_alloc_fun;
extern mm_free_t mm_free_fun;

void set_alloc_fun(mm_alloc_t f);
void set_free_fun(mm_free_t f);

#endif
