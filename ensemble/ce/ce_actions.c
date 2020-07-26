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
#define MAX_NUM_FREE 60
#define NUM_NEW_ACTIONS 5

#if 0
#define CE_CHECK(x) assert((x))
#else
#define CE_CHECK(x) 
#endif

static int check_pool(ce_pool_t *pool)
{
    int i;
    ce_action_t *a;
    
    for(i=0, a=pool->head;
	a != NULL;
	i++, a=a->next);
    
    if (i != pool->num_free) {
	printf ("\n bad pool, num_free=%d, i=%d\n", pool->num_free, i);
	return 0;
    } else {
	return 1;
    }
}

static void free_some_buffers(ce_pool_t *pool)
{
    ce_action_t *tmp;
    
    while (pool->num_free > MAX_NUM_FREE/2) {
	tmp = pool->head;
	pool->head = pool->head->next;
	free(tmp);
	pool->num_free--;
    }
}

ce_pool_t *ce_pool_create(void)
{
    ce_pool_t *pool;

    pool = (ce_pool_t*) ce_malloc(sizeof(ce_pool_t));
    memset(pool, 0, sizeof(ce_pool_t));
    return pool;
}

ce_action_t *ce_action_alloc_from_pool(ce_pool_t *pool)
{
   ce_action_t *new_act;
   int i;

   CE_CHECK(check_pool(pool));
   
   if (pool->num_free > 0) {
       new_act = pool->head;
       pool->head = pool->head->next;
       new_act->next = NULL;
       pool->num_free--;

       CE_CHECK(check_pool(pool));
       return new_act;
   }  else {
       /* Add NUM_NEW_ACTIONS more fresh actions to the pool
	*/
       for (i=0; i<NUM_NEW_ACTIONS; i++) {
	   new_act = (ce_action_t*) ce_malloc(sizeof(ce_action_t));
	   new_act->next = pool->head;
	   pool->head = new_act;
	   pool->num_free++;
       }
       CE_CHECK(check_pool(pool));
       return ce_action_alloc_from_pool(pool);
   }
}

void ce_action_return_to_pool(ce_pool_t *pool, ce_action_t *action)
{
    CE_CHECK(check_pool(pool));
    if (NULL == pool->head) {
	pool->head = action;
	action->next = NULL;
    } else {
	action->next = pool->head;
	pool->head = action;
    }
    pool->num_free++;

    CE_CHECK(check_pool(pool));
}

/* Move free items from one pool to the other. 
 */
void ce_pool_move(ce_pool_t *src, ce_pool_t *trg, int num)
{
    int i;
    ce_action_t *tmp;

    if (num == 0
	|| NULL == src->head) return;
    
    if (NULL == trg->head) {
	tmp = src->head;
	src->head = src->head->next;
	tmp->next = NULL;
	trg->head = tmp;
	num--;

	trg->num_free++;
	src->num_free--;
    }
    
    for (i=0 ; i<num && src->head != NULL; i++) {
	tmp = src->head;
	src->head = tmp->next;
	tmp->next = trg->head;
	trg->head = tmp;
	trg->num_free++;
	src->num_free--;
    }

    if (src->num_free > MAX_NUM_FREE)
	free_some_buffers(src);
    if (trg->num_free > MAX_NUM_FREE)
	free_some_buffers(trg);

    CE_CHECK(check_pool(src));
    CE_CHECK(check_pool(trg));
}

/**************************************************************/
void ce_action_cast(ce_pool_t *pool, ce_queue_t *q, int num, ce_iovec_array_t iovl)
{
    ce_action_t *a = ce_action_alloc_from_pool(pool);
    ce_queue_add_tail(q, a);
    
    if (num > CE_IOVL_MAX_SIZE)
	CE_ERROR(("Cast action: iovector too long (len>%d)", CE_IOVL_MAX_SIZE));
    a->type = APPL_CAST ;
    a->u.cast.num = num ;
    memcpy(a->u.cast.iovl, iovl,  num * sizeof(ce_iovec_t));
}

