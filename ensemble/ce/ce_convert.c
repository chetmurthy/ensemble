/**************************************************************/
/* CE_CONVERT.C */
/* Author: Ohad Rodeh  8/2001 */
/* Conversion of ML <-> C data-structures */
/**************************************************************/
#include "ce_internal.h"
#include "ce_trace.h"
#include <stdio.h>
#include <assert.h>
/**************************************************************/
#define NAME "CE_CONVERT"
/**************************************************************/
#define MAX(x,y) ((x > y) ? x : y)

value
Val_string_opt(char *s){
  value s_v;

  if (s==NULL)
    s_v = alloc_string(0);
  else
    s_v = copy_string(s);

  return s_v;
}


/*
 *  The call to alloc_string should be replaced with a call to ce_alloc_space. 
 */
value
Val_iovl(int num, ce_iovec_array_t iovl){
  int i;
  CAMLparam0();
  CAMLlocal2(msg_v, ret_v);

  if (num==0)
    ret_v = Atom(0);
  else {
    ret_v = alloc(num,0);
    for(i=0; i<num; i++) {
      msg_v = mm_Raw_of_len_buf(Iov_len(iovl[i]), Iov_buf(iovl[i]));
      modify(&Field(ret_v,i), msg_v);
    }
  }
  
  CAMLreturn(ret_v);  
}

/* We cache a local iovl. The user MAY NOT free it. 
 */
static ce_iovec_array_t iovl = NULL;
static iovl_len = 0;

ce_iovec_array_t Iovl_val(value iovl_v){
  int i;
  int num = Wosize_val(iovl_v);
  value iov_v;

  if (num == 0) return NULL;
  if (num > iovl_len){
    free(iovl);
    iovl_len = MAX(2*iovl_len, num);
    iovl = (ce_iovec_array_t) ce_malloc(iovl_len * sizeof(ce_iovec_t));
  }
  
  for (i=0; i<num; i++){
    iov_v = Field(iovl_v,i);
    Iov_len(iovl[i]) = Int_val(Field(iov_v,0));
    Iov_buf(iovl[i]) = (char*) mm_Cbuf_val(Field(iov_v,1));
  }

  return iovl;
}

char*
String_copy_val(value s_v){
  int len;
  char* s;

  len = string_length(s_v);
  s = (char*) ce_malloc(len+1);
  memcpy(s, &Byte(s_v,0),len);
  s[len] = '\0';

  return(s);
}

/**************************************************************/

ce_endpt_array_t
String_array_val(value sa_v, int n){
  int i;
  char **sa;
  
  sa = (char**) ce_malloc((n+1) * sizeof(ce_endpt_t*));
  for (i=0; i< n; i++)
    sa[i] = (char*) String_copy_val(Field(sa_v, i));
  sa[n] = NULL;
  
  return(sa);
}

ce_view_id_t*
View_id_val(value id_v){
  ce_view_id_t *id ;

  id = record_create(ce_view_id_t*, id);
  id->ltime = Int_val(Field(id_v,0));
  id->endpt = String_copy_val(Field(id_v,1));

  return id;
}

ce_view_id_array_t
View_id_array_val(value view_id_array_v, int num){
  int i;
  ce_view_id_array_t va;

  va = (ce_view_id_array_t) ce_malloc((num+1) * sizeof(ce_view_id_t*));
  for (i=0; i<num; i++) 
    va[i] = View_id_val(Field(view_id_array_v,i));
  va[num] = NULL;
  
  return va;
}

/**************************************************************/

enum ce_view_state_enum {
  CE_VIEW_STATE_VERSION,
  CE_VIEW_STATE_GROUP,
  CE_VIEW_STATE_PROTO,
  CE_VIEW_STATE_COORD,
  CE_VIEW_STATE_LTIME,
  CE_VIEW_STATE_PRIMARY,
  CE_VIEW_STATE_GROUPD,
  CE_VIEW_STATE_XFER_VIEW,
  CE_VIEW_STATE_KEY,
  CE_VIEW_STATE_NUM_IDS,
  CE_VIEW_STATE_PREV_IDS,
  CE_VIEW_STATE_PARAMS,
  CE_VIEW_STATE_UPTIME,
  CE_VIEW_STATE_VIEW,
  CE_VIEW_STATE_ADDRESS
};




