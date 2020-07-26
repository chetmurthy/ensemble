/**************************************************************/
/* CE_VIEW.H */
/* Author: Ohad Rodeh  8/2001 */
/* Internal definitions and include files. */
/**************************************************************/

#ifndef __CE_INTERNAL_H__
#define __CE_INTERNAL_H__

#define CE_MAKE_A_DLL

#include "caml/mlvalues.h"
#include "caml/memory.h"
#include "caml/callback.h"
#include "caml/alloc.h"
#include "caml/config.h"

#include <string.h>  // UNIX
#include <assert.h>

#include "ce.h"
#include "sockfd.h"
#include "ce_actions.h"
#include "ce_convert.h"

/* A type used for encoding return codes from functions.
 */
typedef enum {
    CE_YES,
    CE_NO
} ce_reply_t;

/* A serial tag attached to the interface. Used internally by the
 * outboard mode.
 */
typedef int ce_ctx_id_t;

/* The representation of the application interface. This should
 * hidden from
 * the user, which has only a constructor in ce.h. The destructor is
 * not needed, because the interface is freed automatically when the
 * ce_app_exit_t function is called. 
 */
struct ce_appl_intf_t {
    ce_env_t env;
    ce_ctx_id_t id;

    int joining;
    int leaving;
    int blocked;

    struct ce_queue *aq; /*  Contains the current set of queued actions */
    ce_bool_t req_heartbeat;   /*  For internal use */
    
    /*  After this is called, the interface (ce_appl_intf_f*) is freed.
     */
    ce_appl_exit_t exit ;
    
    /*  Note that the view state and local state records passed up are
     * "owned" by the application.
     * These records are pointed to by the 'vs', and 'ls' variables. 
     */
    ce_appl_install_t install ;
    
    /* These use the state returned by install.
     */
    ce_appl_flow_block_t flow_block ;
    ce_appl_block_t block ;
    
    /* The data passed up with the receive call is not
     * owned by the application. It is freed after the callback
     * by Ensemble. 
     */
    ce_appl_receive_cast_t receive_cast ;
    ce_appl_receive_send_t receive_send ;
    
    ce_appl_heartbeat_t heartbeat ;
} ;

/* We provide our own allocation function that exits
 * the program if no space is left. 
 */
void* ce_malloc(int);

void* ce_realloc(void*, int);

/* The user should not free application interfaces.
 * This is performed by the system upon the exit callback. 
 */
void ce_intf_free(ce_appl_intf_t*);


/* Process command line arguments. Return un-processed arguments.
 */
char **
ce_process_args(int argc, char **argv); 

void ce_panic(char *s);

/**************************************************************/
/* The internal functions. These are used to allow wrapping
 * from the outside for thread safety, while keeping the same
 * names. A neccessary hassle. 
 */

/* The basic create_intf function, defined in misc.c
 */
ce_appl_intf_t*
ce_st_create_intf(ce_env_t env, ce_appl_exit_t exit,
		     ce_appl_install_t install, ce_appl_flow_block_t flow_block,
		     ce_appl_block_t block, ce_appl_receive_cast_t cast,
		     ce_appl_receive_send_t send, ce_appl_heartbeat_t heartbeat
    );

ce_appl_intf_t*
ce_mt_create_intf(ce_env_t env, ce_appl_exit_t exit,
		     ce_appl_install_t install, ce_appl_flow_block_t flow_block,
		     ce_appl_block_t block, ce_appl_receive_cast_t cast,
		     ce_appl_receive_send_t send, ce_appl_heartbeat_t heartbeat
    );


/**************************************************************/
/* The single-threaded functions
 */
void ce_st_Init(int argc,char **argv) ;

void ce_st_Main_loop(void);

void ce_st_Join(ce_jops_t *ops, ce_appl_intf_t *c_appl) ;

void ce_st_Leave(ce_appl_intf_t *c_appl) ;

void ce_st_Cast(ce_appl_intf_t *c_appl, int num, ce_iovec_array_t iovl) ;

void ce_st_Send(ce_appl_intf_t *c_appl, int num_dests, ce_rank_array_t dests, int num, ce_iovec_array_t iovl) ;

void ce_st_Send1(ce_appl_intf_t *c_appl, ce_rank_t dest, int num, ce_iovec_array_t iovl) ;

void ce_st_Prompt(ce_appl_intf_t *c_appl);

void ce_st_Suspect(ce_appl_intf_t *c_appl, int num, ce_rank_array_t suspects);

void ce_st_XferDone(ce_appl_intf_t *c_appl) ;

void ce_st_Rekey(ce_appl_intf_t *c_appl) ;

void ce_st_ChangeProtocol(ce_appl_intf_t *c_appl, char *protocol_name) ;

void ce_st_ChangeProperties(ce_appl_intf_t *c_appl, char *properties) ;

void ce_st_MLPrintOverride(void (*handler)(char *msg)) ;
    
void ce_st_MLUncaughtException(void (*handler)(char *info)) ;
    
void ce_st_AddSockRecv(CE_SOCKET socket, ce_handler_t handler, ce_env_t env);

void ce_st_RmvSockRecv(CE_SOCKET socket);

/**************************************************************/

/* The multi-threaded functions
 */
void ce_mt_Init(int argc,char **argv) ;

void ce_mt_Main_loop(void);

void ce_mt_Join(ce_jops_t *ops, ce_appl_intf_t *c_appl) ;

void ce_mt_Leave(ce_appl_intf_t *c_appl) ;

void ce_mt_Cast(ce_appl_intf_t *c_appl, int num, ce_iovec_array_t iovl) ;

void ce_mt_Send(ce_appl_intf_t *c_appl, int num_dests, ce_rank_array_t dests, int num, ce_iovec_array_t iovl) ;

void ce_mt_Send1(ce_appl_intf_t *c_appl, ce_rank_t dest, int num, ce_iovec_array_t iovl) ;

void ce_mt_Prompt(ce_appl_intf_t *c_appl);

void ce_mt_Suspect(ce_appl_intf_t *c_appl, int num, ce_rank_array_t suspects);

void ce_mt_XferDone(ce_appl_intf_t *c_appl) ;

void ce_mt_Rekey(ce_appl_intf_t *c_appl) ;

void ce_mt_ChangeProtocol(ce_appl_intf_t *c_appl, char *protocol_name) ;

void ce_mt_ChangeProperties(ce_appl_intf_t *c_appl, char *properties) ;

void ce_mt_MLPrintOverride(void (*handler)(char *msg)) ;
    
void ce_mt_MLUncaughtException(void (*handler)(char *info)) ;
    
void ce_mt_AddSockRecv(CE_SOCKET socket, ce_handler_t handler, ce_env_t env);

void ce_mt_RmvSockRecv(CE_SOCKET socket);

/**************************************************************/
#endif /*__CE_INTERNAL_H__*/
