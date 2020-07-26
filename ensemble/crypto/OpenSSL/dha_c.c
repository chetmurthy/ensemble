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
/* DHA_C.C */
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
#ifdef WINDOWS
#include "../bio/bss_file.c" 
#endif
#include <openssl/crypto.h>
#include <openssl/bio.h>
#include <openssl/bn.h>

#define VERBOSE 0
#include <stdarg.h>

static void trace(const char *s, ...) {
#if VERBOSE==1
  va_list args;

  va_start(args, s);

  vfprintf(stderr, s, args);
  va_end(args);
  fflush(stdout);
#endif
}

//#define C_CHECK

#ifdef NO_DH
value dhml_DH_Init(void) {
  invalid_argument("NO_DH is defined");
}

value dhml_DH_generate_parameters(value key_len_v) {
  invalid_argument("NO_DH is defined");
}

value dhml_DH_copy_params(value key_v) {
  invalid_argument("NO_DH is defined");
}

value dhml_DH_generate_key(value key_v) {
  invalid_argument("NO_DH is defined");
}

value dhml_DH_size(value key_v){
  invalid_argument("NO_DH is defined");
}
  
value dhml_DH_get_p (value key_v){
  invalid_argument("NO_DH is defined");
}


value dhml_DH_get_g (value key_v){
  invalid_argument("NO_DH is defined");
}

value dhml_DH_get_pub_key (value key_v){
  invalid_argument("NO_DH is defined");
}
  
value dhml_DH_get_prv_key (value key_v){
  invalid_argument("NO_DH is defined");
} 

value dhml_DH_compute_key(value key_a_v,value pub_key_b_v,value str_v){
  invalid_argument("NO_DH is defined");
}
 
value dhml_BN_size(value bignum_v) {
  invalid_argument("NO_DH is defined");
}

value dhml_BN_bn2bin (value pub_key_v,value str_v){
  invalid_argument("NO_DH is defined");
}

value dhml_BN_bin2bn (value str_v){
  invalid_argument("NO_DH is defined");
}
#else
#include <openssl/dh.h>
 
#ifdef WIN16
#define MS_CALLBACK	_far _loadds
#else
#define MS_CALLBACK
#endif

static void MS_CALLBACK cb(int p, int n, void *arg);
#ifdef NO_STDIO
#define APPS_WIN16
#include "bss_file.c"
#endif


BIO *out=NULL;

static const char rnd_seed[] =
"string to make the random number generator think it has entropy";


#ifndef C_CHECK
/**************************************************************/
/* Routines for safely using the DH struture.
 */

inline DH* DH_val(value a_v) {
  return (DH*) Field(a_v,1) ;
}


void dhml_DH_free(value a_v){
  DH *a = DH_val(a_v);

  trace ("DH_free["); 
  if (a == NULL) return;
  DH_free(a);
  trace ("] "); 
  return;
}


value Val_DH(DH* a) {
  /*  CAMLparam0();
  CAMLlocal1(a_v);
  
  a_v = alloc_final(2, dhml_DH_free, 1, 10) ; 
  Store_field(a_v, 1, (value) a) ; 
  CAMLreturn a_v; 
  */
  
  value a_v;
  
  a_v = alloc_final(2, dhml_DH_free, 1, 10) ; 
  Field(a_v, 1) =  (value) a ; 
  return a_v;
}


inline BIGNUM* BN_val(value bn_v) {
  return (BIGNUM*) Field(bn_v,1);
}

void dhml_BN_free(value bn_v){
  BIGNUM *bn = BN_val(bn_v);

  trace("BN_free[");
  if (bn == NULL) return;
  BN_free(bn);
  trace ("] "); 
  return;
}


/* Why doesn't the first version work? 
 */
value Val_BN(BIGNUM* bn) {
  /*  
  CAMLparam0();
  CAMLlocal1(bn_v);

  trace ("Val_BN[");
  bn_v = alloc_final(2, dhml_BN_free, 1, 10) ; 
  Store_field(bn_v, 1, (value) bn) ; 
  trace ("]");
  CAMLreturn bn_v;
  */

  value bn_v;
  
  bn_v = alloc_final(2, dhml_BN_free, 1, 10) ; 
  Field(bn_v, 1) =  (value) bn ; 
  return bn_v;
}

/**************************************************************/


value dhml_DH_Init(void) {
#ifdef WIN32
  CRYPTO_malloc_init();
#endif
  out=BIO_new(BIO_s_file());
  if (out == NULL) exit(1);
  BIO_set_fp(out,stdout,BIO_NOCLOSE);

  RAND_seed(rnd_seed, sizeof rnd_seed);
  return Val_unit;
}

value dhml_DH_generate_parameters(
				  value key_len_v
				  ){
  int key_len = Int_val(key_len_v);
  DH *a;
  
  trace("key_len=%d\n", key_len); 
  a=DH_generate_parameters(key_len,DH_GENERATOR_5,cb,(char*)out);
  trace("] "); 
  return Val_DH(a);
}


value dhml_DH_copy_params(
			  value key_v
			  ) {
  DH *a,*b;

  a = DH_val(key_v);
  
  b=DH_new();
  if (b == NULL) failwith("malloc failed"); 
  
  b->p=BN_dup(a->p);
  b->g=BN_dup(a->g);
  if ((b->p == NULL) || (b->g == NULL)) failwith("malloc failed");

  return Val_DH(b);
}


