/**************************************************************/
/* CE_THREAD_SAFE.C */
/* Author: Ohad Rodeh 03/2002 */
/**************************************************************/
/* This module wraps all calls to the CE interface such that
 * they are thread safe.
 *
 * A single thread is used to run the Ensemble library. All CE calls
 * are performed by this thread, which also receives all Ensemble
 * messages. All CE calls are protected using a single
 * semaphore. Since calls are short, this should be enough.
 */
/**************************************************************/
#include "ce_threads.h"
#include "ce_internal.h"
#include "ce_trace.h"
#include <stdio.h>
/**************************************************************/
#define NAME "CE_THREAD_SAFE"
/**************************************************************/

typedef struct {
    int joining;
    int leaving;
    ce_sema_t *mutex;
    ce_env_t *user_env;
} ts_env_t;

/* These calls do not need protection
 */
/*
  LINKDLL char *ce_copy_string(char *str);
  LINKDLL void ce_view_full_free(ce_local_state_t *ls, ce_view_state_t* vs);
  LINKDLL void ce_jops_free(ce_jops_t*) ;
  LINKDLL ce_appl_intf_t*
  ce_create_intf(ce_env_t env, 
	       ce_appl_exit_t exit,
	       ce_appl_install_t install,
	       ce_appl_flow_block_t flow_block,
	       ce_appl_block_t block,
	       ce_appl_receive_cast_t cast,
	       ce_appl_receive_send_t send,
	       ce_appl_heartbeat_t heartbeat
    );

*/

/**************************************************************/
static struct ce_sema *mutex;

LINKDLL void
ce_Init(int argc,char **argv)
{
    mutex = ce_sema_Create(1);
    ce_intrn_Init(argc, argv);
}

LINKDLL void
ce_Main_loop (void)
{
    ce_intrn_Main_loop();
}

LINKDLL void
ce_Join(ce_jops_t *ops, ce_appl_intf_t *c_appl)
{
    ce_sema_Dec(mutex);
    ce_intrn_Join(ops, c_appl);
    ce_sema_Inc(mutex);
}

LINKDLL void
ce_Leave(ce_appl_intf_t *c_appl)
{
    ce_sema_Dec(mutex);
    ce_intrn_Leave(c_appl);
    ce_sema_Inc(mutex);
}

LINKDLL void
ce_Cast(ce_appl_intf_t *c_appl, int num, ce_iovec_array_t iovl)
{
    ce_sema_Dec(mutex);
    ce_intrn_Leave(c_appl);
    ce_sema_Inc(mutex);
}

LINKDLL void
ce_Send(ce_appl_intf_t *c_appl, int num_dests, ce_rank_array_t dests,
	int num, ce_iovec_array_t iovl)
{
    ce_sema_Dec(mutex);
    ce_intrn_Send(c_appl, num_dests, dests, num, iovl);
    ce_sema_Inc(mutex);
}


LINKDLL void
ce_Send1(ce_appl_intf_t *c_appl, ce_rank_t dest, int num,
	 ce_iovec_array_t iovl)
{
    ce_sema_Dec(mutex);
    ce_intrn_Send1(c_appl, dest, num, iovl);
    ce_sema_Inc(mutex);
}

LINKDLL void
ce_Prompt(ce_appl_intf_t *c_appl)
{
    ce_sema_Dec(mutex);
    ce_intrn_Prompt(c_appl);
    ce_sema_Inc(mutex);
}

LINKDLL void
ce_Suspect(ce_appl_intf_t *c_appl, int num, ce_rank_array_t suspects)
{
    ce_sema_Dec(mutex);
    ce_intrn_Suspect(c_appl, num, suspects);
    ce_sema_Inc(mutex);
}

LINKDLL void
ce_XferDone(ce_appl_intf_t *c_appl)
{
    ce_sema_Dec(mutex);
    ce_intrn_XferDone(c_appl);
    ce_sema_Inc(mutex);
}

LINKDLL void
ce_ChangeProtocol(ce_appl_intf_t *c_appl, char *protocol_name)
{
    ce_sema_Dec(mutex);
    ce_intrn_ChangeProtocol(c_appl, protocol_name);
    ce_sema_Inc(mutex);
}

LINKDLL void
ce_ChangeProperties(ce_appl_intf_t *c_appl,  char *properties)
{
    ce_sema_Dec(mutex);
    ce_intrn_ChangeProperties(c_appl, properties);
    ce_sema_Inc(mutex);
}

/**************************************************************/
/*!  Auxiliary functions.
 */

/*! Allows overriding the default ML value printer.
 * For the power-user.
 */
LINKDLL void
ce_MLPrintOverride( void (*handler)(char *msg))
{
    ce_sema_Dec(mutex);
    ce_intrn_MLPrintOverride(handler);
    ce_sema_Inc(mutex);
}
    
/*! Allows overriding the default ML exception handler.
 * For the power-user.
 */
LINKDLL void
ce_MLUncaughtException(void (*handler)(char *info))
{
    ce_sema_Dec(mutex);
    ce_intrn_MLUncaughtException(handler);
    ce_sema_Inc(mutex);
}
    
/**************************************************************/

LINKDLL void
ce_AddSockRecv(CE_SOCKET socket, ce_handler_t handler, ce_env_t env)
{
    ce_sema_Dec(mutex);
    ce_intrn_AddSockRecv(socket, handler, env);
    ce_sema_Inc(mutex);
}

/*! Remove a socket from the list Ensemble listens to.
 *@param socket The socket to remove. 
 */
LINKDLL void
ce_RmvSockRecv(CE_SOCKET socket)
{
    ce_sema_Dec(mutex);
    ce_intrn_RmvSockRecv(socket);
    ce_sema_Inc(mutex);
}

/**************************************************************/
LINKDLL void
ce_flat_Cast(ce_appl_intf_t *c_appl, ce_len_t len, ce_data_t buf)
{
    ce_sema_Dec(mutex);
    ce_intrn_flat_Cast(c_appl, len, buf);
    ce_sema_Inc(mutex);
}

LINKDLL void
ce_flat_Send(ce_appl_intf_t *c_appl, int num_dests, ce_rank_array_t dests,
    ce_len_t len, ce_data_t buf)
{
    ce_sema_Dec(mutex);
    ce_intrn_flat_Send(c_appl, num_dests, dests, len, buf);
    ce_sema_Inc(mutex);
}


LINKDLL void
ce_flat_Send1(ce_appl_intf_t *c_appl, ce_rank_t dest, ce_len_t len, 
	      ce_data_t buf)
{
    ce_sema_Dec(mutex);
    ce_intrn_flat_Send1(c_appl, dest, len, buf);
    ce_sema_Inc(mutex);
}

/**************************************************************/

