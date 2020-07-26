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
/* CE_CONVERT.C */
/* Author: Ohad Rodeh  8/2001 */
/* Conversion of ML <-> C data-structures */
/**************************************************************/
#include "ce_internal.h"
#include "ce_trace.h"
#include "mm.h"
#include <stdio.h>
#include <assert.h>
/**************************************************************/
#define NAME "CE_CONVERT"
/**************************************************************/
#if 0
value ce_mm_Raw_of_len_buf(int len, char *buf)
{
    CAMLparam0();
    CAMLlocal1(s_v);
    
    TRACE("ce_mm_Raw_of_len_buf");
    printf("<len=%d>");
    s_v = alloc_string (len);
    memcpy(String_val(s_v), buf, len);
//    TRACE(".");
//    printf("buf[0]=%d", *((int*)&buf[0]));
    free(buf);
    TRACE(")");
    
    CAMLreturn(s_v);
}

INLINE void set_iovl (ce_iovec_array_t iovl, int i, value iov_v)
{
    Iov_len(iovl[i]) = string_length(iov_v);
    Iov_buf(iovl[i]) = String_val(iov_v);
}
#else

INLINE void set_iovl(ce_iovec_array_t iovl, int i, value iov_v)
{
    Iov_len(iovl[i]) = Int_val(Field(iov_v,0));
    Iov_buf(iovl[i]) = (char*) mm_Cbuf_val(Field(iov_v,1));
}

#define ce_mm_Raw_of_len_buf       mm_Raw_of_len_buf
#endif
/**************************************************************/


#define MAX(x,y) (((x) > (y)) ? (x) : (y))

/*
 *  The call to alloc_string should be replaced with a call to ce_alloc_space. 
 */
value Val_iovl(int num, ce_iovec_array_t iovl)
{
    int i;
    CAMLparam0();
    CAMLlocal2(msg_v, ret_v);
    
    if (0 == num) {
	ret_v = Atom(0);
    } else {
	ret_v = alloc(num,0);
	for(i=0; i<num; i++) {
	    int len = Iov_len(iovl[i]);
	    char *buf = Iov_buf(iovl[i]);
	    assert(len > 0);
//	    TRACE_GEN(("<Val_iovl[%d] len=%d>", i, len));
	    msg_v = ce_mm_Raw_of_len_buf(len, buf);
	    modify(&Field(ret_v,i), msg_v);
	}
    }
    
    CAMLreturn(ret_v);  
}

/* We cache a local iovl. The user MAY NOT free it. 
 */
static ce_iovec_array_t iovl = NULL;
static int iovl_len = 0;

ce_iovec_array_t Iovl_val(value iovl_v)
{
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
	set_iovl(iovl, i, iov_v);
    }
    
    return iovl;
}

void String_copy_val(value s_v, char *dest, int max_size)
{
    int len;
    
    len = string_length(s_v);
    len = MIN(max_size-1,len);    
    memcpy(dest, &Byte(s_v,0), len);
    dest[len] = '\0';
}


void Key_val(value key_v, char *dest)
{
    if (string_length(key_v) == 0)
	return;
    else {
	memcpy(dest, String_val(key_v), CE_KEY_SIZE);
    }
}

/**************************************************************/

ce_addr_array_t Addr_array_val(value sa_v, int n)
{
    int i;
    ce_addr_t *aa;
    
    aa = (ce_addr_t*) ce_malloc(n * sizeof(ce_addr_t));
    memset(aa, 0, n * sizeof(ce_addr_t));
    for (i=0; i< n; i++)
	String_copy_val(
	    Field(sa_v, i),
	    aa[i].addr,
	    CE_ADDR_MAX_SIZE
	    );
    return(aa);
}


ce_endpt_array_t Endpt_array_val(value sa_v, int n)
{
    int i;
    ce_endpt_t *ea;
    
    ea = (ce_endpt_t*) ce_malloc(n * sizeof(ce_endpt_t));
    memset(ea, 0, n * sizeof(ce_endpt_t));
    for (i=0; i< n; i++)
	String_copy_val(
	    Field(sa_v, i),
	    ea[i].name,
	    CE_ENDPT_MAX_SIZE
	    );
    return(ea);
}


void View_id_val(value id_v, ce_view_id_t *id)
{
    id->ltime = Int_val(Field(id_v,0));
    String_copy_val(
	Field(id_v,1),
	id->endpt.name,
	CE_ENDPT_MAX_SIZE
	);
}

