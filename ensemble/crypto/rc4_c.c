/**************************************************************/
/*
 *  Ensemble, (Version 0.70p1)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
/**************************************************************/
/* rc4_C.ML */
/* Authors: Ohad Rodeh, 5/98 */
/**************************************************************/
#include "caml/mlvalues.h"
#include "rc4.h"
#include <stdio.h>

#include "rc4.c"

value 
rc4ml_context_length (
    ) {
    return Val_int(sizeof(rc4_key));
}

value 
rc4ml_Init(
	   value ctx_v,
	   value key_v,
	   value len_v
) {
    rc4_key *ctx;  
    unsigned char *key;
    int len;

    ctx = (rc4_key*) &Byte(ctx_v, 0) ;
    key = (char*) &Byte(key_v, 0) ;
    len = Int_val(len_v);

    RC4_create_key(key, len, ctx);
    return Val_unit ;
}

value 
rc4ml_Encrypt( 
		value ctx_v,
		value buf_v,
		value ofs_v,
		value len_v
) {
    rc4_key *ctx ;
    unsigned char *buf;
    unsigned int len ;

    ctx = (rc4_key*) &Byte(ctx_v, 0) ;
    buf = &Byte(buf_v,Long_val(ofs_v)) ;
    len = Long_val(len_v) ;

    RC4_encrypt(buf,len,ctx);
    return Val_unit;
}
	

