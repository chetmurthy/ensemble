/****************************************************************************/
/* CE_INTF.C */
/* Author:  Ohad Rodeh, 03/2002. */
/* Wraps the lower level calls to conform to the major interface
 * file, ce.h.
 *
 * This module is a front-end to the single-threaded version.
 * 
 * This allows wrapping transparently with thread-safe routines. */
/****************************************************************************/
#include "ce_internal.h"
#include "ce_trace.h"
/****************************************************************************/
#define NAME "CE_INTF"
/****************************************************************************/

LINKDLL ce_appl_intf_t*
ce_create_intf(ce_env_t env, 
	       ce_appl_exit_t exit,
	       ce_appl_install_t install,
	       ce_appl_flow_block_t flow_block,
	       ce_appl_block_t block,
	       ce_appl_receive_cast_t receive_cast,
	       ce_appl_receive_send_t receive_send,
	       ce_appl_heartbeat_t heartbeat
    ){
    return ce_st_create_intf(env, exit, install, flow_block,
			     block, receive_cast, receive_send, heartbeat);
}

LINKDLL void
ce_Init(int argc, char **argv)
{
    TRACE("ce_Init: calling ce_st_INIT");
    ce_st_Init(argc, argv);
}

LINKDLL void
ce_Main_loop (void)
{
    ce_st_Main_loop();
}

LINKDLL void
ce_Join(ce_jops_t *ops, ce_appl_intf_t *c_appl)
{
    ce_st_Join(ops, c_appl);
}

LINKDLL void
ce_Leave(ce_appl_intf_t *c_appl)
{
    ce_st_Leave(c_appl);
}

LINKDLL void
ce_Cast(ce_appl_intf_t *c_appl, int num, ce_iovec_array_t iovl)
{
    ce_st_Cast(c_appl, num, iovl);
}

LINKDLL void
ce_Send(ce_appl_intf_t *c_appl, int num_dests, ce_rank_array_t dests,
	int num, ce_iovec_array_t iovl)
{
    ce_st_Send(c_appl, num_dests, dests, num, iovl);
}

LINKDLL void
ce_Send1(ce_appl_intf_t *c_appl,  ce_rank_t dest, int num,
	 ce_iovec_array_t iovl)
{
    ce_st_Send1(c_appl, dest, num, iovl);
}

LINKDLL void
ce_Prompt(ce_appl_intf_t *c_appl)
{
    ce_st_Prompt(c_appl);
}

LINKDLL void
ce_Suspect(ce_appl_intf_t *c_appl, int num, ce_rank_array_t suspects)
{
    ce_st_Suspect(c_appl, num, suspects);
}

LINKDLL void
ce_XferDone(ce_appl_intf_t *c_appl)
{
    ce_st_XferDone(c_appl);
}

LINKDLL void
ce_Rekey(ce_appl_intf_t *c_appl)
{
    ce_st_Rekey(c_appl);
}

LINKDLL void
ce_ChangeProtocol(ce_appl_intf_t *c_appl, char *protocol_name)
{
    ce_st_ChangeProtocol(c_appl, protocol_name);
}

LINKDLL void
ce_ChangeProperties(ce_appl_intf_t *c_appl, char *properties)
{
    ce_st_ChangeProperties(c_appl, properties);
}

LINKDLL void
ce_MLPrintOverride(void (*handler)(char *msg))
{
    ce_st_MLPrintOverride(handler);
}
    
LINKDLL void
ce_MLUncaughtException(void (*handler)(char *info))
{
    ce_st_MLUncaughtException(handler);
}
    
LINKDLL void
ce_AddSockRecv(CE_SOCKET socket, ce_handler_t handler, ce_env_t env)
{
    ce_st_AddSockRecv(socket, handler, env);
}

LINKDLL void
ce_RmvSockRecv(CE_SOCKET socket)
{
    ce_st_RmvSockRecv(socket);
}


/****************************************************************************/

