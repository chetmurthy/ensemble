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
/* IDEA_C.ML */
/* Authors: Ohad Rodeh, 11/97 */
/**************************************************************/
#include <stdio.h>
#include "caml/mlvalues.h"
#include "idea.h"

value ideaml_context_length(void) {
  return Val_int(sizeof(struct IdeaCfbContext)) ;
}

value ideaml_CfbInit(
        value ctx_v,
	value key_v
) {
    struct IdeaCfbContext *ctx;  
    unsigned char *key;

    ctx = (struct IdeaCfbContext*) &Byte(ctx_v, 0) ;
    key = &Byte(key_v, 0) ;

    ideaCfbInit(ctx, key); 
    return Val_unit ;
}

value ideaml_CfbUpdate_native( 
        value ctx_v,
	value sbuf_v,
	value sofs_v,
	value dbuf_v,
	value dofs_v,
	value len_v,
	value encrypt_v
) {
    struct IdeaCfbContext *ctx ;
    unsigned char *src, *dst ;
    unsigned int len ;
    int encrypt ;

    ctx = (struct IdeaCfbContext*) &Byte(ctx_v, 0) ;
    src = &Byte(sbuf_v,Long_val(sofs_v)) ;
    dst = &Byte(dbuf_v,Long_val(dofs_v)) ;
    len = Long_val(len_v) ;
    encrypt = Bool_val(encrypt_v);
    if (encrypt) 
	ideaCfbEncrypt(ctx,src,dst,len);
    else 
	ideaCfbDecrypt(ctx,src,dst,len);

    return Val_int(0);
}
	
value ideaml_CfbUpdate_bytecode(
        value *argv,
	int argn
) {
    return ideaml_CfbUpdate_native(argv[0], argv[1], argv[2], argv[3],
                                argv[4], argv[5], argv[6]);
}
