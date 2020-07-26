/**************************************************************/
/* IDEA_C.ML */
/* Authors: Ohad Rodeh, 3/2000 */
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

#include <openssl/idea.h>


value ideaml_context_length (
) {
  return Val_int(sizeof(IDEA_KEY_SCHEDULE));
}

value ideaml_iv_length (
) {
  return Val_int(8);
}

value ideaml_set_encrypt_key(
			     value str_v,
			     value idea_ks_v
			     ) {
  char* str = String_val(str_v);
  IDEA_KEY_SCHEDULE *idea_ks = (IDEA_KEY_SCHEDULE*) String_val(idea_ks_v);
  
  idea_set_encrypt_key(str,idea_ks);
  return Val_unit;
}

value ideaml_set_decrypt_key(
			     value str_v,
			     value idea_ks_dec_v) {
  char* str = String_val(str_v);
  IDEA_KEY_SCHEDULE *idea_ks_dec =
    (IDEA_KEY_SCHEDULE*) String_val(idea_ks_dec_v);
  IDEA_KEY_SCHEDULE idea_ks ;

  idea_set_encrypt_key(str,&idea_ks);
  idea_set_decrypt_key(&idea_ks,idea_ks_dec);
  return Val_unit;
}

value ideaml_set_iv(
		    value iv_v
		    ) {
  char *iv = String_val(iv_v);

  memset(iv,0,8);
  return Val_unit;
}


value ideaml_cbc_encrypt_native(
		       value idea_ks_v,
		       value iv_v,
		       value sbuf_v,
		       value sofs_v,
		       value dbuf_v,
		       value dofs_v,
		       value len_v, 
		       value encrypt_v){
  char *sbuf = &Byte(sbuf_v, Long_val(sofs_v));
  char *dbuf = &Byte(dbuf_v, Long_val(dofs_v));
  long  len  = Long_val(len_v);
  IDEA_KEY_SCHEDULE *idea_ks = (IDEA_KEY_SCHEDULE*) idea_ks_v;
  char *iv   = String_val(iv_v);
  int  encrypt = Bool_val(encrypt_v);
  
  idea_cbc_encrypt(sbuf,dbuf,len,idea_ks,iv,encrypt);
  return Val_unit;
}


value ideaml_cbc_encrypt_bytecode(
        value *argv,
	int argn
) {
    return ideaml_cbc_encrypt_native(argv[0], argv[1], argv[2], argv[3],
                                argv[4], argv[5], argv[6], argv[7]);
}

