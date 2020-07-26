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
/* CE_OUTBOARD_C_MT.C */
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
#include "ce_outboard_c.h"
#include "ce_threads.h"
#include "ce_actions_mt.h"
#include "ce_comm.h"
#include "ce_trace.h"

#include <stdio.h>
/**************************************************************/
#define NAME "CE_OUTBOARD_MT"
/**************************************************************/

/* The global state of this module
 */
static struct global {
    int initialized;
    ce_lck_t *mutex;
    ce_mt_queue_t *q;
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

static void
mt_exit(ce_env_t env)
{
    mt_env_t *e = (mt_env_t*) env;

    TRACE("exit(");
    e->exit(e->user_env);
    TRACE(".");

    ce_lck_Lock(g.mutex);
    destroy_mt_env(env);
    ce_lck_Unlock(g.mutex);
}

static void
mt_install(ce_env_t env, ce_local_state_t *ls, ce_view_state_t *vs)
{
    mt_env_t *e = env;
    
    TRACE("install(");
    e->install(e->user_env, ls, vs);
}

static void
mt_flow_block(ce_env_t env, ce_rank_t origin, ce_bool_t onoff)
{
    mt_env_t *e = env;
    e->flow_block(e->user_env, origin, onoff);
}

static void
mt_block(ce_env_t env)
{
    mt_env_t *e = env;
    e->block(e->user_env);
}

static void
mt_cast(ce_env_t env, ce_rank_t origin, int len, ce_iovec_array_t iovl)
{
    mt_env_t *e = env;
    e->cast(e->user_env, origin, len, iovl);
}

static void
mt_send(ce_env_t env, ce_rank_t origin, int len, ce_iovec_array_t iovl)
{
    mt_env_t *e = env;
    e->send(e->user_env, origin, len, iovl);
}

static void
mt_heartbeat(ce_env_t env, ce_time_t time)
{
    mt_env_t *e = env;
    e->heartbeat(e->user_env, time);
}


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
    return ce_st_create_intf((void*)e, mt_exit, mt_install, mt_flow_block,
				mt_block, mt_cast, mt_send, mt_heartbeat);
}

/**************************************************************/
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
    ce_st_Main_loop();
    ce_trace(NAME, "thread:)");
}

/**************************************************************/
/* This is used to customize the locking functions used by
 * single-threaded outboard mode.
 */
void ce_mt_lock(void) { ce_lck_Lock(g.mutex); }
void ce_mt_unlock(void) { ce_lck_Unlock(g.mutex); }

void
ce_mt_Init(int argc,char **argv)
{
    TRACE("ce_Init(");
    init_g();
    ce_st_set_lock_fun(ce_mt_lock);
    ce_st_set_unlock_fun(ce_mt_unlock);

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
    ce_lck_Lock(g.mutex);
    ce_st_Join(ops, c_appl);
    ce_lck_Unlock(g.mutex);
}

void
ce_mt_Leave(ce_appl_intf_t *c_appl)
{
    ce_lck_Lock(g.mutex);
    ce_st_Leave(c_appl);
    ce_lck_Unlock(g.mutex);
}

void
ce_mt_Cast(ce_appl_intf_t *c_appl, int num, ce_iovec_array_t iovl)
{
    ce_lck_Lock(g.mutex);
    ce_st_Cast(c_appl, num, iovl);
    ce_lck_Unlock(g.mutex);
}

void
ce_mt_Send(ce_appl_intf_t *c_appl, int num_dests, ce_rank_array_t dests,
	int num, ce_iovec_array_t iovl)
{
    ce_lck_Lock(g.mutex);
    ce_st_Send(c_appl, num_dests, dests, num, iovl);
    ce_lck_Unlock(g.mutex);
}


void
ce_mt_Send1(ce_appl_intf_t *c_appl, ce_rank_t dest, int num,
	 ce_iovec_array_t iovl)
{
    ce_lck_Lock(g.mutex);
    ce_st_Send1(c_appl, dest, num, iovl);
    ce_lck_Unlock(g.mutex);
}

void
ce_mt_Prompt(ce_appl_intf_t *c_appl)
{
    ce_lck_Lock(g.mutex);
    ce_st_Prompt(c_appl);
    ce_lck_Unlock(g.mutex);
}

void
ce_mt_Suspect(ce_appl_intf_t *c_appl, int num, ce_rank_array_t suspects)
{
    ce_lck_Lock(g.mutex);
    ce_st_Suspect(c_appl, num, suspects);
    ce_lck_Unlock(g.mutex);
}

void
ce_mt_XferDone(ce_appl_intf_t *c_appl)
{
    TRACE("ce_XferDone");
    ce_lck_Lock(g.mutex);
    ce_st_XferDone(c_appl);
    ce_lck_Unlock(g.mutex);
}

void
ce_mt_Rekey(ce_appl_intf_t *c_appl)
{
    ce_lck_Lock(g.mutex);
    ce_st_Rekey(c_appl);
    ce_lck_Unlock(g.mutex);
}

void
ce_mt_ChangeProtocol(ce_appl_intf_t *c_appl, char *protocol_name)
{
    ce_lck_Lock(g.mutex);
    ce_st_ChangeProtocol(c_appl, protocol_name);
    ce_lck_Unlock(g.mutex);
}

void
ce_mt_ChangeProperties(ce_appl_intf_t *c_appl,  char *properties)
{
    ce_lck_Lock(g.mutex);
    ce_st_ChangeProperties(c_appl, properties);
    ce_lck_Unlock(g.mutex);
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
    ce_panic ("ce_AddSockRecv is not supported for the multi-threaded version\n");
}

/*! Remove a socket from the list Ensemble listens to.
 *
 * Illegal in the multi-threaded version.
 * 
 *@param socket The socket to remove. 
 */
void
ce_mt_RmvSockRecv(CE_SOCKET socket)
{
    ce_panic ("ce_RmvSockRecv is not supported for the multi-threaded version\n");
}

/**************************************************************/