void ce_action_send(ce_pool_t *pool, ce_queue_t *q, int num_dests,
		  ce_rank_array_t dests, int num, ce_iovec_array_t iovl)
{
    ce_action_t *a = ce_action_alloc_from_pool(pool);
    ce_queue_add_tail(q, a);
    
    if (num > CE_IOVL_MAX_SIZE)
	CE_ERROR(("Send action: iovector too long (len>%d)", CE_IOVL_MAX_SIZE));
    if (num_dests > CE_DESTS_MAX_SIZE)
	CE_ERROR(("Send action: number of destinations too large (len>%d)", CE_DESTS_MAX_SIZE));
    
    a->type = APPL_SEND ;
    a->u.send.num_dests  = num_dests;
    memcpy(a->u.send.dests, dests, num_dests * sizeof(ce_rank_t)) ;
    a->u.send.num = num ;
    memcpy(a->u.send.iovl, iovl, num * sizeof(ce_iovec_t)) ;
}

void ce_action_send1(ce_pool_t *pool, ce_queue_t *q, ce_rank_t dest, int num, ce_iovec_array_t iovl)
{
    ce_action_t *a = ce_action_alloc_from_pool(pool);    
    ce_queue_add_tail(q, a);

    a->type = APPL_SEND1 ;
    if (num > CE_IOVL_MAX_SIZE)
	CE_ERROR(("Send1 action: iovector too long (len>%d)", CE_IOVL_MAX_SIZE));
    a->u.send1.dest = dest ;
    a->u.send1.num = num ;
    memcpy(a->u.send1.iovl, iovl, num * sizeof(ce_iovec_t)) ;
}

void ce_action_leave(ce_pool_t *pool, ce_queue_t *q)
{
    ce_action_t *a = ce_action_alloc_from_pool(pool);
    ce_queue_add_tail(q, a);

    a->type = APPL_LEAVE ;
}

void ce_action_prompt(ce_pool_t *pool, ce_queue_t *q)
{
    ce_action_t *a = ce_action_alloc_from_pool(pool);
    ce_queue_add_tail(q, a);

    a->type = APPL_PROMPT ;
}

void ce_action_suspect(ce_pool_t *pool, ce_queue_t *q, int num, ce_rank_array_t suspects)
{
    ce_action_t *a = ce_action_alloc_from_pool(pool);
    ce_queue_add_tail(q, a);
    
    if (num > CE_DESTS_MAX_SIZE)
	CE_ERROR(("Suspect action: number of suspicions too large (len>%d)", CE_DESTS_MAX_SIZE));
    a->type = APPL_SUSPECT ;
    a->u.suspect.num = num;
    memcpy(a->u.suspect.members, suspects, num * sizeof(ce_rank_t));
}

void ce_action_xfer_done(ce_pool_t *pool, ce_queue_t *q)
{
    ce_action_t *a = ce_action_alloc_from_pool(pool);
    ce_queue_add_tail(q, a);
    a->type = APPL_XFERDONE ;
}

void ce_action_rekey(ce_pool_t *pool, ce_queue_t *q)
{
    ce_action_t *a = ce_action_alloc_from_pool(pool);
    ce_queue_add_tail(q, a);
    a->type = APPL_REKEY ;
}

void ce_action_protocol(ce_pool_t *pool, ce_queue_t *q, char* protocol)
{
    ce_action_t *a;

    if (strlen(protocol) > CE_PROTOCOL_MAX_SIZE-1) 
	CE_ERROR(("Protocol action: protocl string too long (%s) (len=%d > maximum=%d",
		  protocol, strlen(protocol), CE_PROTOCOL_MAX_SIZE-1));

    a = ce_action_alloc_from_pool(pool);
    ce_queue_add_tail(q, a);
    a->type = APPL_PROTOCOL ;
    memset(a->u.proto, 0, CE_PROTOCOL_MAX_SIZE);
    memcpy(a->u.proto, protocol, strlen(protocol));
}


