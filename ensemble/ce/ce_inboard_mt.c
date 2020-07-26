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
#include "ce_appl_env_list.h"

#include <stdio.h>
/**************************************************************/
#define NAME "CE_INBOARD_MT"
/**************************************************************/

/* The global state of this module
 */
static struct global {
    int initialized;
    ce_lck_t *mutex;

    CE_SOCKET sock ;  /* Used to communicate with the Ensemble thread */
    int req;    /* Have we requested attention already? */
    int checking ;
    ce_mt_queue_t *q;
    ce_mt_queue_t *internal_q;
    ce_sema_t *wait_AddSockRecv;
    ce_sema_t *wait_RmvSockRecv;
    struct sockaddr_in to;
    ce_pool_t *mt_pool;                /* The action pool used by MT */
    ce_pool_t *st_pool;                /* The action pool used by ST */
    ce_appl_env_list_t *appl_env_list;
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
    g.mt_pool = ce_pool_create();
    g.st_pool = ce_st_get_allocation_pool();
    g.appl_env_list = ce_appl_env_list_create();
    
    ce_internal_sock(&g.sock, &g.to);

	
    TRACE(")");
}

/**************************************************************/

typedef struct {
    ce_env_t user_env;
    ce_appl_intf_t *c_appl;
    ce_queue_t *mt_aq;               /* A queue of pending actions */
    int req_heartbeat;   /* Should we request a callback? */
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
    memset(e, 0, sizeof(mt_env_t));
    e->mt_aq = ce_queue_create();
    e->user_env = env;
    e->exit = exit;
    e->install = install;
    e->block = block;
    e->flow_block = flow_block;
    e->cast = cast;
    e->send = send;
    e->heartbeat = heartbeat;

    return e;
}

static void
destroy_mt_env(mt_env_t *e)
{
    ce_queue_free(g.mt_pool, e->mt_aq);
    free(e);
}

/**************************************************************/

/* Takes the ens_mutex lock, and performs all pending Ensemble
 * operations. 
 */
