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
/****************************************************************************/
/* CE_INBOARD_C.C */
/* Author:  Ohad Rodeh, Aug. 2001. */
/* Based on code by: Alexey Vaysburd, and Mark Hayden.  */
/* This provides the raw IOV interface*/
/****************************************************************************/
#include "ce_internal.h"
#include "ce_trace.h"
#include <stdio.h>
/****************************************************************************/
#define NAME "CE_INBOARD_C"
/****************************************************************************/
/* These functions are exported from ML.
 */
static value *ce_add_sock_recv_v = NULL;
static value *ce_rmv_sock_recv_v = NULL;
static value *ce_async_v = NULL;
static value *ce_join_v = NULL;
static value *ce_main_loop_v = NULL;
/****************************************************************************/
/* Global variables
 */

/* A pool of free actions
 */
static ce_pool_t *pool;

ce_pool_t *ce_st_get_allocation_pool(void)
{
    return pool;
}

// Forward declaration
static void ce_BlockOk_full(
    ce_appl_intf_t *c_appl,
    ce_bool_t flag
    );
/****************************************************************************/

value ce_actions_of_queue(ce_queue_t *q)
{
    value ret;
    //  printf("ce_actions_of_queue("); fflush (stdout);
//    TRACE("Val_queue(");
    ret = Val_queue(q);
//    TRACE(".");
    ce_queue_clear(pool, q);
//    TRACE(")");
    
    return(ret);
}

/* Called from ML to get the pending actions of an endpoint.
 */
/*
value ce_GetActions(value c_appl_v)
{
    ce_appl_intf_t *intf = C_appl_val(c_appl_v);
    
    intf->req_heartbeat = 0;
    return (ce_actions_of_queue(intf->aq));
}
*/

void ce_Async(ce_appl_intf_t *c_appl)
{
    callback (*ce_async_v,Val_c_appl(c_appl));
}

/****************************************************************************/
value ce_Exit_cbd (value c_appl_v)
{
    ce_appl_intf_t *c_appl = C_appl_val(c_appl_v);
    (c_appl->exit) (c_appl->env);
    ce_intf_free(pool, c_appl);
    
    return (Val_unit);
}

value ce_Install_cbd (value c_appl_v, value ls_v, value vs_v)
{
    ce_appl_intf_t *c_appl;
    ce_local_state_t *ls;
    ce_view_state_t *vs; 
    
    TRACE("ce_Install_cbd("); 
    c_appl = C_appl_val(c_appl_v);

    assert(check_queue(c_appl->aq));
    ls = (ce_local_state_t*) ce_malloc(sizeof(ce_local_state_t));
    vs = (ce_view_state_t*) ce_malloc(sizeof(ce_view_state_t));
    memset((char*)ls, 0, sizeof(ce_local_state_t));
    memset((char*)vs, 0, sizeof(ce_view_state_t));
    ViewFull_val(ls_v, vs_v, ls, vs);
    c_appl->req_heartbeat = 1;
    c_appl->blocked = 0;
    if (c_appl->joining == 1) c_appl->joining = 0;
    (c_appl->install) (c_appl->env, ls, vs);
    ce_view_full_free(ls,vs);
    c_appl->req_heartbeat = 0;
    TRACE(")");

    return (ce_actions_of_queue(c_appl->aq));
}

value ce_FlowBlock_cbd (value c_appl_v, value rank_opt_v, value onoff_v)
{
    ce_appl_intf_t *c_appl;
    ce_bool_t onoff = Bool_val(onoff_v);
    int rank = -1;
    
    TRACE("ce_FlowBlock_cbd(");
	c_appl = C_appl_val(c_appl_v);
	assert(check_queue(c_appl->aq));
    if (Int_val(rank_opt_v) == 0) {
	TRACE("None");
	rank = -1;
    } else {
	TRACE("Some");
	rank = Int_val (Field(rank_opt_v,0));
    }
    c_appl->req_heartbeat = 1;
    TRACE_D("flow_control onoff=", onoff);
    (c_appl->flow_block) (c_appl->env, rank, onoff);
    c_appl->req_heartbeat = 0;
    
    TRACE(")");
    return Val_unit;
}

