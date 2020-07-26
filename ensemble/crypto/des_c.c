/**************************************************************/
/*
 *  Ensemble, (Version 0.70p1)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
#include <stdio.h>
#include "caml/mlvalues.h"
#define PROTO_LIST(x) x
#include "des.h"

value desml_context_length(void) {
  return Val_int(sizeof(DES_CBC_CTX)) ;
}

value desml_CBCInit(
        value ctx_v,
	value key_v,
	value vi_v,
	value encrypt_v
) {
  DES_CBC_CTX *ctx ;
  unsigned char *key, *vi ;
  int encrypt ;

  ctx = (DES_CBC_CTX*) &Byte(ctx_v, 0) ;
  key = &Byte(key_v, 0) ;
  vi = &Byte(vi_v, 0) ;
  encrypt = Bool_val(encrypt_v) ;
  
  DES_CBCInit(ctx,key,vi,encrypt) ;
  return Val_unit ;
}

value desml_CBCUpdate_native( 
        value ctx_v,
	value sbuf_v,
	value sofs_v,
	value dbuf_v,
	value dofs_v,
	value len_v
) {
  DES_CBC_CTX *ctx ;
  unsigned char *src, *dst ;
  unsigned int len ;
  int ret ;

  ctx = (DES_CBC_CTX*) &Byte(ctx_v, 0) ;
  src = &Byte(sbuf_v,Long_val(sofs_v)) ;
  dst = &Byte(dbuf_v,Long_val(dofs_v)) ;
  len = Long_val(len_v) ;
  ret = DES_CBCUpdate(ctx,dst,src,len) ;
  return Val_int(ret) ;
}
	
value desml_CBCUpdate_bytecode(
        value *argv,
	int argn
) {
  return desml_CBCUpdate_native(argv[0], argv[1], argv[2], argv[3],
                                argv[4], argv[5]);
}
