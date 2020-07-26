/**************************************************************/
/* CE_QUEUE.C */
/* Author: Ohad Rodeh 8/2001 */
/* Based in part on code by Mark Hayden from the CEnsemble system. */
/**************************************************************/
#include "ce_internal.h"
#include "ce_trace.h"
#include <stdio.h>
/**************************************************************/
#define NAME "CE_ACTIONS"
/**************************************************************/

ce_action_t *
ce_appl_cast(ce_queue_t *q, int num, ce_iovec_array_t iovl) {
  ce_action_t *a = ce_queue_alloc(q);
  a->type = APPL_CAST ;
  a->u.cast.num = num ;
  a->u.cast.iovl = iovl ;
  return a ;
}

ce_action_t *
ce_appl_send(ce_queue_t *q, int num_dests,
	     ce_rank_array_t dests, int num, ce_iovec_array_t iovl) {
  ce_action_t *a = ce_queue_alloc(q);
  a->type = APPL_SEND ;
  a->u.send.num_dests = num_dests ;
  a->u.send.dests = dests ;
  a->u.send.num = num ;
  a->u.send.iovl = iovl ;
  return a ;
}

ce_action_t *
ce_appl_send1(ce_queue_t *q, ce_rank_t dest, int num, ce_iovec_array_t iovl) {
  ce_action_t *a = ce_queue_alloc(q);
  a->type = APPL_SEND1 ;
  a->u.send1.dest = dest ;
  a->u.send1.num = num ;
  a->u.send1.iovl = iovl;
  return a ;
}

ce_action_t *
ce_appl_leave(ce_queue_t *q) {
  ce_action_t *a = ce_queue_alloc(q);
  a->type = APPL_LEAVE ;
  return a ;
}

ce_action_t *
ce_appl_prompt(ce_queue_t *q) {
  ce_action_t *a = record_create(ce_action_t*, a) ;
  a->type = APPL_PROMPT ;
  return a ;
}

ce_action_t *
ce_appl_suspect(ce_queue_t *q, int num, ce_rank_array_t suspects) {
  ce_action_t *a = ce_queue_alloc(q);
  a->type = APPL_SUSPECT ;
  a->u.suspect.num = num;
  a->u.suspect.members = suspects;
  return a ;
}

ce_action_t *
ce_appl_xfer_done(ce_queue_t *q) {
  ce_action_t *a = ce_queue_alloc(q);
  a->type = APPL_XFERDONE ;
  return a ;
}

ce_action_t *
ce_appl_rekey(ce_queue_t *q) {
  ce_action_t *a = ce_queue_alloc(q);
  a->type = APPL_REKEY ;
  return a ;
}

ce_action_t *
ce_appl_protocol(ce_queue_t *q, char* protocol_name) {
  ce_action_t *a = ce_queue_alloc(q);
  a->type = APPL_PROTOCOL ;
  a->u.proto = protocol_name;
  return a ;
}


ce_action_t *
ce_appl_properties(ce_queue_t *q, char* properties) {
  ce_action_t *a = ce_queue_alloc(q);
  a->type = APPL_PROPERTIES ;
  a->u.properties = properties;
  return a ;
}


void
ce_action_free(ce_action_t *a) {
    switch(a->type) {
	
    case APPL_CAST:
      free(a->u.cast.iovl) ;
      break ;

    case APPL_SEND:
      free(a->u.send.iovl) ;
      free(a->u.send.dests) ;
      break ;

    case APPL_SEND1:
      free(a->u.send1.iovl) ;
      break ;

    case APPL_LEAVE:
    case APPL_PROMPT:
	/* nothing */
	break ;

    case APPL_SUSPECT:
      free(a->u.suspect.members);
      break;
	
    case APPL_XFERDONE:
    case APPL_REKEY:
	/* nothing */
	break ;

    case APPL_PROTOCOL:
      free(a->u.proto);
      break;

    case APPL_PROPERTIES:
      free(a->u.properties);
      break;
      
    default:
      printf ("Error, bad action type\n");
      exit(1);
    }

}
/**************************************************************/
/* This implements an efficient queue, that is implemented
 * using an extendible array.
 */