void ce_action_properties(ce_pool_t *pool, ce_queue_t *q, char* properties)
{
    ce_action_t *a;

    if (strlen(properties) > CE_PROPERTIES_MAX_SIZE-1) 
	CE_ERROR(("Properties action: properties string too long (len=%d > maximum=%d",
		 strlen(properties), CE_PROPERTIES_MAX_SIZE-1));

    a = ce_action_alloc_from_pool(pool);
    ce_queue_add_tail(q, a);
    a->type = APPL_PROPERTIES ;
    memset(a->u.properties, 0, CE_PROPERTIES_MAX_SIZE);
    memcpy(a->u.properties, properties, strlen(properties));
}

void ce_action_block_ok(ce_pool_t *pool, ce_queue_t *q, ce_bool_t flag )
{
    ce_action_t *a = ce_action_alloc_from_pool(pool);
    ce_queue_add_tail(q, a);
    a->type = APPL_BLOCK_OK;
    a->u.block_ok = flag;
}

/**************************************************************/
/* This implements an efficient queue, that is implemented
 * using an extendible array.
 */

/* Function used for debugging, compute the length of the queue.
 * We can then compare it to the real length.
 */
int check_queue(ce_queue_t *q)
{
    int i;
    ce_action_t *a;
    
    for(i=0, a=q->head;
	a != NULL;
	i++, a=a->next);

    if (i != q->len)
	return 0;
    switch(q->len){
    case 0:
	if (q->head == q->tail
	    && q->tail == NULL) return 1;
	else
	    return 0;
	break;
    case 1:
	if (q->head != q->tail)
	    return 0;
	else
	    return 1;
    default:
	return 1;
    }
}

ce_queue_t *ce_queue_create(void)
{
    ce_queue_t *q ;
    q = (ce_queue_t*) ce_malloc(sizeof(ce_queue_t));
    memset(q, 0, sizeof(ce_queue_t));
    return q ;
}

ce_bool_t ce_queue_empty(ce_queue_t *q)
{
    CE_CHECK(check_queue(q));
    return !q->len ;
}

int ce_queue_length(ce_queue_t *q)
{
    CE_CHECK(check_queue(q));
    return q->len ;
}

void ce_queue_add_tail(ce_queue_t *q, ce_action_t *a)
{
    CE_CHECK(check_queue(q));

    a->next = NULL;
    if (NULL == q->tail) {
	assert(NULL == q->head && 0 == q->len);
	q->head = a;
	q->tail = a;
	q->len =1;
    } else {
	assert(NULL != q->head && 0 != q->len);
	q->tail->next = a;
	q->tail = a;
	q->len++;
    }
    CE_CHECK(check_queue(q));
}

ce_action_t *ce_queue_pop(ce_queue_t *q)
{
    ce_action_t *a;
    
    CE_CHECK(check_queue(q));
    if (q->len == 0) return NULL;

    assert(NULL != q->head && NULL != q->tail);
    if (1 == q->len) {
	a = q->head;
	q->head = NULL;
	q->tail = NULL;
	q->len = 0;
    } else {
	a = q->head;
	q->head = a->next;
	q->len--;
    }
    CE_CHECK(check_queue(q));
    a->next = NULL;
    return a;
}

void ce_queue_pour(ce_queue_t *src, ce_queue_t *trg)
{
    ce_action_t *a;
    
    CE_CHECK(check_queue(src));
    CE_CHECK(check_queue(trg));
    
    if (0 == src->len) {
	assert(NULL == src->head && NULL == src->tail);
	return;
    }

    while(src->len >0) {
	a = ce_queue_pop(src);
	ce_queue_add_tail(trg, a);
    }

    CE_CHECK(check_queue(src));
    CE_CHECK(check_queue(trg));
}

void ce_queue_clear(ce_pool_t *pool, ce_queue_t *q)
{
    ce_action_t *tmp, *next;
    
    TRACE("ce_queue_clear(");
    if (q->head != NULL) {
	tmp = q->head;
	while(tmp != NULL){
	    next = tmp->next ;
	    ce_action_return_to_pool(pool, tmp);
	    tmp = next;
	}
    }
    TRACE(")");

    memset(q, 0, sizeof(ce_queue_t));
}


void ce_queue_free(ce_pool_t *pool, ce_queue_t *q)
{
    ce_queue_clear(pool, q);
    ce_free(q) ;
}

/**************************************************************/
/**************************************************************/



