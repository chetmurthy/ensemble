/**************************************************************/
/* CE_ACTIONS_MT.C */
/* Author: Ohad Rodeh 8/2001 */
/* Based in part on code by Mark Hayden from the CEnsemble system. */
/**************************************************************/
#include "ce_internal.h"
#include "ce_trace.h"
#include "ce_actions_mt.h"
#include <stdio.h>
/**************************************************************/
#define NAME "CE_ACTIONS_MT"
/**************************************************************/

ce_mt_action_t *
ce_mt_appl_cast(ce_mt_queue_t *q, ce_appl_intf_t *c_appl, int num, ce_iovec_array_t iovl) {
    ce_mt_action_t *a = ce_mt_queue_alloc(q);
    TRACE("MT_CAST");
    a->type = MT_CAST ;
    a->c_appl = c_appl;
    a->u.cast.num = num ;
    a->u.cast.iovl = iovl ;
    return a ;
}

ce_mt_action_t *
ce_mt_appl_send(ce_mt_queue_t *q, ce_appl_intf_t *c_appl,
		int num_dests,
		ce_rank_array_t dests, int num, ce_iovec_array_t iovl) {
    ce_mt_action_t *a = ce_mt_queue_alloc(q);
    a->type = MT_SEND ;
    a->c_appl = c_appl;
    a->u.send.num_dests = num_dests ;
    a->u.send.dests = dests ;
    a->u.send.num = num ;
    a->u.send.iovl = iovl ;
    return a ;
}

ce_mt_action_t *
ce_mt_appl_send1(ce_mt_queue_t *q, ce_appl_intf_t *c_appl,
	      ce_rank_t dest, int num, ce_iovec_array_t iovl) {
    ce_mt_action_t *a = ce_mt_queue_alloc(q);
    a->type = MT_SEND1 ;
    a->c_appl = c_appl;
    a->u.send1.dest = dest ;
    a->u.send1.num = num ;
    a->u.send1.iovl = iovl;
    return a ;
}

ce_mt_action_t *
ce_mt_appl_leave(ce_mt_queue_t *q, ce_appl_intf_t *c_appl) {
    ce_mt_action_t *a = ce_mt_queue_alloc(q);
    a->type = MT_LEAVE ;
    a->c_appl = c_appl;
    return a ;
}

ce_mt_action_t *
ce_mt_appl_prompt(ce_mt_queue_t *q, ce_appl_intf_t *c_appl) {
    ce_mt_action_t *a = ce_mt_queue_alloc(q);
    a->type = MT_PROMPT ;
    a->c_appl = c_appl;
    return a ;
}

ce_mt_action_t *
ce_mt_appl_suspect(ce_mt_queue_t *q, ce_appl_intf_t *c_appl,
		int num, ce_rank_array_t suspects) {
    ce_mt_action_t *a = ce_mt_queue_alloc(q);
    a->type = MT_SUSPECT ;
    a->c_appl = c_appl;
    a->u.suspect.num = num;
    a->u.suspect.members = suspects;
    return a ;
}

ce_mt_action_t *
ce_mt_appl_xfer_done(ce_mt_queue_t *q, ce_appl_intf_t *c_appl) {
    ce_mt_action_t *a = ce_mt_queue_alloc(q);
    a->type = MT_XFERDONE ;
    a->c_appl = c_appl;
    return a ;
}

ce_mt_action_t *
ce_mt_appl_rekey(ce_mt_queue_t *q, ce_appl_intf_t *c_appl) {
    ce_mt_action_t *a = ce_mt_queue_alloc(q);
    a->type = MT_REKEY ;
    a->c_appl = c_appl;
    return a ;
}

ce_mt_action_t *
ce_mt_appl_protocol(ce_mt_queue_t *q, ce_appl_intf_t *c_appl, char* protocol_name) {
    ce_mt_action_t *a = ce_mt_queue_alloc(q);
    a->type = MT_PROTOCOL ;
    a->c_appl = c_appl;
    a->u.proto = protocol_name;
    return a ;
}


ce_mt_action_t *
ce_mt_appl_properties(ce_mt_queue_t *q, ce_appl_intf_t *c_appl, char* properties) {
    ce_mt_action_t *a = ce_mt_queue_alloc(q);
    a->type = MT_PROPERTIES ;
    a->c_appl = c_appl;
    a->u.properties = properties;
    return a ;
}

