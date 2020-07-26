/**************************************************************/
/* MM_BASIC.C */
/* Author: Ohad Rodeh, 9/2001 */
/* The basic memory management functions. */
/**************************************************************/
#include "mm_basic.h"
#include <malloc.h>
#include <stdio.h>
void* user_malloc(int size){
  if (size>0) return (malloc(size));
  else return NULL;
}

void user_free(char *buf){
  if (buf != NULL)
    free(buf);
}

mm_alloc_t mm_alloc_fun = user_malloc ;
mm_free_t mm_free_fun = user_free ;

void set_alloc_fun(mm_alloc_t f){
  mm_alloc_fun = f;
}

void set_free_fun(mm_free_t f){
  mm_free_fun = f;
}
