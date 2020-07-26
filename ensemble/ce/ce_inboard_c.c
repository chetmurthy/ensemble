/****************************************************************************/
/* CE_INBOARD_C.C */
/* Author:  Ohad Rodeh, Aug. 2001. */
/* Based on code by: Alexey Vaysburd, and Mark Hayden.  */
/****************************************************************************/
#include "ce_internal.h"
#include "ce_trace.h"
#include <stdio.h>
/****************************************************************************/
#define NAME "CE_INBOARD_C"
/****************************************************************************/
/* These functions are exported from ML.
 */
value *ce_add_sock_recv_v = NULL;
value *ce_rmv_sock_recv_v = NULL;
value *ce_async_v = NULL;
value *ce_join_v = NULL;
value *ce_main_loop_v = NULL;
/****************************************************************************/

value
ce_actions_of_queue(ce_queue_t *q){
  value ret;
  //  printf("ce_actions_of_queue("); fflush (stdout);
  TRACE("Val_queue(");
  ret = Val_queue(q);
  TRACE(".");
  ce_queue_clear(q);
  TRACE(")");

  return(ret);
}

/* Called from ML to get the pending actions of an endpoint.
 */
value
ce_GetActions(value c_appl_v){
  ce_appl_intf_t *intf = C_appl_val(c_appl_v);

  intf->req_heartbeat = 0;
  return (ce_actions_of_queue(intf->aq));
}

void
ce_Async(ce_appl_intf_t *intf){
  callback (*ce_async_v,Val_c_appl(intf));
}

/****************************************************************************/
value
ce_Exit_cbd (value c_appl_v) {
  ce_appl_intf_t *intf = C_appl_val(c_appl_v);
  (intf->exit) (intf->env);
  ce_intf_free(intf);

  return (Val_unit);
}

value
ce_Install_cbd (value c_appl_v, value ls_v, value vs_v) {
  ce_appl_intf_t *intf = C_appl_val(c_appl_v);
  ce_local_state_t *ls;
  ce_view_state_t *vs; 

  TRACE("ce_Install_cbd"); 
  ls = record_create(ce_local_state_t*,ls);
  vs = record_create(ce_view_state_t*,vs);
  record_clear(ls);
  record_clear(vs);
  ViewFull_val(ls_v, vs_v, ls, vs);
  intf->req_heartbeat = 1;
  (intf->install) (intf->env, ls, vs);
  intf->req_heartbeat = 0;
  return (ce_actions_of_queue(intf->aq));
}

value
ce_FlowBlock_cbd (value c_appl_v, value rank_opt_v, value onoff_v) {
  ce_appl_intf_t *intf = C_appl_val(c_appl_v);
  ce_bool_t onoff = Val_bool(onoff_v);
  int rank = -1;
  
  switch (Tag_val(rank_opt_v)) {
  case 0: /* None */
    break;
  case 1: /* Some(rank) */
    rank = Int_val (Field(rank_opt_v,0));
  }
  intf->req_heartbeat = 1;
  (intf->flow_block) (intf->env, rank, onoff);
  intf->req_heartbeat = 0;

  return Val_unit;
}

value
ce_Block_cbd(value c_appl_v) {
  ce_appl_intf_t *intf = C_appl_val(c_appl_v);

  TRACE("ce_Block_cbd"); 
  intf->req_heartbeat = 1;
  (intf->block) (intf->env);
  intf->req_heartbeat = 0;

  return(ce_actions_of_queue(intf->aq));
}

value
ce_Heartbeat_cbd(value c_appl_v, value time_v) {
  ce_appl_intf_t *intf = C_appl_val(c_appl_v);
  double time = Double_val(time_v);

  TRACE("ce_Heartbeat_cbd"); 
  intf->req_heartbeat = 1;
  (intf->heartbeat) (intf->env, time);
  intf->req_heartbeat = 0;

  return(ce_actions_of_queue(intf->aq));
}

value
ce_ReceiveCast_cbd(value c_appl_v, value origin_v, value buf_v, value ofs_v, value len_v){
  ce_appl_intf_t *intf = C_appl_val(c_appl_v);
  ce_bool_t origin = Int_val(origin_v);
  char *buf = String_val(buf_v);
  int ofs = Int_val(ofs_v);
  int len = Int_val(len_v);
  
  TRACE("ce_ReceiveCast_cbd"); 
  /* The application does not own the msg.
   */
  intf->req_heartbeat = 1;
  (intf->receive_cast) (intf->env, origin, len, (char*)(buf + ofs));  
  intf->req_heartbeat = 0;

  return (ce_actions_of_queue(intf->aq));
}

value
ce_ReceiveSend_cbd(value c_appl_v, value origin_v, value buf_v, value ofs_v, value len_v){
  ce_appl_intf_t *intf = C_appl_val(c_appl_v);
  ce_bool_t origin = Int_val(origin_v);
  char *buf = String_val(buf_v);
  int ofs = Int_val(ofs_v);
  int len = Int_val(len_v);

  TRACE("ce_ReceiveSend_cbd"); 
  intf->req_heartbeat = 1;
  (intf->receive_send) (intf->env, origin, len, (char*)(buf + ofs));  
  intf->req_heartbeat = 0;

  return (ce_actions_of_queue(intf->aq));
}

/****************************************************************************/
/* For a customizable interface to ML exception and print handling.
 */
