/**************************************************************/
/*
 *  Ensemble, 1.10
 *  Copyright 2001 Cornell University, Hebrew University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
/**************************************************************/
/* STATIC_STRING.C */
/* Author: Mark Hayden, 5/96 */
/**************************************************************/
#include "skt.h"
/**************************************************************/

#define White (0 << 8)		/* from byterun/gc.h */

/* From byterun/gc.h */
/* This depends on the layout of the header.  See [mlvalues.h]. */
#define Make_header(wosize, tag, color)                                       \
       ((header_t) (((header_t) (wosize) << 10)                               \
                    + (color)                                                 \
                    + (tag_t) (tag)))

value skt_static_string(value len_v) {       /* ML */
  value ret_v ;
  asize_t nbytes ;
  mlsize_t len ;
  mlsize_t wosize ;
  mlsize_t whsize ;
  mlsize_t offset_index;
  SKTTRACE ;

  /* From various */
  len = Int_val(len_v) ;
  wosize = (len + sizeof (value)) / sizeof (value);
  whsize = Whsize_wosize(wosize) ;
  offset_index = Bsize_wsize (wosize) - 1 ;

  /* From static_alloc */
  nbytes = whsize * sizeof (value) ;
  ret_v = Val_hp((header_t *) stat_alloc(nbytes)) ;

  /* From alloc_shr */
  Hd_val(ret_v) = Make_header(wosize, String_tag, White) ;

  /* From alloc_string */
  Field (ret_v, wosize - 1) = 0 ;
  Byte (ret_v, offset_index) = offset_index - len ;

  /* This checks that the memset below is correct.
   */
  assert(Bhsize_wosize(Wosize_val(ret_v)) == nbytes) ;
  return ret_v ;
}

/**************************************************************/

value skt_static_string_free(value s_v) {       /* ML */
  /* Check some things.
   */
  assert(Is_block(s_v)) ;
  assert(Tag_val(s_v) == String_tag) ;
  assert(!Is_young(s_v)) ;
  /*assert(Is_in_heap(s_v)) ;*/

  /* Then zero the memory.
   */
  memset(String_val(s_v),0,Bhsize_wosize(Wosize_val(s_v))) ;

  /* Finally free the object.
   */
  stat_free((char*)s_v) ;
  return Val_unit ;
}

/**************************************************************/

value skt_substring_eq(
        value s1_v,
	value ofs1_v,
	value s2_v,
	value ofs2_v,
	value len_v
) {
  long len ;
  long ret ;
  char *s1 ;
  char *s2 ;
  
  len = Long_val(len_v) ;
  s1 = ((char*)String_val(s1_v)) + Long_val(ofs1_v) ;
  s2 = ((char*)String_val(s2_v)) + Long_val(ofs2_v) ;
  ret = !memcmp(s1,s2,len) ;
  return Val_bool(ret) ;
}

/**************************************************************/
