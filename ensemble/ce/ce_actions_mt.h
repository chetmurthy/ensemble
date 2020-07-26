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

 * Ts_join : ce_Join

 * Ts_ADDSOCKRECV : ce_AddSockRecv

 * TS_RMVSOCKRECV : ce_RmvSockRecv
*/
typedef struct ce_mt_action_t {
    enum {
	MT_CAST,
	MT_SEND,
	MT_SEND1,
	MT_LEAVE,
	MT_PROMPT,
	MT_SUSPECT,
	MT_XFERDONE,
	MT_REKEY,
	MT_PROTOCOL,
	MT_PROPERTIES,
	
	MT_JOIN,
	MT_ADDSOCKRECV,
	MT_RMVSOCKRECV

    } type;
    ce_appl_intf_t *c_appl;
    union {
	struct {
	    int num;
	    ce_iovec_array_t iovl;
	} cast;
	struct {
	    int num_dests;
	    ce_rank_array_t dests ;
	    int num;
	    ce_iovec_array_t iovl;
	} send ;
	struct {
	    ce_rank_t dest ;
	    int num;
	    ce_iovec_array_t iovl;
	} send1 ;
	struct {
	    int num;
	    ce_rank_array_t members ;
	} suspect;
	char* proto ;
	char* properties ;
	struct {
	    ce_len_t len;
	    ce_data_t buf;
	} flat_cast;
	struct {
	    int num_dests;
	    ce_rank_array_t dests;
	    ce_len_t len;
	    ce_data_t buf;
	} flat_send;
	struct {
	    ce_rank_t dest;
	    ce_len_t len;
	    ce_data_t buf;
	} flat_send1;
	struct {
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

ce_mt_action_t *ce_mt_appl_cast(
    ce_mt_queue_t*,
    ce_appl_intf_t *,
    int, ce_iovec_array_t
    ) ;

ce_mt_action_t *ce_mt_appl_send(
    ce_mt_queue_t*,
    ce_appl_intf_t *,
    int, ce_rank_array_t, int, ce_iovec_array_t
    );

ce_mt_action_t *ce_mt_appl_send1(
    ce_mt_queue_t*,
    ce_appl_intf_t *,
    ce_rank_t dest, int, ce_iovec_array_t
    ) ;

ce_mt_action_t *ce_mt_appl_leave(
    ce_mt_queue_t*,
    ce_appl_intf_t *
    ) ;

ce_mt_action_t *ce_mt_appl_prompt(
    ce_mt_queue_t*,
    ce_appl_intf_t *
    ) ;

ce_mt_action_t *ce_mt_appl_suspect(
    ce_mt_queue_t*,
    ce_appl_intf_t *,
    int, ce_rank_array_t suspects
    ) ;

ce_mt_action_t *ce_mt_appl_xfer_done(
    ce_mt_queue_t*,
    ce_appl_intf_t *
    ) ;

ce_mt_action_t *ce_mt_appl_rekey(
    ce_mt_queue_t*,
    ce_appl_intf_t *
    ) ;

ce_mt_action_t *ce_mt_appl_protocol(
    ce_mt_queue_t*,
    ce_appl_intf_t *,
    char *proto
    ) ;

ce_mt_action_t *ce_mt_appl_properties(
    ce_mt_queue_t*,
    ce_appl_intf_t *,
    char *properties
    ) ;

ce_mt_action_t *ce_mt_appl_join(
    ce_mt_queue_t*,
    ce_appl_intf_t *,
    ce_jops_t *ops
    );
				       
ce_mt_action_t *ce_mt_appl_AddSockRecv(
    ce_mt_queue_t*,
    CE_SOCKET socket, ce_handler_t handler, ce_env_t env
    );

ce_mt_action_t *ce_mt_appl_RmvSockRecv(
    ce_mt_queue_t*,
    CE_SOCKET socket
    );

//void ce_action_free(ce_mt_action_t*) ;


#endif /* __CE_ACTIONS_MT_H__ */
