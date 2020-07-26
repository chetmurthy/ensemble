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

ce_mt_action_t *ce_mt_appl_join(ce_mt_queue_t *q, ce_appl_intf_t *c_appl,
				ce_jops_t *ops)
{
    ce_mt_action_t *a = ce_mt_queue_alloc(q);
    ce_jops_t *new_jops;
    
    TRACE("MT_JOIN");
    new_jops = (ce_jops_t*) ce_malloc(sizeof(ce_jops_t));
    ce_jops_copy(ops, new_jops);    
    a->type = MT_JOIN ;
    a->u.join.c_appl = c_appl;
    a->u.join.ops = new_jops;
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
    q = (ce_mt_queue_t*) ce_malloc(sizeof(ce_mt_queue_t));
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

void ce_mt_queue_free(ce_mt_queue_t *q)
{
    free(q->arr) ;
    free(q) ;
}

/* There is no need to free the individual items, because they
 * are passed for processing to the Ensemble thread, where they will
 * be freed. 
 */
void ce_mt_queue_clear(ce_mt_queue_t *q)
{
    TRACE("ce_mt_queue_clear(");
    memset(q->arr, 0, SIZE * q->len) ;
    q->len = 0 ;
    TRACE(")");
}

void ce_mt_queue_copy_and_clear(ce_mt_queue_t *src, ce_mt_queue_t *trg)
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