#define SIZE sizeof(ce_action_t)

struct ce_queue_t {
  ce_action_t *arr ;
  int len ;
  int alen ;		/* power of 2 */
} ;

void grow(ce_queue_t *q) {
  ce_action_t *oarr = q->arr ;

  q->alen = 2 * q->alen ;
  q->arr = ce_malloc(SIZE * q->alen) ;

    //   if (q->alen * q->size > 1<<12) {
    //	eprintf("QUEUE:expand:getting large:len=%d:%s\n", q->alen * q->size, q->debug) ;
    //    }

  memset(q->arr, 0, SIZE * q->alen) ;
  memcpy(q->arr, oarr, SIZE * q->len); 
  free(oarr) ;
}

ce_queue_t *ce_create_queue() {
  ce_queue_t *q ;
  q = record_create(ce_queue_t*, q) ;
  q->alen = 1<<5  ;		/* must be a power of 2 */
  q->len = 0 ;
  q->arr = ce_malloc(SIZE * q->alen) ;
  memset(q->arr, 0, SIZE * q->alen) ;
  return q ;
}

ce_bool_t ce_queue_empty(ce_queue_t *q) {
    return !q->len ;
}

int ce_queue_length(ce_queue_t *q) {
    return q->len ;
}


/* We wish to add an action to the end of the queue.
 * There are three things to do:
 * 1) check the queue is not full, in which case
 *    it needs to be enlarged.
 * 2) return an address at the end of the queue at which we can write.
 * 3) Increment the length.
 */
ce_action_t* ce_queue_alloc(ce_queue_t *q){
  int ret_addr;

  if (q->len >= q->alen) {
    TRACE("grow");
    grow(q) ;
  }
  ret_addr = q->len;
  q->len = q->len + 1 ;
  return((ce_action_t*)&(q->arr[ret_addr]));
}

void ce_queue_free(ce_queue_t *q) {
    free(q->arr) ;
    record_free(q) ;
}

void ce_queue_clear(ce_queue_t *q) {
  int i ;

  TRACE("ce_queue_clear len");
  for (i=0;i<q->len;i++) {
    ce_action_free((ce_action_t*)&(q->arr[i]));
  }
  TRACE(".");
  memset(q->arr, 0, SIZE * q->len) ;
  q->len = 0 ;
  TRACE(")");
}

/**************************************************************/
/* Conversions
 */

/* A function that wrapps Val_int
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


value
Val_action (ce_action_t *a){
  CAMLparam0() ;
  CAMLlocal3(field0, field1, a_v) ;

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
    field0 = copy_string(a->u.proto);
    a_v = alloc_small(1,APPL_PROTOCOL);
    Field(a_v, 0) = field0 ;
    break;

  case APPL_PROPERTIES:
    field0 = copy_string(a->u.properties);
    a_v = alloc_small(1,APPL_PROPERTIES);
    Field(a_v, 0) = field0 ;
    break;
    
  default:
    printf("Bad action type");
    exit(1);
  }
  
  CAMLreturn(a_v) ;
}

value Val_queue(ce_queue_t *q){
  int i;
  CAMLparam0() ;
  CAMLlocal2(tmp,dn_v) ;

  //  sprintf(str, "Val_queue: len=%d", q->len);
  //TRACE(str);

  /* ML already zeros the field here. 
   */
  TRACE("{");
  if (q->len == 0)
    dn_v = Atom(0) ;
  else {
    dn_v = alloc(q->len,0) ;
    
    for (i = 0; i< q->len; i++) {
      TRACE(" .");
      tmp = Val_action(&(q->arr[i])) ;
      modify(&Field(dn_v,i),tmp);
    }
  }
  TRACE("}");
  
  CAMLreturn(dn_v) ;
}
/**************************************************************/



