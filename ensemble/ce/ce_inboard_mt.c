/**************************************************************/
/* CE_INBOARD_C_MT.C */
/* Author: Ohad Rodeh 03/2002 */
/**************************************************************/
/* This module wraps all calls to the CE interface such that
 * they are thread safe.
 *
 * A single thread is used to run the Ensemble library. All CE calls
 * are performed by this thread, which also receives all Ensemble
 * messages. A queue is used to store all pending CE calls, each queue
 * cell contains pointers to call arguments. A socket is used to
 * connect between program threads and Ensemble thread, a callback is
 * registered by Ensemble such that whenever a byte is received on the
 * socket, the shared queue is emptied and pending calls are perfored.
 *
 */
/**************************************************************/
#include "ce_internal.h"
#include "ce_threads.h"
#include "ce_actions_mt.h"
#include "ce_comm.h"
#include "ce_trace.h"

#include <stdio.h>
/**************************************************************/
#define NAME "CE_INBOARD_MT"
/**************************************************************/

/* The global state of this module
 */
static struct global {
    int initialized;
    ce_lck_t *mutex;

    ce_mt_queue_t *q;
    ce_mt_queue_t *internal_q;

    CE_SOCKET sock ;  /* Used to communicate with the Ensemble thread */
    int req;    /* Have we requested attention already? */
    int checking ;
    ce_sema_t *wait_AddSockRecv;
    ce_sema_t *wait_RmvSockRecv;
    struct sockaddr_in to;
} g;

/* Initialize the global state
 */ 
static void
init_g (void)
{
    TRACE("init_g(");
    g.initialized = 0;
    g.mutex = ce_lck_Create();
    g.q = ce_mt_queue_create ();
    g.internal_q = ce_mt_queue_create ();
    g.req = 0;
    g.checking = 0;
    g.wait_AddSockRecv = ce_sema_Create(1);
    g.wait_RmvSockRecv = ce_sema_Create(1);

    ce_internal_sock(&g.sock, &g.to);

    TRACE(")");
}

/**************************************************************/

typedef struct {
    ce_env_t user_env;
    ce_appl_exit_t exit;
    ce_appl_install_t install;
    ce_appl_flow_block_t flow_block;
    ce_appl_block_t block;
    ce_appl_receive_cast_t cast;
    ce_appl_receive_send_t send;
    ce_appl_heartbeat_t heartbeat;
} mt_env_t;

static mt_env_t *
create_mt_env(ce_env_t env, 
	      ce_appl_exit_t exit,
	      ce_appl_install_t install,
	      ce_appl_flow_block_t flow_block,
	      ce_appl_block_t block,
	      ce_appl_receive_cast_t cast,
	      ce_appl_receive_send_t send,
	      ce_appl_heartbeat_t heartbeat)
{
    mt_env_t *e;

    e = (mt_env_t*) ce_malloc(sizeof(mt_env_t));
    e->user_env = env;
    e->exit = exit;
    e->install = install;
    e->block = block;
    e->block = block;
    e->cast = cast;
    e->send = send;
    e->heartbeat = heartbeat;
    return e;
}

static void
destroy_mt_env(mt_env_t *e)
{
    free(e);
}

/**************************************************************/

/* Takes the ens_mutex lock, and performs all pending Ensemble
 * operations. 
 */
