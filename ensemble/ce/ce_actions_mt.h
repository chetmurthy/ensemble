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
/* CE_ACTIONS_MT.H: application interface */
/* Author: Ohad Rodeh 8/2001 */
/* Based on code by  Mark Hayden from the CEnsemble system */
/**************************************************************/

#ifndef __CE_ACTIONS_MT_H__
#define __CE_ACTIONS_MT_H__

#include "ce.h"

/* ACTION: The type of actions an application can take.
 * These are typically returned from callbacks as lists of
 * actions to be taken.

 * Ts_join : ce_Join

*/
typedef struct ce_mt_action_t {
    enum {
	MT_JOIN,
    } type;
    union {
	struct {
	    ce_appl_intf_t *c_appl;
	    ce_jops_t *ops;
	} join;
	struct {
	    CE_SOCKET socket;
	    ce_handler_t handler;
	    ce_env_t env;
	} add_sock;
	struct {
	    CE_SOCKET socket;
	} rmv_sock;
    } u ;
} ce_mt_action_t ;

/* The type of message queues. The type is obscured to prevent outside
 * access. The struct itself is defined in ce_actions.c
 */
typedef struct ce_mt_queue ce_mt_queue_t;

struct ce_mt_queue {
  ce_mt_action_t *arr ;
  int len ;
  int alen ;		/* power of 2 */
} ;


ce_mt_queue_t* ce_mt_queue_create(void);
ce_bool_t ce_mt_queue_empty(ce_mt_queue_t*) ;
int ce_mt_queue_length(ce_mt_queue_t*) ;
ce_mt_action_t* ce_mt_queue_alloc(ce_mt_queue_t *q);
void ce_mt_queue_clear(ce_mt_queue_t*) ;
void ce_mt_queue_free(ce_mt_queue_t*) ;
void ce_mt_queue_copy_and_clear(ce_mt_queue_t *src, ce_mt_queue_t *trg);

ce_mt_action_t *ce_mt_appl_join(
    ce_mt_queue_t*,
    ce_appl_intf_t *,
    ce_jops_t *ops
    );
				       
//void ce_action_free(ce_mt_action_t*) ;

/**************************************************************/

#endif /* __CE_ACTIONS_MT_H__ */