static void (*MLPrinter)(char *) = NULL ;

void
ce_MLPrintOverride(
	void (*handler)(char *msg)
) {
    MLPrinter = handler ;
}

value
ce_MLDoPrint(value msg_v) {
  if (MLPrinter != NULL) {
    MLPrinter(String_val(msg_v)) ;
    return Val_true ;
  }
  return Val_false ;
}

static void (*MLHandler)(char *) = NULL ;

void
ce_MLUncaughtException(
	void (*handler)(char *info)
) {
    MLHandler = handler ;
}

value
ce_MLHandleException(value msg_v) {
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
#define check_heartbeat(c_appl){ \
  if (!(c_appl -> req_heartbeat)) { \
    c_appl->req_heartbeat = 1; \
    ce_Async(c_appl); \
  } \
}

void ce_Cast(
	ce_appl_intf_t *c_appl,
	ce_len_t len,
	ce_data_t data
	) {
  check_heartbeat(c_appl);
  ce_queue_add(c_appl->aq, ce_appl_cast(len,data));
}

void ce_Send(
	ce_appl_intf_t *c_appl,
	ce_rank_array_t dests,
	ce_len_t len,
	ce_data_t data
	) {
  check_heartbeat(c_appl);
  ce_queue_add(c_appl->aq, ce_appl_send(dests, len, data));
}

void ce_Send1(
	ce_appl_intf_t *c_appl,
	ce_rank_t dest,
	ce_len_t len,
	ce_data_t data
	) {
  check_heartbeat(c_appl);
  ce_queue_add(c_appl->aq, ce_appl_send1(dest, len, data));
}


void
ce_Leave(
	 ce_appl_intf_t *c_appl
) {
  check_heartbeat(c_appl);
  ce_queue_add(c_appl->aq, ce_appl_leave());
}

void ce_Prompt(
	ce_appl_intf_t *c_appl
	) {
  check_heartbeat(c_appl);
  ce_queue_add(c_appl->aq, ce_appl_prompt());
}

void ce_Suspect(
	ce_appl_intf_t *c_appl,
	ce_rank_array_t suspects
	){
  check_heartbeat(c_appl);
  ce_queue_add(c_appl->aq, ce_appl_suspect(suspects));
}

void ce_XferDone(
	ce_appl_intf_t *c_appl
	) {
  check_heartbeat(c_appl);
  ce_queue_add(c_appl->aq, ce_appl_xfer_done());
}

void ce_ChangeProtocol(
	 ce_appl_intf_t *c_appl,
	 char *proto
	) {
  check_heartbeat(c_appl);
  ce_queue_add(c_appl->aq, ce_appl_protocol(proto));
}

void ce_ChangeProperties(
         ce_appl_intf_t *c_appl,
	 char *properties
	) {
  check_heartbeat(c_appl);
  ce_queue_add(c_appl->aq, ce_appl_properties(properties));
}

/*****************************************************************************/
/* Listening to sockets. 
 */

/* This function gets called by ML when input becomes available
 * on the specified socket. The registered C-upcall is then called
 * with its environment variable. 
 */
void ce_PassSock(value handler_v, value env_v){
  ce_handler_t handler;
  ce_env_t env;

  handler = Handler_val(handler_v);
  env = Env_val(env_v);
  (*handler)(env);
}

void ce_AddSockRecv(CE_SOCKET socket, ce_handler_t handler, ce_env_t env){
  CAMLparam0();
  CAMLlocal3(socket_v,env_v, handler_v);

  socket_v = Val_socket(socket);
  env_v = Val_env(env);
  handler_v = Val_handler(handler);
  callback3(*ce_add_sock_recv_v, socket_v, handler_v, env_v);

  CAMLreturn0;
}

void ce_RmvSockRecv(CE_SOCKET socket){
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
void
ce_Init(int argc, char **argv){
  char **ml_args;
  
  ml_args = ce_process_args(argc, argv);
  caml_startup(ml_args) ;

  /* Read the set of exported CAML callbacks.
   */
  ce_add_sock_recv_v = caml_named_value((char*) "ce_add_sock_recv_v");
  ce_rmv_sock_recv_v = caml_named_value((char*) "ce_rmv_sock_recv_v");
  ce_async_v = caml_named_value((char*)"ce_async_v") ;
  ce_join_v = caml_named_value((char*)"ce_join_v") ;
  ce_main_loop_v = caml_named_value((char*)"ce_main_loop_v") ;
}

/* Join a group
 */
void
ce_Join(
        ce_jops_t *jops,
	ce_appl_intf_t *c_appl
) {
  value jops_v, c_appl_v;

  if (ce_join_v == NULL){
    printf("Main loop callback not initialized yet. You need to do"
	   "ce_process_args first.\n");
    exit(1);
  }

  jops_v = Val_jops(jops);
  c_appl_v = Val_c_appl(c_appl);
  TRACE("before the callback"); 
  callback2(*ce_join_v, c_appl_v, jops_v);
}

/* Start the Ensemble main_loop
 */
void ce_Main_loop () {
  if (ce_main_loop_v == NULL){
    printf("Main loop callback not initialized yet. You need to do"
	   "ce_process_args first.\n");
    exit(1);
  }
  callback(*ce_main_loop_v, Val_unit);
}

/****************************************************************************/