static void
check_pending(void)
{
    int i;
    ce_mt_action_t *a;
    
    /* Prevent re-entry by the ens_thread.
     */
    if (g.checking) return;
    g.checking = 1;

//    TRACE("check_pending(");
    ce_lck_Lock(g.mutex);
    if (g.q->len > 0) {
	ce_mt_queue_copy_and_clear(g.q, g.internal_q);
	ce_lck_Unlock(g.mutex);
	g.req = 0;
	
	/* Dispatch all pending events. 
	 */
	for(i=0; i<g.internal_q->len; i++){
	    a = (ce_mt_action_t *) &(g.internal_q->arr[i]);

	    switch (a->type){
	    case MT_CAST:
		TRACE("MT_CAST");
		ce_st_Cast(a->c_appl, a->u.cast.num, a->u.cast.iovl);
		break;
	    case MT_SEND:
		TRACE("MT_SEND");
		ce_st_Send(a->c_appl, a->u.send.num_dests, a->u.send.dests,
			      a->u.send.num, a->u.send.iovl);
		break;
	    case MT_SEND1:
		TRACE("MT_SEND1");
		ce_st_Send1(a->c_appl, a->u.send1.dest, a->u.send1.num, a->u.send1.iovl);
		break;
	    case MT_LEAVE:
		TRACE("MT_LEAVE");
		ce_st_Leave(a->c_appl);
		break;
	    case MT_PROMPT:
		TRACE("MT_PROMPT");
		ce_st_Prompt(a->c_appl);
		break;
	    case MT_SUSPECT:
		TRACE("MT_SUSPECT");
		ce_st_Suspect(a->c_appl, a->u.suspect.num, a->u.suspect.members);
		break;
	    case MT_XFERDONE:
		TRACE("MT_XFERDONE");
		ce_st_XferDone(a->c_appl);
		break;
	    case MT_REKEY:
		TRACE("MT_REKEY");
		ce_st_Rekey(a->c_appl);
		break;
	    case MT_PROTOCOL:
		TRACE("MT_PROTOCOL");
		ce_st_ChangeProtocol(a->c_appl, a->u.proto);
		break;
	    case MT_PROPERTIES:
		TRACE("MT_PROPERITES");
		ce_st_ChangeProperties(a->c_appl, a->u.properties);
		break;
		
	    case MT_JOIN:
		TRACE("MT_JOIN");
		ce_st_Join(a->u.join.ops, a->c_appl);
		break;
	    case MT_ADDSOCKRECV:
		ce_st_AddSockRecv(a->u.add_sock.socket,
				     a->u.add_sock.handler, a->u.add_sock.env);
		ce_sema_Inc(g.wait_AddSockRecv);
		break;
	    case MT_RMVSOCKRECV:
		ce_st_RmvSockRecv(a->u.rmv_sock.socket);
		ce_sema_Inc(g.wait_RmvSockRecv);
		break;
	    }
	}
	/* cleanup
	 */
	ce_mt_queue_clear (g.internal_q);
    } else {
	ce_lck_Unlock(g.mutex);
	g.req = 0;
    }
    
    g.checking = 0;
//    TRACE(")");
}


/**************************************************************/
static void
mt_exit(ce_env_t env)
{
    mt_env_t *e = (mt_env_t*) env;
    e->exit(e->user_env);
    destroy_mt_env(e);
}

/*
#define REQ  { \
    ce_lck_Lock(g.mutex); \
    g.req = 1; \
    ce_lck_Unlock(g.mutex);\
}
*/

#define REQ g.req = 1; 

/* Call the application install handler, and then send an asynchronous
 * block_ok event to Ensemble.
 */
static void
mt_install(ce_env_t env, ce_local_state_t *ls, ce_view_state_t *vs)
{
    mt_env_t *e = (mt_env_t*)env;
    REQ;
    e->install(e->user_env, ls, vs);
    check_pending();
}

static void
mt_flow_block(ce_env_t env, ce_rank_t origin, ce_bool_t onoff)
{
    mt_env_t *e = (mt_env_t*)env;
    REQ;
    e->flow_block(e->user_env, origin, onoff);
    check_pending();
}

static void
mt_block(ce_env_t env)
{
    mt_env_t *e = (mt_env_t*)env;
    REQ;
    e->block(e->user_env);
    check_pending();
}

static void
mt_cast(ce_env_t env, ce_rank_t origin, int len, ce_iovec_array_t iovl)
{
    mt_env_t *e = (mt_env_t*)env;
    REQ;
    e->cast(e->user_env, origin, len, iovl);
    check_pending();
}

static void
mt_send(ce_env_t env, ce_rank_t origin, int len, ce_iovec_array_t iovl)
{
    mt_env_t *e = (mt_env_t*)env;
    REQ;
    e->send(e->user_env, origin, len, iovl);
    check_pending();
}

static void
mt_heartbeat(ce_env_t env, ce_time_t time)
{
    mt_env_t *e = (mt_env_t*)env;
    REQ;
    e->heartbeat(e->user_env, time);
    check_pending();
}


/* We need to make the inteface asynchrouns, so as blocking will occur
 * a la outboard mode. 
 */