/**************************************************************/

ce_mt_action_t *ce_mt_appl_join(ce_mt_queue_t *q, ce_appl_intf_t *c_appl,
				ce_jops_t *ops){
    ce_mt_action_t *a = ce_mt_queue_alloc(q);
    TRACE("MT_JOIN");
    a->type = MT_JOIN ;
    a->c_appl = c_appl;
    a->u.join.ops = ops;
    return a ;
}
				       
ce_mt_action_t *ce_mt_appl_AddSockRecv(
    ce_mt_queue_t *q,
    CE_SOCKET socket, ce_handler_t handler, ce_env_t env
    ){
    ce_mt_action_t *a = ce_mt_queue_alloc(q);
    a->type = MT_ADDSOCKRECV;
    a->c_appl = NULL;
    a->u.add_sock.socket = socket;
    a->u.add_sock.handler = handler;
    a->u.add_sock.env = env;
    return a ;
}

ce_mt_action_t *ce_mt_appl_RmvSockRecv(ce_mt_queue_t *q,  CE_SOCKET socket)
{
    ce_mt_action_t *a = ce_mt_queue_alloc(q);
    a->type = MT_RMVSOCKRECV;
    a->c_appl = NULL;
    a->u.rmv_sock.socket = socket;
    return a ;
}

/**************************************************************/
/* This implements an efficient queue, that is implemented
 * using an extendible array.
 */


#define SIZE sizeof(ce_mt_action_t)

static void
grow(ce_mt_queue_t *q)
{
    ce_mt_action_t *oarr = q->arr ;
    
    q->alen = 2 * q->alen ;
    q->arr = ce_malloc(SIZE * q->alen) ;
    
    //   if (q->alen * q->size > 1<<12) {
    //	eprintf("QUEUE:expand:getting large:len=%d:%s\n", q->alen * q->size, q->debug) ;
    //    }
    
    memset(q->arr, 0, SIZE * q->alen) ;
    memcpy(q->arr, oarr, SIZE * q->len); 
    free(oarr) ;
}

ce_mt_queue_t *
ce_mt_queue_create()
{
    ce_mt_queue_t *q ;
    q = record_create(ce_mt_queue_t*, q) ;
    q->alen = 1<<5  ;		/* must be a power of 2 */
    q->len = 0 ;
    q->arr = ce_malloc(SIZE * q->alen) ;
    memset(q->arr, 0, SIZE * q->alen) ;
    return q ;
}

ce_bool_t
ce_mt_queue_empty(ce_mt_queue_t *q)
{
    return !q->len ;
}

int
ce_mt_queue_length(ce_mt_queue_t *q) {
    return q->len ;
}


/* We wish to add an action to the end of the queue.
 * There are three things to do:
 * 1) check the queue is not full, in which case
 *    it needs to be enlarged.
 * 2) return an address at the end of the queue at which we can write.
 * 3) Increment the length.
 */
ce_mt_action_t *
ce_mt_queue_alloc(ce_mt_queue_t *q)
{
    int ret_addr;
    
    if (q->len >= q->alen) {
	TRACE("grow");
	grow(q) ;
    }
    ret_addr = q->len;
    q->len = q->len + 1 ;
    return((ce_mt_action_t*)&(q->arr[ret_addr]));
}

void
ce_mt_queue_free(ce_mt_queue_t *q)
{
    free(q->arr) ;
    record_free(q) ;
}

/* There is no need to free the individual items, because they
 * are passed for processing to the Ensemble thread, where they will
 * be freed. 
 */
void
ce_mt_queue_clear(ce_mt_queue_t *q)
{
    TRACE("ce_mt_queue_clear(");
    memset(q->arr, 0, SIZE * q->len) ;
    q->len = 0 ;
    TRACE(")");
}

void
ce_mt_queue_copy_and_clear(ce_mt_queue_t *src, ce_mt_queue_t *trg)
{
    trg->len =src->len;
    if (trg->alen < src->len){
	free(trg->arr);
	trg->arr = ce_malloc(SIZE * src->len);
    }
    memcpy(trg->arr, src->arr, SIZE * src->len);
    trg->alen = src->len;
    ce_mt_queue_clear(src);
}

/**************************************************************/
/**************************************************************/