value ce_Block_cbd(value c_appl_v)
{
    ce_appl_intf_t *c_appl = C_appl_val(c_appl_v);
    
    assert(check_queue(c_appl->aq));
//    TRACE("ce_Block_cbd"); 

    c_appl->req_heartbeat = 1;
    (c_appl->block) (c_appl->env);
    c_appl->req_heartbeat = 0;

    /* The application is going to send a BlockOk by itself. We tell
     * Ensemble to wait for the application to do so.
     *
     * Note: in this case, it is still legal for the application to
     * send messages.

     */
    if (c_appl->async_block_ok
	&& 0 == c_appl->blocked) 
	ce_BlockOk_full(c_appl, 0);
    else
	c_appl->blocked = 1;

    return (ce_actions_of_queue(c_appl->aq));
}

/*
  value
  ce_Disable_cbd(value c_appl_v) {
  ce_appl_intf_t *c_appl = C_appl_val(c_appl_v);
  
  TRACE("ce_Disblae_cbd"); 
  c_appl->req_heartbeat = 1;
  (c_appl->disable) (c_appl->env);
  c_appl->req_heartbeat = 0;
  
  return Val_unit;
  }
*/

/* We do not return a list of actions, because polling
 * is done on the ML side right after this callback.
 */
value ce_Heartbeat_cbd(value c_appl_v, value time_v)
{
    ce_appl_intf_t *c_appl = C_appl_val(c_appl_v);
    double time = Double_val(time_v);
    
    assert(check_queue(c_appl->aq));
//    TRACE("ce_Heartbeat_cbd"); 
    c_appl->req_heartbeat = 1;

    /* If this is not an async request, then call the application callback.
     */
    if (0 == c_appl->req_async)
	(c_appl->heartbeat) (c_appl->env, time);
    c_appl->req_async = 0;
    c_appl->req_heartbeat = 0;
    
    return (ce_actions_of_queue(c_appl->aq));
}

value ce_ReceiveCast_cbd(value c_appl_v, value origin_v, value iovl_v)
{
    ce_appl_intf_t *c_appl = C_appl_val(c_appl_v);
    ce_bool_t origin = Int_val(origin_v);
    ce_iovec_array_t iovl = Iovl_val(iovl_v);
    int num = Wosize_val(iovl_v);
    
    TRACE("ce_ReceiveCast_cbd(");
    assert(check_queue(c_appl->aq));
    /* The application does not own the msg.
     */
    c_appl->req_heartbeat = 1;
    (c_appl->receive_cast) (c_appl->env, origin, num, iovl);

    c_appl->req_heartbeat = 0;
    TRACE(")");
    
    /* No need to free the iovl, it is static.
     */
    //free(iovl);
    
    return (ce_actions_of_queue(c_appl->aq));
}

value ce_ReceiveSend_cbd(value c_appl_v, value origin_v, value iovl_v)
{
    ce_appl_intf_t *c_appl = C_appl_val(c_appl_v);
    ce_bool_t origin = Int_val(origin_v);
    ce_iovec_array_t iovl = Iovl_val(iovl_v);
    int num = Wosize_val(iovl_v);
    
//    TRACE("ce_ReceiveSend_cbd"); 
    assert(check_queue(c_appl->aq));
    c_appl->req_heartbeat = 1;
    (c_appl->receive_send) (c_appl->env, origin, num, iovl);  
    c_appl->req_heartbeat = 0;
    
    /* No need to free the iovl, it is static.
     */
    //free(iovl);
    
    return (ce_actions_of_queue(c_appl->aq));
}

/****************************************************************************/
/* For a customizable interface to ML exception and print handling.
 */
static void (*MLPrinter)(char *) = NULL ;

void
ce_st_MLPrintOverride(
    void (*handler)(char *msg)
    )
{
    MLPrinter = handler ;
}

value
ce_st_MLDoPrint(value msg_v)
{
    if (MLPrinter != NULL) {
	MLPrinter(String_val(msg_v)) ;
	return Val_true ;
    }
    return Val_false ;
}

static void (*MLHandler)(char *) = NULL ;

void ce_st_MLUncaughtException(
    void (*handler)(char *info)
    )
{
    MLHandler = handler ;
}