value dhml_DH_generate_key(
			   value key_v
			   ) {
  DH *a;

  a = DH_val(key_v);
  if (!DH_generate_key(a)) failwith("generate key failed");
  return Val_unit;
}


value dhml_DH_size(
		   value key_v
		   ){
  DH *a = DH_val (key_v);

  if (a == NULL) failwith ("Null key pointer");
  return Val_int (DH_size(a));
}

value dhml_DH_get_p (
		     value key_v
		     ){
  DH *a = DH_val (key_v);
  BIGNUM *p;
  
  if (a == NULL) failwith ("Null key pointer");
  p = BN_dup(a->p);
  return Val_BN(p);
}


value dhml_DH_get_g (
		     value key_v
		     ){
  DH *a = DH_val(key_v);
  BIGNUM *g;

  if (a == NULL) failwith ("Null key pointer");
  g = BN_dup(a->g);
  return Val_BN(g);
}


value dhml_DH_get_pub_key (
			   value key_v
			   ){
  DH *a = DH_val(key_v);
  BIGNUM *pub;

  if (a == NULL) failwith ("Null key pointer");
  pub = BN_dup(a->pub_key);
  return Val_BN(pub);
}


value dhml_DH_get_prv_key (
			   value key_v
			   ){
  DH *a = DH_val(key_v);
  BIGNUM *prv;

  if (a == NULL) failwith ("Null key pointer");
  prv = BN_dup(a->priv_key);
  return Val_BN(prv);
}


value dhml_DH_compute_key(
			  value key_a_v,
			  value pub_key_b_v,
			  value str_v
			  ){
  int aout;
  DH *a = DH_val(key_a_v);
  BIGNUM *pub_b = BN_val(pub_key_b_v);
  unsigned char *abuf = (unsigned char*) String_val(str_v);

  if (a == NULL) failwith ("Null key pointer");
  trace ("[compute_key"); 
  aout=DH_compute_key(abuf,pub_b,a);
  trace("]");
  if (aout < 4) failwith ("Failure in DH routines.");
  return Val_unit;
}

value dhml_d2i_DHparams(
			value str_v,
			value len_v
			){
  unsigned char *p = (unsigned char*) String_val (str_v);
  long len = Long_val(len_v);
  DH *a ;

  trace ("d2i=%d [", len);
  a = d2i_DHparams(NULL,&p,len);
  if (a == NULL) failwith("Null return value in DH routines.");
  trace ("] "); 
  return Val_DH(a); 
}

/* Need to get the length of the buffer to be allocated in
 * advance.
 *
 * It seems that there is a bug in the OpenSSL interface. If
 * one uses NULL in i2d_DHparams(a,NULL), then there is
 * an inner allocation that isn't freed.
 */

value dhml_i2d_DHparams(
			value key_v
			){
  CAMLparam1(key_v);
  CAMLlocal1(s_v);
  DH *a = DH_val(key_v);
  int len = 0;
  unsigned char *q,*p;
  
  trace("i2d=");
  p = malloc(200);
  q=p;
  len = i2d_DHparams(a,&p);
  trace("%d [",len);
  s_v = alloc_string(len);
  memcpy(String_val(s_v), q, len);
  free(q);
  trace ("] ");
  CAMLreturn(s_v);
}     


value dhml_BN_size(
		   value bn_v
		   ) {
  BIGNUM *a = BN_val(bn_v);

  trace ("dhml_BN_size");
  return Val_int (BN_num_bytes(a));
}

value dhml_BN_bn2bin (
		      value bn_v,
		      value str_v
		      ){
  BIGNUM *bn = BN_val(bn_v);
  unsigned char *str = (unsigned char*) String_val(str_v);

  trace ("dhml_BN_bn2bin");
  BN_bn2bin(bn,str);
  return Val_unit;
}
     
value dhml_BN_bin2bn (
		      value str_v
		      ){
  char *str = (char*) String_val(str_v);
  int len = string_length(str_v);
  BIGNUM *bn;


  /* Allocation occurs inside bn_lib
   */

  trace("%d [",len);
  bn = BN_bin2bn(str,len,NULL);
  trace("]");
  return Val_BN(bn);
}
#endif /*C_CHECK*/



static void MS_CALLBACK cb(int p, int n, void *arg)
	{
	char c='*';

	if (p == 0) c='.';
	if (p == 1) c='+';
	if (p == 2) c='*';
	if (p == 3) c='\n';
	BIO_write((BIO *)arg,&c,1);
	BIO_flush((BIO *)arg);
#ifdef LINT
	p=n;
#endif
	}
#endif

/*****************************************************************************/
/* For dubugging purposes
 */
#ifdef C_CHECK

int main() {
  DH *a;
  int key_len = 128;
  
  /* Initialization
   */
#ifdef WIN32
  CRYPTO_malloc_init();
#endif
  
  out=BIO_new(BIO_s_file());
  if (out == NULL) exit(1);
  BIO_set_fp(out,stdout,BIO_NOCLOSE);
  RAND_seed(rnd_seed, sizeof rnd_seed);
  
  
  a=DH_generate_parameters(key_len,DH_GENERATOR_5,cb,(char*)out);
  
  if (a==NULL) {
    printf ("Failed to generate_parameters\n");
    exit(0);
  }
  BIO_puts(out,"\np    =");
  BN_print(out,a->p);
  BIO_puts(out,"\ng    =");
  BN_print(out,a->g);
  BIO_puts(out,"\n");
}
#endif /*C_CHECK*/
/*****************************************************************************/

