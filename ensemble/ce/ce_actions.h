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
typedef struct ce_action_t {
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
      APPL_PROPERTIES
    } type;
  union {
    struct {
      ce_len_t len ;
      ce_data_t data ;
    } cast;
    struct {
      ce_rank_array_t dests ;
      ce_len_t len ;
      ce_data_t data ;
    } send ;
    struct {
      ce_rank_t dest ;
      ce_len_t len ;
      ce_data_t data ;
    } send1 ;
    ce_rank_array_t suspects ;
    char* proto ;
    char* properties ;
  } u ;
} ce_action_t ;

ce_action_t *ce_appl_cast(ce_len_t, ce_data_t) ;
ce_action_t *ce_appl_send(ce_rank_array_t, ce_len_t, ce_data_t);
ce_action_t *ce_appl_send1(ce_rank_t dest, ce_len_t, ce_data_t) ;
ce_action_t *ce_appl_leave(void) ;
ce_action_t *ce_appl_prompt(void) ;
ce_action_t *ce_appl_suspect(ce_rank_array_t suspects) ;
ce_action_t *ce_appl_xfer_done(void) ;
ce_action_t *ce_appl_rekey(void) ;
ce_action_t *ce_appl_protocol(char *proto) ;
ce_action_t *ce_appl_properties(char *properties) ;
	    
void ce_action_free(ce_action_t*) ;


/* The type of message queues. The type is obscured to prevent outside
 * access. The struct itself is defined in ce_actions.c
 */
typedef struct ce_queue_t ce_queue_t ; 

ce_queue_t* ce_create_queue(void);
ce_bool_t ce_queue_empty(ce_queue_t*) ;
int ce_queue_length(ce_queue_t*) ;
void ce_queue_add(ce_queue_t*, ce_action_t*) ;
void ce_queue_clear(ce_queue_t*) ;
void ce_queue_free(ce_queue_t*) ;
value Val_queue(ce_queue_t*);

#endif /* __CE_ACTIONS_H__ */
