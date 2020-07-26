/**************************************************************/
/* MM.C */
/* Author: Ohad Rodeh, 9/2001 */
/* The basic memory management functions. Used to manage user allocated */
/* buffer in C layout. */
/**************************************************************/
/* Instead of raising exceptions upon malloc failure, we return
 * empty iovecs.
 *
 * 
 */
/**************************************************************/
#include "skt.h"
/**************************************************************/
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
/**************************************************************/

value mm_Val_cbuf (char *buf) {
  CAMLparam0();
  CAMLlocal1(cbuf_v);

  cbuf_v = alloc_small(1,Abstract_tag);
  Field(cbuf_v,0) = (value) buf;

  CAMLreturn(cbuf_v);
}

char *mm_Cbuf_val(value cbuf_v){
  return (char*) Field(cbuf_v,0);
}


value mm_cbuf_free(value cbuf_v){
  mm_free_fun(mm_Cbuf_val(cbuf_v));
  return Val_unit;
}

/**************************************************************/
value mm_Raw_of_len_buf(int len, char *buf){
  CAMLparam0();
  CAMLlocal2(iov_v,cbuf_v);

  SKTTRACE(("mm_Raw_of_len_buf\n"));
  cbuf_v = mm_Val_cbuf(buf);
  iov_v = alloc_small(2,0);
  Field(iov_v,0) = Val_int(len);
  Field(iov_v,1) = cbuf_v;

  CAMLreturn(iov_v);
}

/* An empty iovec.
 * Register it so that the Caml GC will be aware of it. 
 */
value empty_iovec = (value) NULL;

/* Initialize the empty iovec. The initialization function is called
 * by ssocket.
 */
value mm_empty (){
  CAMLparam0();
  if (empty_iovec == (value) NULL) {
    SKTTRACE(("mm_empty: setting mm_empty(\n"));
    empty_iovec =  mm_Raw_of_len_buf(0,NULL);
    SKTTRACE((".\n"));
    register_global_root(&empty_iovec);
    SKTTRACE((")\n"));
  }
  CAMLreturn(empty_iovec);
}

value mm_Val_raw (ce_iovec_t *iov){
  CAMLparam0();
  CAMLlocal2(cbuf_v, iov_v);

  SKTTRACE(("mm_Val_raw\n"));
  cbuf_v = mm_Val_cbuf(Iov_buf(*iov));
  iov_v = alloc_small(2,0);
  Field(iov_v,0) = Val_int(Iov_len(*iov));
  Field(iov_v,1) = cbuf_v;

  CAMLreturn(iov_v);
}

value mm_copy_raw_into_string(value iov_v, value buf_v, value ofs_v){
  int len;
  char *cbuf;

  SKTTRACE(("mm_copy_raw_into_string"));
  len = Int_val(Field(iov_v,0));
  cbuf = mm_Cbuf_val(Field(iov_v,1));
  memcpy(String_val(buf_v) + Int_val(ofs_v), cbuf, len);
  
  return Val_unit;
}

value mm_copy_string_into_raw(value str_v, value ofs_v, value len_v, value iov_v){
  char *dst;
  
  SKTTRACE(("mm_copy_string_into_raw\n"));
  dst = mm_Cbuf_val(Field(iov_v,1));
  memcpy(dst, (char*)String_val(str_v) + Int_val(ofs_v), Int_val(len_v));

  return Val_unit;
}

value mm_copy_raw_into_raw(value iov_src_v, value iov_dst_v){
  int len;
  char *dst, *src;
  
  SKTTRACE(("mm_copy_raw_into_raw\n"));
  len = Int_val(Field(iov_src_v,0));
  assert(len!=0);
  src = mm_Cbuf_val(Field(iov_src_v,1));
  dst = mm_Cbuf_val(Field(iov_dst_v,1));
  memcpy(dst, src, len);

  return Val_unit;
}

/* Here, we assume that [ofs] is indeed inside the iovec.
 */
value mm_cbuf_sub(value iov_v, value ofs_v){
  char *cbuf;
  CAMLparam2(iov_v, ofs_v);
  CAMLlocal1(cbuf_new_v);

  SKTTRACE(("mm_sub: "));
  cbuf = mm_Cbuf_val(Field(iov_v,1));
  cbuf_new_v = mm_Val_cbuf((char*) cbuf + Int_val(ofs_v));

  CAMLreturn(cbuf_new_v);
}

/* Flatten an array of iovectors. 
 * A iovec of the correct size is preallocated, and given by the
 * ML side. 
 */
value mm_flatten(value iova_v, value iov_v){
  int len, i, n, ofs;
  char *dst, *src;

  SKTTRACE(("mm_flatten: "));
  n = Wosize_val(iova_v);
  dst= mm_Cbuf_val(Field(iov_v,1));
  
  for (i=0, ofs=0; i<n; i++){
    len = Int_val(Field(Field(iova_v,i),0));
    src = mm_Cbuf_val(Field(Field(iova_v,i),1));
    memcpy((char*)dst + ofs, src, len);
    ofs += len;
  }
  
  return Val_unit;
}

/**************************************************************/
/* Allocate an iovec
 */

value mm_alloc(value len_v){
  int len;
  char *buf;
  CAMLparam1(len_v);
  CAMLlocal2(iov_v, cbuf_v);
  
  SKTTRACE(("mm_alloc("));
  len = Int_val(len_v);
  buf = (char*) mm_alloc_fun(len);

  if (len>0 && buf == NULL)
    raise_out_of_memory ();    
  
  cbuf_v = mm_Val_cbuf(buf);
  iov_v = alloc_small(2,0);
  Field(iov_v,0) = len_v;
  Field(iov_v,1) = cbuf_v;

  SKTTRACE((")\n"));
  CAMLreturn(iov_v);
}

/**************************************************************/
