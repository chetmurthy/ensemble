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
/* CE_APPL_INTF.H: application interface */
/* Author: Ohad Rodeh 8/2001 */
/* Based on code by  Mark Hayden from the CEnsemble system */
/**************************************************************/

#ifndef __CE_ACTIONS_H__
#define __CE_ACTIONS_H__

#include "ce_internal.h"

/* ACTION: The type of actions an application can take.
 * These are typically returned from callbacks as lists of
 * actions to be taken.

 * [NOTE: XferDone, Protocol, Rekey, and Migrate are not
 * implemented by all protocol stacks.  Dump and Block are
 * undocumented actions used for internal Ensemble
 * services.]

 * Cast(msg): Broadcast a message to entire group

 * Send(dests,msg): Send a message to subset of group.

 * Send1(dest,msg): Send a message to group member.

 * Leave: Leave the group.

 * Prompt: Prompt for a view change.

 * Suspect: Tell the protocol stack about suspected failures
 * in the group.

 * XferDone: Mark end of a state transfer.

 * Rekey: Request that the group be rekeyed.
 
 * Protocol(proto): Request a protocol switch.  Will
 * cause a view change to new protocol stack.
 
 * Properties : The same, but with a specified set of properties.
 
*/

typedef struct ce_action_t ce_action_t ;

struct ce_action_t {
    ce_action_t *next;         /* Pointer to the next action on the chain */
    enum {
	APPL_CAST,
	APPL_SEND,
	APPL_SEND1,
	APPL_LEAVE,
	APPL_PROMPT,
	APPL_SUSPECT,
	APPL_XFERDONE,
	APPL_REKEY,
	APPL_PROTOCOL,
	APPL_PROPERTIES,
	APPL_BLOCK_OK
    } type;
    union {
	struct {
	    int num;
	    ce_iovec_t iovl[CE_IOVL_MAX_SIZE];
	} cast;
	struct {
	    int num_dests;
	    ce_rank_t dests[CE_DESTS_MAX_SIZE] ;
	    int num;
	    ce_iovec_t iovl[CE_IOVL_MAX_SIZE];
	} send ;
	struct {
	    ce_rank_t dest ;
	    int num;
	    ce_iovec_t iovl[CE_IOVL_MAX_SIZE];
	} send1 ;
	struct {
	    ce_rank_t members[CE_DESTS_MAX_SIZE] ;
	    int num;
	} suspect;
	char proto[CE_PROTOCOL_MAX_SIZE] ;
	char properties[CE_PROPERTIES_MAX_SIZE] ;
	ce_bool_t block_ok;
    } u ;
};

typedef struct ce_pool_t {
    int num_free ;
    ce_action_t *head;
} ce_pool_t;

ce_pool_t *ce_pool_create(void);

/* Allocate space for an action from a pool. Allocate more memory using malloc if necessary.
 */
ce_action_t* ce_action_alloc_from_pool(ce_pool_t *pool);

/* Return an action to a pool
 */
void ce_action_return_to_pool(ce_pool_t *pool, ce_action_t *action);

/* Move free items from one pool to the other. 
 */
void ce_pool_move(ce_pool_t *src, ce_pool_t *trg, int num);

/* The type of message queues. 
 */
typedef struct ce_queue_t ce_queue_t;

struct ce_queue_t {
    int len;             /* Total number of queued actions */
    ce_action_t *head;   /* Pointer to the first queued action*/
    ce_action_t *tail;   /* Pointer to the last one */
} ;



ce_queue_t* ce_queue_create(void);
ce_bool_t ce_queue_empty(ce_queue_t*) ;
int  ce_queue_length(ce_queue_t*) ;

/* Clear this queue, and return the actions to the specified pool.
 */
void ce_queue_clear(ce_pool_t *pool, ce_queue_t *q);

/* Release this queue, and return the actions to the specified pool.
 */
void ce_queue_free(ce_pool_t *pool, ce_queue_t *q);

/* Enque an action
 */
void ce_queue_add_tail(ce_queue_t *q, ce_action_t *a);

/* Move all actions from source queue to destination.
 */
void ce_queue_pour(ce_queue_t *src, ce_queue_t *trg);

/* Check the sanity of a queue
 */
int check_queue(ce_queue_t *q);
    
void ce_action_cast(ce_pool_t *pool, ce_queue_t *q, int num, ce_iovec_array_t iovl) ;
void ce_action_send(ce_pool_t *pool, ce_queue_t*q,  int num_dests, ce_rank_array_t dests,
		    int num, ce_iovec_array_t iovl);
void ce_action_send1(ce_pool_t *pool, ce_queue_t*, ce_rank_t dest, int num, ce_iovec_array_t iovl) ;
void ce_action_leave(ce_pool_t *pool, ce_queue_t *q) ;
void ce_action_prompt(ce_pool_t *pool, ce_queue_t *q) ;
void ce_action_suspect(ce_pool_t *pool, ce_queue_t *q, int num, ce_rank_array_t suspects) ;
void ce_action_xfer_done(ce_pool_t *pool, ce_queue_t *q) ;
void ce_action_rekey(ce_pool_t *pool, ce_queue_t *q) ;
void ce_action_protocol(ce_pool_t *pool, ce_queue_t *q, char *proto) ;
void ce_action_properties(ce_pool_t *pool, ce_queue_t *q, char *properties) ;
void ce_action_block_ok(ce_pool_t *pool, ce_queue_t *q, ce_bool_t flag);

#endif /* __CE_ACTIONS_H__ */