ce_appl_intf_t*
ce_mt_create_intf(ce_env_t env, 
	       ce_appl_exit_t exit,
	       ce_appl_install_t install,
	       ce_appl_flow_block_t flow_block,
	       ce_appl_block_t block,
	       ce_appl_receive_cast_t cast,
	       ce_appl_receive_send_t send,
	       ce_appl_heartbeat_t heartbeat
    ){
    mt_env_t *e;
    
    TRACE("ce_create_intf");
    e = create_mt_env(env, exit, install, flow_block, block, cast, send, heartbeat);
    return ce_st_create_intf((void*)e, mt_exit,
				mt_install, mt_flow_block,
				mt_block, mt_cast,
				mt_send, mt_heartbeat);
}

/* Send one byte on the socket to Ensemble. This call is unsafe, must
 * be protected by taking g.mutex. This call is also responsible for
 * releaseing the lock. 
 */
void
req_attention(void)
{
    int result = 0;
    char buf[2] = "a";

    if (g.req == 0) {
	g.req = 1;
//	ce_lck_Unlock(g.mutex);

	TRACE("Send[");
/*#ifndef _WIN32*/
	result = sendto(g.sock, buf, 1, 0, (struct sockaddr *) &g.to,
	       sizeof(g.to));
/*#else
	{
	    WSABUF iov;
	    int len =0;
	    iov.len = 1;
	    iov.buf = "a";

	    result = WSASendTo (g.sock, &iov, 1, &len, 0,
				(struct sockaddr *) &g.to, sizeof(struct sockaddr_in), 0, NULL);
	}
	#endif*/
	TRACE("]");
	
	//if (result <= 0)
	//ce_panic("socket is broken\n");
    } /*else
	{
	ce_lck_Unlock(g.mutex);
	}*/
}

/**************************************************************/
static void
sock_handler(void *dummy)
{
    char buf[4];
    int res;
    
    TRACE("sock_handler[");
     /* Receive one byte, this should be thread-safe.
      */
    
//    ce_lck_Lock(g.mutex);
    res = recv(g.sock, (char*)&buf, 4, 0);
//    ce_lck_Unlock(g.mutex);
    check_pending();
    TRACE("]");
}

/* The code running inside the Ensemble thread. Listen to a socket, when
 * a byte arrives:
 * (1) grab the global semaphore
 * (2) read the queue, and dispatch all pending events.
 * (3) release the global semaphore
 */
static void
ens_thread (void *dummy)
{
    ce_trace(NAME, "thread:(");
    ce_st_AddSockRecv((CE_SOCKET)g.sock, sock_handler, NULL);
    ce_trace(NAME, "thread:.");
    ce_st_Main_loop();
    ce_trace(NAME, "thread:)");
}
/**************************************************************/
void
ce_mt_Init(int argc,char **argv)
{
    TRACE("ce_Init(");
    init_g();
    ce_st_Init(argc, argv);

    /* This must be performed exactly once.
     */
    TRACE("ce_Main_loop(");
    g.initialized = 1;
    ce_thread_Create(ens_thread, NULL, 1000000);
    TRACE(")");
}

/* Start Ensemble in a separate thread, allow 1M of memory for
 * the thread stack size.
 */
void
ce_mt_Main_loop (void)
{
    ce_sema_t *sema;
    
    sema = ce_sema_Create(0);
    ce_sema_Dec(sema);
}

void
ce_mt_Join(ce_jops_t *ops, ce_appl_intf_t *c_appl)
{
    if (!g.initialized) {
	ce_panic("Ensemble has not been initialized. Must call ce_Init\n");
	exit(1);
    }
    TRACE("ce_Join(");
    ce_lck_Lock(g.mutex);
    TRACE(".");
    ce_mt_appl_join(g.q, c_appl, ops);
    ce_lck_Unlock(g.mutex);
    TRACE(".");
    req_attention();
    TRACE(")");
}

void
ce_mt_Leave(ce_appl_intf_t *c_appl)
{
    TRACE("Leave("); 
    ce_lck_Lock(g.mutex);
    ce_mt_appl_leave(g.q, c_appl);
    ce_lck_Unlock(g.mutex);
    req_attention();
    TRACE(")");
}

void
ce_mt_Cast(ce_appl_intf_t *c_appl, int num, ce_iovec_array_t iovl)
{
    TRACE("Cast(");
    ce_lck_Lock(g.mutex);
    ce_mt_appl_cast(g.q, c_appl, num, iovl);
    ce_lck_Unlock(g.mutex);
    req_attention();
    TRACE(")");
}

