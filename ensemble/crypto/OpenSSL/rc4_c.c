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
/* RC4.ML */
/* Authors: Ohad Rodeh, 4/2000 */
/**************************************************************/
/* Caml stuff
 */
#include "caml/config.h"
#include "caml/mlvalues.h"
#include "caml/misc.h"
#include "caml/alloc.h"
#include "caml/memory.h"


#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <openssl/crypto.h>
#include <openssl/rc4.h>

#include "mm.h"

value rc4ml_context_length (
) {
  return Val_int(sizeof(RC4_KEY));
}

value rc4ml_set_key(
		    value str_v,
		    value len_v,
		    value ctx_v
		    ){
  char *str = String_val(str_v);
  int  len = Int_val(len_v);
  RC4_KEY *rc4_ks =  (RC4_KEY*)&Byte(ctx_v,0);
  
  RC4_set_key(rc4_ks,len,str);
  return Val_unit;
}
		    

value rc4ml_encrypt_native (
		       value rc4_ks_v,
		       value sbuf_v,
		       value sofs_v,
		       value dbuf_v,
		       value dofs_v,
		       value len_v) {
  char *sbuf = &Byte(sbuf_v, Long_val(sofs_v));
  char *dbuf = &Byte(dbuf_v, Long_val(dofs_v));
  long  len  = Long_val(len_v);
  RC4_KEY *rc4_ks = (RC4_KEY*) rc4_ks_v;
  
  RC4(rc4_ks,len,sbuf,dbuf);
  return Val_unit;
}


value rc4ml_encrypt_bytecode(
        value *argv,
	int argn
) {
    return rc4ml_encrypt_native(argv[0], argv[1], argv[2], argv[3],
                                argv[4], argv[5]);
}

value rc4ml_encrypt_iov(
			value ctx_v,
			value iov_v
){
  RC4_KEY *rc4_ks = (RC4_KEY*) ctx_v;
  int len = Int_val(Field(iov_v,0));
  char *buf = mm_Cbuf_val(Field(iov_v,1));
  
  RC4(rc4_ks,len,buf,buf);
  return Val_unit;
}