ce_view_id_t*
View_id_array_val(value view_id_array_v, int num)
{
    int i;
    ce_view_id_t *va;

    va = (ce_view_id_t*) ce_malloc(num * sizeof(ce_view_id_t));
    memset((char*)va, 0, num * sizeof(ce_view_id_t));
    for (i=0; i<num; i++) 
	View_id_val(Field(view_id_array_v,i), &va[i]);
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
void ViewState_of_val(value vs_v, int nmembers, ce_view_state_t *vs)
{
    TRACE("ViewState_of_val(");
    String_copy_val(
	Field(vs_v, CE_VIEW_STATE_VERSION),
	vs->version,
	CE_VERSION_MAX_SIZE
	);
    String_copy_val(
	Field(vs_v, CE_VIEW_STATE_GROUP),
	vs->group,
	CE_GROUP_NAME_MAX_SIZE
	);
    String_copy_val(
	Field(vs_v, CE_VIEW_STATE_PROTO),
	vs->proto,
	CE_PROTOCOL_MAX_SIZE
	);
    vs->coord     = Int_val(Field(vs_v, CE_VIEW_STATE_COORD));
    vs->ltime     = Int_val(Field(vs_v, CE_VIEW_STATE_LTIME));
    vs->primary   = Bool_val(Field(vs_v, CE_VIEW_STATE_PRIMARY));
    vs->groupd    = Bool_val(Field(vs_v, CE_VIEW_STATE_GROUPD));
    vs->xfer_view = Bool_val(Field(vs_v, CE_VIEW_STATE_XFER_VIEW));
    Key_val(
	Field(vs_v, CE_VIEW_STATE_KEY),
	vs->key
	);
    TRACE(".");
    vs->num_ids   = Wosize_val(Field(vs_v, CE_VIEW_STATE_PREV_IDS));
    TRACE("..");
    vs->prev_ids  = View_id_array_val(Field(vs_v, CE_VIEW_STATE_PREV_IDS),
				      vs->num_ids);
    String_copy_val(
	Field(vs_v,CE_VIEW_STATE_PARAMS),
	vs->params,
	CE_PARAMS_MAX_SIZE
	);
    vs->uptime    = Double_val(Field(vs_v,CE_VIEW_STATE_UPTIME));
    vs->view      = Endpt_array_val(Field(vs_v, CE_VIEW_STATE_VIEW), nmembers);
    vs->address   = Addr_array_val(Field(vs_v, CE_VIEW_STATE_ADDRESS), nmembers);
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
LocalState_of_val(value ls_v, ce_local_state_t *ls)
{
    String_copy_val(
	Field(ls_v,CE_LOCAL_STATE_ENDPT),
	ls->endpt.name,
	CE_ENDPT_MAX_SIZE
	);
    String_copy_val(
	Field(ls_v,CE_LOCAL_STATE_ADDR),
	ls->addr.addr,
	CE_ADDR_MAX_SIZE
	);
		    
    ls->rank  = Int_val(Field(ls_v,CE_LOCAL_STATE_RANK));
    String_copy_val(
	Field(ls_v,CE_LOCAL_STATE_NAME),
	ls->name,
	CE_NAME_MAX_SIZE
	);
    ls->nmembers = Int_val(Field(ls_v,CE_LOCAL_STATE_NMEMBERS));
    View_id_val(Field(ls_v,CE_LOCAL_STATE_VIEW_ID), &ls->view_id);
    ls->am_coord= Bool_val(Field(ls_v,CE_LOCAL_STATE_AM_COORD));
}

/**************************************************************/
void ViewFull_val(value ls_v, value vs_v, ce_local_state_t *ls, ce_view_state_t *vs)
{
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

value Val_jops (ce_jops_t *jops)
{
    CAMLparam0();
    CAMLlocalN(rt, CE_M+1);
    
//    TRACE("(Val_jops");
    rt[CE_JOPS_HRTBT_RATE] = copy_double(jops->hrtbt_rate)  ;
    rt[CE_JOPS_TRANSPORTS] = copy_string(jops->transports) ;
    rt[CE_JOPS_PROTOCOL] = copy_string(jops->protocol);
    rt[CE_JOPS_GROUP_NAME] = copy_string(jops->group_name);
    rt[CE_JOPS_PROPERTIES] = copy_string(jops->properties);
    rt[CE_JOPS_USE_PROPERTIES] = Val_bool(jops->use_properties);
    rt[CE_JOPS_GROUPD] = Val_bool(jops->groupd);
    rt[CE_JOPS_PARAMS] = copy_string(jops->params);
    rt[CE_JOPS_CLIENT] = Val_bool(jops->client);
    rt[CE_JOPS_DEBUG] = Val_bool(jops->debug);
    rt[CE_JOPS_ENDPT] = copy_string(jops->endpt.name);
    rt[CE_JOPS_PRINC] = copy_string(jops->princ);
    rt[CE_JOPS_KEY] = copy_string(jops->key);
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
    
//    TRACE(")");
    
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
C_appl_val(value c_appl_v)
{
    ce_appl_intf_t *c_appl;
    
    c_appl = (ce_appl_intf_t*) C_pointer_val(c_appl_v);
    assert(c_appl->magic == CE_MAGIC);
    return c_appl; 
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
/* Conversions
 */

/* A function that wraps Val_int
 */
value Val_int_fun(const char *p){
    int i = (int)p;
    
    return (Val_int(i));
}

value convert_int_array(int num, int* a){
    int i;
    CAMLparam0();
    CAMLlocal1(ret_v);
    
    if (num==0)
	ret_v = Atom(0);
    else {
	ret_v = alloc(num,0);
	for(i=0; i<num; i++) {
	    modify(&Field(ret_v,i), Val_int(a[i]));
	}
    }
    
    CAMLreturn(ret_v);
}


static value
Val_action (ce_action_t *a)
{
    CAMLparam0() ;
    CAMLlocal3(field0, field1, a_v) ;

    assert(a != NULL);
    switch (a->type) {
    case APPL_CAST:
	TRACE("APPL_CAST(");
	field0 = Val_iovl(a->u.cast.num, a->u.cast.iovl);
	a_v = alloc_small(1, APPL_CAST);
	Field(a_v, 0) = field0;
	TRACE(")");
	break;
	
    case APPL_SEND:
	TRACE("APPL_CAST(");
	field0 = convert_int_array(a->u.send.num,a->u.send.dests);
	field1 = Val_iovl(a->u.send.num, a->u.send.iovl);
	a_v = alloc_small(2, APPL_SEND);
	Field(a_v, 0) = field0;
	Field(a_v, 1) = field1;
	TRACE(")");
	break;
	
    case APPL_SEND1:
	field0 = Val_int(a->u.send1.dest);
	field1 = Val_iovl(a->u.send1.num, a->u.send1.iovl);
	a_v = alloc_small(2, APPL_SEND1);
	Field(a_v, 0) = field0;
	Field(a_v, 1) = field1;
	break;
	
    case APPL_LEAVE:
	a_v = alloc_small(1,APPL_LEAVE);
	Field(a_v, 0) = Val_unit ;
	break;
	
    case APPL_PROMPT:
	a_v = alloc_small(1,APPL_PROMPT);
	Field(a_v, 0) = Val_unit ;
	break;
	
    case APPL_SUSPECT:
	field0 = convert_int_array(a->u.suspect.num,a->u.suspect.members);
	a_v = alloc_small(1,APPL_SUSPECT);
	Field(a_v, 0) = field0;
	break;
	
    case APPL_XFERDONE:
	a_v = alloc_small(1,APPL_XFERDONE);
	Field(a_v, 0) = Val_unit ;
	break;
	
    case APPL_REKEY:
	a_v = alloc_small(1,APPL_REKEY);
	Field(a_v, 0) = Val_unit ;
	break;
	
    case APPL_PROTOCOL:
	TRACE("APPL_PROTOCOL(");
	field0 = copy_string(a->u.proto);
	a_v = alloc_small(1,APPL_PROTOCOL);
	Field(a_v, 0) = field0 ;
	TRACE(")");
	break;
	
    case APPL_PROPERTIES:
	field0 = copy_string(a->u.properties);
	a_v = alloc_small(1,APPL_PROPERTIES);
	Field(a_v, 0) = field0 ;
	break;
	
    case APPL_BLOCK_OK:
	field0 = Val_int(a->u.block_ok) ;
	a_v = alloc_small(1,APPL_BLOCK_OK);
	Field(a_v, 0) = field0; 
	break;
	
    default:
	printf("Bad action type");
	exit(1);
    }
    
    CAMLreturn(a_v) ;
}

value
Val_queue(ce_queue_t *q)
{
    int i;
    ce_action_t *a;
    CAMLparam0() ;
    CAMLlocal2(tmp,dn_v) ;

    assert(check_queue(q));
    
    /* ML already zeros the field here. 
     */
    if (q->len == 0)
	dn_v = Atom(0) ;
    else {
	TRACE_D("Val_queue: len=", q->len);
	dn_v = alloc(q->len,0) ;

	for (i = 0, a = q->head;
	     i< q->len;
	     i++, a = a->next) {
	    TRACE(" .");
	    assert(a != NULL);
	    tmp = Val_action(a);
	    modify(&Field(dn_v,i),tmp);
	}
    }
    
    CAMLreturn(dn_v) ;
}
/**************************************************************/