/* Convert a value into a view state.
 * We also need to know the number of members in the
 * view. 
 */
void
ViewState_of_val(value vs_v, int nmembers, ce_view_state_t *vs) {
  TRACE("ViewState_of_val(");
  vs->version   = String_copy_val(Field(vs_v, CE_VIEW_STATE_VERSION));
  vs->group     = String_copy_val(Field(vs_v, CE_VIEW_STATE_GROUP));
  vs->coord     = Int_val(Field(vs_v, CE_VIEW_STATE_COORD));
  vs->ltime     = Int_val(Field(vs_v, CE_VIEW_STATE_LTIME));
  vs->primary   = Bool_val(Field(vs_v, CE_VIEW_STATE_PRIMARY));
  vs->proto     = String_copy_val(Field(vs_v, CE_VIEW_STATE_PROTO));
  vs->groupd    = Bool_val(Field(vs_v, CE_VIEW_STATE_GROUPD));
  vs->xfer_view = Bool_val(Field(vs_v, CE_VIEW_STATE_XFER_VIEW));
  vs->key       = String_copy_val(Field(vs_v, CE_VIEW_STATE_KEY));
  TRACE(".");
  vs->num_ids   = Int_val(Field(vs_v, CE_VIEW_STATE_NUM_IDS));
  TRACE("..");
  vs->prev_ids  = View_id_array_val(Field(vs_v, CE_VIEW_STATE_PREV_IDS),
				    vs->num_ids);
  vs->params    = String_copy_val(Field(vs_v,CE_VIEW_STATE_PARAMS));
  vs->uptime    = Double_val(Field(vs_v,CE_VIEW_STATE_UPTIME));
  vs->view      = String_array_val(Field(vs_v, CE_VIEW_STATE_VIEW), nmembers);
  vs->address   = String_array_val(Field(vs_v, CE_VIEW_STATE_ADDRESS), nmembers);
  TRACE(")");
}

/**************************************************************/

enum ce_local_state_enum {
  CE_LOCAL_STATE_ENDPT,
  CE_LOCAL_STATE_ADDR,
  CE_LOCAL_STATE_RANK,
  CE_LOCAL_STATE_NAME,
  CE_LOCAL_STATE_NMEMBERS,
  CE_LOCAL_STATE_VIEW_ID,
  CE_LOCAL_STATE_AM_COORD,
};



void
LocalState_of_val(value ls_v, ce_local_state_t *ls){
  ls->endpt = String_copy_val(Field(ls_v,CE_LOCAL_STATE_ENDPT));
  ls->addr = String_copy_val(Field(ls_v,CE_LOCAL_STATE_ADDR));
  ls->rank  = Int_val(Field(ls_v,CE_LOCAL_STATE_RANK));
  ls->name  = String_copy_val(Field(ls_v,CE_LOCAL_STATE_NAME));
  ls->nmembers = Int_val(Field(ls_v,CE_LOCAL_STATE_NMEMBERS));
  ls->view_id= View_id_val(Field(ls_v,CE_LOCAL_STATE_VIEW_ID));
  ls->am_coord= Bool_val(Field(ls_v,CE_LOCAL_STATE_AM_COORD));
}
/**************************************************************/
void 
ViewFull_val(value ls_v, value vs_v, ce_local_state_t *ls, ce_view_state_t *vs){
  LocalState_of_val(ls_v, ls);
  ViewState_of_val(vs_v, ls->nmembers, vs);
}

/**************************************************************/
enum ce_jops_enum {
  CE_JOPS_HRTBT_RATE,
  CE_JOPS_TRANSPORTS,
  CE_JOPS_PROTOCOL,
  CE_JOPS_GROUP_NAME,
  CE_JOPS_PROPERTIES,
  CE_JOPS_USE_PROPERTIES,
  CE_JOPS_GROUPD,
  CE_JOPS_PARAMS,
  CE_JOPS_DEBUG,
  CE_JOPS_CLIENT,
  CE_JOPS_ENDPT,

  CE_JOPS_PRINC,
  CE_JOPS_KEY,
  CE_JOPS_SECURE,

  CE_JOPS_MAX
};
  
#define CE_M CE_JOPS_MAX