static void check_pending(void)
{
    int i;
    ce_mt_action_t *a;
    int total_num_actions = 0;
    
    /* Prevent re-entry by the ens_thread.
     */
    if (g.checking) return;
    g.checking = 1;

    if (rand() % 100 == 0) {
	TRACE_GEN(("mt_pool free=%d\n", g.mt_pool->num_free));
	TRACE_GEN(("st_pool free=%d\n", g.st_pool->num_free));
    }
//    TRACE("check_pending(");
    ce_lck_Lock(g.mutex);
    if (g.q->len > 0)
	ce_mt_queue_copy_and_clear(g.q, g.internal_q);

    for(i=0; i<g.appl_env_list->len; i++) {
	mt_env_t *env;
	
	if (g.appl_env_list->arr[i] == 0) continue;
	
	env = (mt_env_t*) g.appl_env_list->arr[i];
	if (ce_queue_length(env->mt_aq) == 0) continue;

	total_num_actions += ce_queue_length(env->mt_aq);
	ce_queue_pour(env->mt_aq, env->c_appl->aq);
	env->req_heartbeat = 1;
    }

    /* Replenish the MT pool from the ST pool
     */
    ce_pool_move(g.st_pool, g.mt_pool, total_num_actions);
    
    ce_lck_Unlock(g.mutex);
    g.req = 0;
    
    /* These parts do not require the lock. They can also take a long time, since they call
     * Ensemble synchronously.
     */
    for(i=0; i<g.appl_env_list->len; i++) {
	mt_env_t *env;
	
	if (g.appl_env_list->arr[i] == 0) continue;
	
	env = (mt_env_t*) g.appl_env_list->arr[i];
	if (0 == env->req_heartbeat) continue;
	
	ce_st_check_heartbeat(env->c_appl);
	env->req_heartbeat = 0;
    }

    /* Dispatch all pending events. 
     */
    for(i=0; i<g.internal_q->len; i++){
	a = (ce_mt_action_t *) &(g.internal_q->arr[i]);
	
	switch (a->type){
	case MT_JOIN:
//		TRACE("MT_JOIN");
	    ce_st_Join(a->u.join.ops, a->u.join.c_appl);
	    ce_jops_free(a->u.join.ops);
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

    g.checking = 0;
//    TRACE(")");
}


/**************************************************************/
static void
mt_exit(ce_env_t env)
{
    mt_env_t *e = (mt_env_t*) env;
    e->exit(e->user_env);
    ce_appl_env_list_remove(g.appl_env_list, (void*)e);
    destroy_mt_env(e);
}

/* Call the application install handler, and then send an asynchronous
 * block_ok event to Ensemble.
 */
static void
mt_install(ce_env_t env, ce_local_state_t *ls, ce_view_state_t *vs)
{
    mt_env_t *e = (mt_env_t*)env;
    g.req = 1;
    e->install(e->user_env, ls, vs);
    check_pending();
}

static void
mt_flow_block(ce_env_t env, ce_rank_t origin, ce_bool_t onoff)
{
    mt_env_t *e = (mt_env_t*)env;
    g.req = 1;
    TRACE("mt_flow_block");
    e->flow_block(e->user_env, origin, onoff);
    check_pending();
}

static void
mt_block(ce_env_t env)
{
    mt_env_t *e = (mt_env_t*)env;
    g.req = 1;
    e->block(e->user_env);
    check_pending();
}

static void
mt_cast(ce_env_t env, ce_rank_t origin, int len, ce_iovec_array_t iovl)
{
    mt_env_t *e = (mt_env_t*)env;
    g.req = 1;
    e->cast(e->user_env, origin, len, iovl);
    check_pending();
}

static void
mt_send(ce_env_t env, ce_rank_t origin, int len, ce_iovec_array_t iovl)
{
    mt_env_t *e = (mt_env_t*)env;
    g.req = 1;
    e->send(e->user_env, origin, len, iovl);
    check_pending();
}

static void
mt_heartbeat(ce_env_t env, ce_time_t time)
{
    mt_env_t *e = (mt_env_t*)env;
    g.req = 1;
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
    ce_appl_intf_t *c_appl;
    
    TRACE("ce_create_intf");
    e = create_mt_env(env, exit, install, flow_block, block, cast, send, heartbeat);
    ce_appl_env_list_add(g.appl_env_list, (void*)e);
    c_appl = ce_st_create_intf((void*)e, mt_exit,
			       mt_install, mt_flow_block,
			       mt_block, mt_cast,
			       mt_send, mt_heartbeat);
    e->c_appl = c_appl;
    return c_appl;
}

/* Send one byte on the socket to Ensemble. This call is unsafe, must
 * be protected by taking g.mutex. This call is also responsible for
 * releaseing the lock. 
 */
void
req_attention(void)
{
    int result = 0;
    char *buf = "a";

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
    
    res = recv(g.sock, (char*)&buf, 4, 0);
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
    ce_st_Init(argc, argv);

    /* MT initalization is dependent upon ST initialization. 
     */
    init_g();

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

void ce_mt_Leave(ce_appl_intf_t *c_appl)
{
    mt_env_t *env = c_appl->env;
    
    TRACE("Leave("); 
    ce_lck_Lock(g.mutex);
    ce_action_leave(g.mt_pool, env->mt_aq);
    ce_lck_Unlock(g.mutex);
    req_attention();
    TRACE(")");
}

void ce_mt_Cast(ce_appl_intf_t *c_appl, int num, ce_iovec_array_t iovl)
{
    mt_env_t *env = c_appl->env;

    TRACE("Cast(");
    ce_lck_Lock(g.mutex);
    ce_action_cast (g.mt_pool, env->mt_aq, num, iovl);
    ce_lck_Unlock(g.mutex);
    req_attention();
    TRACE(")");
}

void
ce_mt_Send(ce_appl_intf_t *c_appl, int num_dests, ce_rank_array_t dests,
	   int num, ce_iovec_array_t iovl)
{
    mt_env_t *env = c_appl->env;

    TRACE("Send(");
    ce_lck_Lock(g.mutex);
    ce_action_send(g.mt_pool, env->mt_aq, num_dests, dests, num, iovl);
    ce_lck_Unlock(g.mutex);
    req_attention();
    TRACE(")");
}


void
ce_mt_Send1(ce_appl_intf_t *c_appl, ce_rank_t dest, int num,
	    ce_iovec_array_t iovl)
{
    mt_env_t *env = c_appl->env;

    TRACE("Send1(");
    ce_lck_Lock(g.mutex);
    ce_action_send1(g.mt_pool, env->mt_aq, dest, num, iovl);
    ce_lck_Unlock(g.mutex);
    req_attention();
    TRACE(")");
}

void
ce_mt_Prompt(ce_appl_intf_t *c_appl)
{
    mt_env_t *env = c_appl->env;

    ce_lck_Lock(g.mutex);
    ce_action_prompt(g.mt_pool, env->mt_aq);
    ce_lck_Unlock(g.mutex);
    req_attention();
}

void
ce_mt_Suspect(ce_appl_intf_t *c_appl, int num, ce_rank_array_t suspects)
{
    mt_env_t *env = c_appl->env;

    ce_lck_Lock(g.mutex);
    ce_action_suspect(g.mt_pool, env->mt_aq, num, suspects);
    ce_lck_Unlock(g.mutex);
    req_attention();
}

void
ce_mt_XferDone(ce_appl_intf_t *c_appl)
{
    mt_env_t *env = c_appl->env;

    TRACE("ce_XferDone");
    ce_lck_Lock(g.mutex);
    ce_action_xfer_done(g.mt_pool, env->mt_aq);
    ce_lck_Unlock(g.mutex);
    req_attention();
}

void
ce_mt_Rekey(ce_appl_intf_t *c_appl)
{
    mt_env_t *env = c_appl->env;

    TRACE("ce_Rekey");
    ce_lck_Lock(g.mutex);
    ce_action_rekey(g.mt_pool, env->mt_aq);
    ce_lck_Unlock(g.mutex);
    req_attention();
}

void
ce_mt_ChangeProtocol(ce_appl_intf_t *c_appl, char *protocol_name)
{
    mt_env_t *env = c_appl->env;

    ce_lck_Lock(g.mutex);
    ce_action_protocol(g.mt_pool, env->mt_aq, protocol_name);
    ce_lck_Unlock(g.mutex);
    req_attention();
}

void
ce_mt_ChangeProperties(ce_appl_intf_t *c_appl,  char *properties)
{
    mt_env_t *env = c_appl->env;

    ce_lck_Lock(g.mutex);
    ce_action_properties(g.mt_pool, env->mt_aq, properties);
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