value ce_st_MLHandleException(value msg_v)
{
    if (MLHandler != NULL) {
	MLHandler(String_val(msg_v)) ;
	exit(1) ;
    }
    return Val_false ;
}

/*****************************************************************************/
/* The set of supported actions in a group context. 
 */

/* Request an asynchrous call if this hasn't been done already. 
 */
void ce_st_check_heartbeat(ce_appl_intf_t *c_appl)
{
    if (!(c_appl -> req_heartbeat)){ 
	c_appl->req_heartbeat = 1; 
	c_appl->req_async = 1;
	ce_Async(c_appl); 
    }
}

static void
report_err(ce_appl_intf_t *c_appl)
{
    
    if (c_appl->joining)
	printf("Operation while group is joining (id=%d, ptr=%x)\n",
	       c_appl->id, (int)c_appl);
    if (c_appl->leaving)
	printf("Operation while group is leaving (id=%d, ptr=%x)\n",
	       c_appl->id, (int)c_appl);
    if (c_appl->blocked)
	printf("Operation while group is blocked (id=%d, ptr=%x)\n",
	       c_appl->id, (int)c_appl);
    exit(1);
}

INLINE static void
check_valid(ce_appl_intf_t *c_appl)
{
    if (c_appl->blocked || c_appl->joining || c_appl->leaving) {
	report_err(c_appl);
    }
}


void ce_st_Cast(
    ce_appl_intf_t *c_appl,
    ce_len_t num,
    ce_iovec_array_t iovl
    )
{
    check_valid(c_appl);
    ce_st_check_heartbeat(c_appl);
    TRACE("cast");
    ce_action_cast(pool, c_appl->aq, num, iovl);
}

void ce_st_Send(
    ce_appl_intf_t *c_appl,
    int num_dests,
    ce_rank_array_t dests,
    int num,
    ce_iovec_array_t iovl
    )
{
    check_valid(c_appl);
    ce_st_check_heartbeat(c_appl);
    ce_action_send(pool, c_appl->aq, num_dests, dests, num, iovl);
}

void ce_st_Send1(
    ce_appl_intf_t *c_appl,
    ce_rank_t dest,
    int num,
    ce_iovec_array_t iovl
    )
{
    check_valid(c_appl);
    ce_st_check_heartbeat(c_appl);
    ce_action_send1(pool, c_appl->aq, dest, num, iovl);
}


void ce_st_Leave(
    ce_appl_intf_t *c_appl
    )
{
    check_valid(c_appl);
    ce_st_check_heartbeat(c_appl);
    c_appl->leaving = 1;
    ce_action_leave(pool, c_appl->aq);
}

void ce_st_Prompt(
    ce_appl_intf_t *c_appl
    )
{
    check_valid(c_appl);
    ce_st_check_heartbeat(c_appl);
    ce_action_prompt(pool, c_appl->aq);
}

void ce_st_Suspect(
    ce_appl_intf_t *c_appl,
    int num,
    ce_rank_array_t suspects
    )
{
    check_valid(c_appl);
    ce_st_check_heartbeat(c_appl);
    ce_action_suspect(pool, c_appl->aq, num, suspects);
}

void ce_st_XferDone(
    ce_appl_intf_t *c_appl
    )
{
    check_valid(c_appl);
    ce_st_check_heartbeat(c_appl);
    TRACE("XferDone");
    ce_action_xfer_done(pool, c_appl->aq);
}

void ce_st_Rekey(
    ce_appl_intf_t *c_appl
    )
{
    check_valid(c_appl);
    ce_st_check_heartbeat(c_appl);
    TRACE("Rekey");
    ce_action_rekey(pool, c_appl->aq);
}

void ce_st_ChangeProtocol(
    ce_appl_intf_t *c_appl,
    char *proto
    )
{
    check_valid(c_appl);
    ce_st_check_heartbeat(c_appl);
    ce_action_protocol(pool, c_appl->aq, proto);
}

void ce_st_ChangeProperties(
    ce_appl_intf_t *c_appl,
    char *properties
    )
{
    check_valid(c_appl);
    ce_st_check_heartbeat(c_appl);
    ce_action_properties(pool, c_appl->aq, properties);
}

/* The application is now blocked
 */