value 
Val_jops (ce_jops_t *jops){
  CAMLparam0();
  CAMLlocalN(rt, CE_M+1);

  TRACE("(Val_jops");
  rt[CE_JOPS_HRTBT_RATE] = copy_double(jops->hrtbt_rate)  ;
  rt[CE_JOPS_TRANSPORTS] = Val_string_opt(jops->transports) ;
  rt[CE_JOPS_PROTOCOL] = Val_string_opt(jops->protocol);
  rt[CE_JOPS_GROUP_NAME] = Val_string_opt(jops->group_name);
  rt[CE_JOPS_PROPERTIES] = Val_string_opt(jops->properties);
  rt[CE_JOPS_USE_PROPERTIES] = Val_bool(jops->use_properties);
  rt[CE_JOPS_GROUPD] = Val_bool(jops->groupd);
  rt[CE_JOPS_PARAMS] = Val_string_opt(jops->params);
  rt[CE_JOPS_CLIENT] = Val_bool(jops->client);
  rt[CE_JOPS_DEBUG] = Val_bool(jops->debug);
  rt[CE_JOPS_ENDPT] = Val_string_opt(jops->endpt);
  rt[CE_JOPS_PRINC] = Val_string_opt(jops->princ);
  rt[CE_JOPS_KEY] = Val_string_opt(jops->key);
  rt[CE_JOPS_SECURE] = Val_bool(jops->secure);

  rt[CE_M] = alloc(CE_M,0);

  Store_field(rt[CE_M], CE_JOPS_HRTBT_RATE, rt[CE_JOPS_HRTBT_RATE]);
  Store_field(rt[CE_M], CE_JOPS_TRANSPORTS, rt[CE_JOPS_TRANSPORTS]);
  Store_field(rt[CE_M], CE_JOPS_PROTOCOL,   rt[CE_JOPS_PROTOCOL]);
  Store_field(rt[CE_M], CE_JOPS_GROUP_NAME, rt[CE_JOPS_GROUP_NAME]);
  Store_field(rt[CE_M], CE_JOPS_PROPERTIES, rt[CE_JOPS_PROPERTIES]);
  Store_field(rt[CE_M], CE_JOPS_USE_PROPERTIES, rt[CE_JOPS_USE_PROPERTIES]);
  Store_field(rt[CE_M], CE_JOPS_GROUPD,     rt[CE_JOPS_GROUPD]);
  Store_field(rt[CE_M], CE_JOPS_PARAMS,     rt[CE_JOPS_PARAMS]);
  Store_field(rt[CE_M], CE_JOPS_CLIENT,     rt[CE_JOPS_CLIENT]);
  Store_field(rt[CE_M], CE_JOPS_DEBUG,      rt[CE_JOPS_DEBUG]);
  Store_field(rt[CE_M], CE_JOPS_ENDPT,      rt[CE_JOPS_ENDPT]);
  Store_field(rt[CE_M], CE_JOPS_PRINC,      rt[CE_JOPS_PRINC]);
  Store_field(rt[CE_M], CE_JOPS_KEY,        rt[CE_JOPS_KEY]);
  Store_field(rt[CE_M], CE_JOPS_SECURE,     rt[CE_JOPS_SECURE]);

  TRACE(")");

  TRACE("free C-jops("); 
  ce_jops_free(jops);
  TRACE(")"); 

  CAMLreturn(rt[CE_M]);

}

/**************************************************************/
value
Val_c_pointer(void *ptr){
  CAMLparam0();
  CAMLlocal1(ptr_v);

  /* This is a hack, intended to allow caml to use a native
   * representation for a C pointer. 
   */
  ptr_v = copy_nativeint((int)ptr);
  
  CAMLreturn(ptr_v);
}

ce_env_t
C_pointer_val(value ptr_v){
  return (void*) Nativeint_val(ptr_v);
}


value
Val_c_appl(ce_appl_intf_t *c_appl){
  return Val_c_pointer((void*)c_appl);
}

ce_appl_intf_t*
C_appl_val(value c_appl){
  return (ce_appl_intf_t*) C_pointer_val(c_appl);
}
	   
value
Val_env(ce_env_t env){
  return Val_c_pointer(env);
}

ce_env_t
Env_val(value env_v){
  return (ce_env_t)C_pointer_val(env_v);
}

value
Val_handler(ce_handler_t handler){
  return Val_c_pointer(handler);  
}

ce_handler_t
Handler_val(value handler_v){
  return (ce_handler_t)C_pointer_val(handler_v);
}
/**************************************************************/