void
ce_mt_Send(ce_appl_intf_t *c_appl, int num_dests, ce_rank_array_t dests,
	int num, ce_iovec_array_t iovl)
{
   TRACE("Send(");
    ce_lck_Lock(g.mutex);
    ce_mt_appl_send(g.q, c_appl, num_dests, dests, num, iovl);
    ce_lck_Unlock(g.mutex);
    req_attention();
   TRACE(")");
}


void
ce_mt_Send1(ce_appl_intf_t *c_appl, ce_rank_t dest, int num,
	 ce_iovec_array_t iovl)
{
   TRACE("Send1(");
    ce_lck_Lock(g.mutex);
    ce_mt_appl_send1(g.q, c_appl, dest, num, iovl);
    ce_lck_Unlock(g.mutex);
    req_attention();
   TRACE(")");
}

void
ce_mt_Prompt(ce_appl_intf_t *c_appl)
{
    ce_lck_Lock(g.mutex);
    ce_mt_appl_prompt(g.q, c_appl);
    ce_lck_Unlock(g.mutex);
    req_attention();
}

void
ce_mt_Suspect(ce_appl_intf_t *c_appl, int num, ce_rank_array_t suspects)
{
    ce_lck_Lock(g.mutex);
    ce_mt_appl_suspect(g.q, c_appl, num, suspects);
    ce_lck_Unlock(g.mutex);
    req_attention();
}

void
ce_mt_XferDone(ce_appl_intf_t *c_appl)
{
    TRACE("ce_XferDone");
    ce_lck_Lock(g.mutex);
    ce_mt_appl_xfer_done(g.q, c_appl);
    ce_lck_Unlock(g.mutex);
    req_attention();
}

void
ce_mt_Rekey(ce_appl_intf_t *c_appl)
{

    TRACE("ce_Rekey");
    ce_lck_Lock(g.mutex);
    ce_mt_appl_rekey(g.q, c_appl);
    ce_lck_Unlock(g.mutex);
    req_attention();
}

void
ce_mt_ChangeProtocol(ce_appl_intf_t *c_appl, char *protocol_name)
{
    ce_lck_Lock(g.mutex);
    ce_mt_appl_protocol(g.q, c_appl, protocol_name);
    ce_lck_Unlock(g.mutex);
    req_attention();
}

void
ce_mt_ChangeProperties(ce_appl_intf_t *c_appl,  char *properties)
{
    ce_lck_Lock(g.mutex);
    ce_mt_appl_properties(g.q, c_appl, properties);
    ce_lck_Unlock(g.mutex);
    req_attention();
}

/**************************************************************/
/*!  Auxiliary functions.
 */

/*! Allows overriding the default ML value printer.
 * For the power-user.
 *
 * Can be performed only before the Ensemble thread is started.
 */
void
ce_mt_MLPrintOverride( void (*handler)(char *msg))
{
    if (!g.initialized)
	ce_st_MLPrintOverride(handler);
}
    
/*! Allows overriding the default ML exception handler.
 * For the power-user.
 *
 * Can be performed only before the Ensemble thread is started.
*/
void
ce_mt_MLUncaughtException(void (*handler)(char *info))
{
    if (!g.initialized)
	ce_st_MLUncaughtException(handler);
}
    
/**************************************************************/

void
ce_mt_AddSockRecv(CE_SOCKET socket, ce_handler_t handler, ce_env_t env)
{
    ce_lck_Lock(g.mutex);
    ce_mt_appl_AddSockRecv(g.q, socket, handler, env);
    ce_lck_Unlock(g.mutex);
    req_attention();

    /* Go to sleep until ce_AddSockRecv is actually invoked.
     */
    ce_sema_Dec(g.wait_AddSockRecv);
}

/*! Remove a socket from the list Ensemble listens to.
 *@param socket The socket to remove. 
 */
void
ce_mt_RmvSockRecv(CE_SOCKET socket)
{
    ce_lck_Lock(g.mutex);
    ce_mt_appl_RmvSockRecv(g.q, socket);
    ce_lck_Unlock(g.mutex);
    req_attention();

    /* Go to sleep until ce_RmvSockRecv is actually invoked.
     */
    ce_sema_Dec(g.wait_RmvSockRecv);
}

/**************************************************************/