void ce_st_BlockOk(
    ce_appl_intf_t *c_appl
    )
{
    if (!c_appl->async_block_ok)
	ce_panic("the application sent a BlockOk although it hasn't joined with an async_block_ok flag");
    if (c_appl->blocked)
	ce_panic("application is already blocked. Second BlockOk.");
    check_valid(c_appl);
    ce_st_check_heartbeat(c_appl);
    c_appl->blocked = 1;

    TRACE("block_ok");
    ce_action_block_ok(pool, c_appl->aq, 1);
}


static void ce_BlockOk_full(
    ce_appl_intf_t *c_appl,
    ce_bool_t flag
    )
{
    TRACE("block_ok_full");
    ce_action_block_ok(pool, c_appl->aq, flag);
}

/*****************************************************************************/
/* Listening to sockets. 
 */

/* This function gets called by ML when input becomes available
 * on the specified socket. The registered C-upcall is then called
 * with its environment variable. 
 */
value
ce_PassSock(value handler_v, value env_v)
{
    ce_handler_t handler;
    ce_env_t env;
    
    TRACE("ce_PassSock(");
    handler = Handler_val(handler_v);
    env = Env_val(env_v);
    (*handler)(env);
    TRACE(")");
    return Val_int(0);
}

void
ce_st_AddSockRecv(ocaml_skt_t socket, ce_handler_t handler, ce_env_t env)
{
    CAMLparam0();
    CAMLlocal3(socket_v,env_v, handler_v);
    
    socket_v = Val_socket(socket);
    env_v = Val_env(env);
    handler_v = Val_handler(handler);
    callback3(*ce_add_sock_recv_v, socket_v, handler_v, env_v);
    
    CAMLreturn0;
}

void
ce_st_RmvSockRecv(ocaml_skt_t socket)
{
    CAMLparam0();
    CAMLlocal1(socket_v);
    
    socket_v = Val_socket(socket);
    callback(*ce_rmv_sock_recv_v, socket_v);
    
    CAMLreturn0;
}
/*****************************************************************************/

/* Initialize the interface, start Ensemble/OCAML if necessary.
 * Pass the command line arguements to Ensemble. 
 */ 
void ce_st_Init(int argc, char **argv)
{
    char **ml_args;

    TRACE("ce_st_Init");
    ml_args = ce_process_args(argc, argv);
    caml_startup(ml_args) ;
    
    /* Read the set of exported CAML callbacks.
     */
    ce_add_sock_recv_v = caml_named_value((char*) "ce_add_sock_recv_v");
    ce_rmv_sock_recv_v = caml_named_value((char*) "ce_rmv_sock_recv_v");
    ce_async_v = caml_named_value((char*)"ce_async_v") ;
    ce_join_v = caml_named_value((char*)"ce_join_v") ;
    ce_main_loop_v = caml_named_value((char*)"ce_main_loop_v") ;

    /* Initialize global data structures
     */
    pool = ce_pool_create();
}

/* Join a group
 */
void
ce_st_Join(ce_jops_t *jops, ce_appl_intf_t *c_appl)
{
    CAMLparam0();
    CAMLlocal2(jops_v, c_appl_v);
    
    check_valid(c_appl);
    TRACE("ce_st_Join");

    /* Pass the async_block_ok flag into the c_appl state. This will allow
     * using it in the next uses of the endpoint. 
     */
    c_appl->async_block_ok = jops->async_block_ok ;
    c_appl->joining = 1;
    if (ce_join_v == NULL){
	printf("Main loop callback not initialized yet. You need to do"
	       "ce_process_args first.\n");
	exit(1);
    }
    
    jops_v = Val_jops(jops);
    c_appl_v = Val_c_appl(c_appl);
//    printf("c_appl=%d\n", (int) c_appl);
    TRACE("before the callback"); 
    callback2(*ce_join_v, c_appl_v, jops_v);
    CAMLreturn0;
}


/* Start the Ensemble main_loop
 */
void
ce_st_Main_loop (void)
{
    if (ce_main_loop_v == NULL){
	printf("Main loop callback not initialized yet. You need to do"
	       "ce_process_args first.\n");
	exit(1);
    }
    TRACE("ce_st_Main_loop");
    callback(*ce_main_loop_v, Val_unit);
}

/****************************************************************************/
