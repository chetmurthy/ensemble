/**************************************************************/
/* DES.ML */
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

#include <openssl/des.h>

value desml_context_length (
){
  return Val_int(sizeof(des_key_schedule));
}

value desml_iv_length (
		  ){
  return Val_int(sizeof(des_cblock));
}
     

/* Some silly pointer tricks are used here to convince the
 * C compiler that sch_v is infact a pointer to a "des_key_schedule".
 */
value desml_set_encrypt_key(
		    value str_v,
		    value sch_v
		    ){
  char *str = String_val(str_v);
  struct des_ks_struct *sch = (struct des_ks_struct*)sch_v;

  des_set_key((des_cblock*)str,sch);
  return Val_unit;
}  

value desml_set_iv(
		   value iv_v
		   ){
  unsigned char *iv = (unsigned char*) String_val(iv_v);
  memset(iv,0,sizeof(des_cblock));
  return Val_unit;
}

value desml_ncbc_encrypt_native(
		       value sch_v,
		       value iv_v,
		       value sbuf_v,
		       value sofs_v,
		       value dbuf_v,
		       value dofs_v,
		       value len_v,
		       value encrypt_v
		       ){
  char *sbuf = &Byte(sbuf_v, Long_val(sofs_v));
  char *dbuf = &Byte(dbuf_v, Long_val(dofs_v));
  long  len  = Long_val(len_v);
  struct des_ks_struct *sch = (struct des_ks_struct*) sch_v;
  des_cblock *iv = (unsigned char*) &Byte(iv_v,0);
  int  encrypt = Bool_val(encrypt_v);
  
  des_ncbc_encrypt(sbuf,dbuf,len,sch,iv,encrypt);
  return Val_unit;
}

value desml_ncbc_encrypt_bytecode(
        value *argv,
	int argn
) {
    return desml_ncbc_encrypt_native(argv[0], argv[1], argv[2], argv[3],
                                argv[4], argv[5], argv[6], argv[7]);
}
