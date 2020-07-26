/****************************************************************************/
/* CE_INTF.C */
/* Author:  Ohad Rodeh, 03/2002. */
/* Wraps the lower level calls to conform to the major interface
 * file, ce.h. This allows wrapping transparently with thread-safe
 * routines. */
/****************************************************************************/
#include "ce_internal.h"
/****************************************************************************/
#define NAME "CE_INTF"
/****************************************************************************/

LINKDLL void
ce_Init(int argc, char **argv)
{
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
    ce_intrn_Join(ops, c_appl);
}

LINKDLL void
ce_Leave(ce_appl_intf_t *c_appl)
{
    ce_intrn_Leave(c_appl);
}

LINKDLL void
ce_Cast(ce_appl_intf_t *c_appl, int num, ce_iovec_array_t iovl)
{
    ce_intrn_Cast(c_appl, num, iovl);
}

LINKDLL void
ce_Send(ce_appl_intf_t *c_appl, int num_dests, ce_rank_array_t dests,
	int num, ce_iovec_array_t iovl)
{
    ce_intrn_Send(c_appl, num_dests, dests, num, iovl);
}

LINKDLL void
ce_Send1(ce_appl_intf_t *c_appl,  ce_rank_t dest, int num,
	 ce_iovec_array_t iovl)
{
    ce_intrn_Send1(c_appl, dest, num, iovl);
}

LINKDLL void
ce_Prompt(ce_appl_intf_t *c_appl)
{
    ce_intrn_Prompt(c_appl);
}

LINKDLL void
ce_Suspect(ce_appl_intf_t *c_appl, int num, ce_rank_array_t suspects)
{
    ce_intrn_Suspect(c_appl, num, suspects);
}
LINKDLL void
ce_XferDone(ce_appl_intf_t *c_appl)
{
    ce_intrn_XferDone(c_appl);
}

LINKDLL void
ce_ChangeProtocol(ce_appl_intf_t *c_appl, char *protocol_name)
{
    ce_intrn_ChangeProtocol(c_appl, protocol_name);
}

LINKDLL void
ce_ChangeProperties(ce_appl_intf_t *c_appl, char *properties)
{
    ce_intrn_ChangeProperties(c_appl, properties);
}

LINKDLL void
ce_MLPrintOverride(void (*handler)(char *msg))
{
    ce_intrn_MLPrintOverride(handler);
}
    
LINKDLL void
ce_MLUncaughtException(void (*handler)(char *info))
{
    ce_intrn_MLUncaughtException(handler);
}
    
LINKDLL void
ce_AddSockRecv(CE_SOCKET socket, ce_handler_t handler, ce_env_t env)
{
    ce_intrn_AddSockRecv(socket, handler, env);
}

LINKDLL void
ce_RmvSockRecv(CE_SOCKET socket)
{
    ce_intrn_RmvSockRecv(socket);
}


/****************************************************************************/

LINKDLL void
ce_flat_Cast(ce_appl_intf_t *c_appl, ce_len_t len, ce_data_t buf)
{
    ce_intrn_flat_Cast(c_appl, len, buf);
}

LINKDLL void
ce_flat_Send(ce_appl_intf_t *c_appl, int num_dests,
	     ce_rank_array_t dests, ce_len_t len, ce_data_t buf)
{
    ce_intrn_flat_Send(c_appl, num_dests, dests, len, buf);
}

LINKDLL void
ce_flat_Send1(ce_appl_intf_t *c_appl, ce_rank_t dest, ce_len_t len,
		    ce_data_t buf)
{
    ce_intrn_flat_Send1(c_appl, dest, len, buf); 
}

/****************************************************************************/
