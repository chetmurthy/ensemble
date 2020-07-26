/**************************************************************/
/* CE.H */
/* Author: Ohad Rodeh */
/* Based on code by Mark Hayden and Alexey Vaysburd. */
/**************************************************************/
/*! \file
 * CE is a C-interface to the Ensemble system. It attempt to 
 * provide a simple to use basis from which to build Ensemble
 * applications. To use this interface, one has to read 
 * this H file, and link with the ce library --- libce.a on
 * Unix systems, and libce.lib on WIN32.
 */
/**************************************************************/

#ifndef __CE_H__
#define __CE_H__

#include "e_iovec.h"

#ifdef _WIN32
#include <winsock2.h>
#endif

/*! The type of floats used here. Should be the same as an
 * ML float.
 */
typedef double      ce_float_t ;

/*! The type of boolean values.
 */
typedef int         ce_bool_t ;

/*! The type of member ranks, an integer. Each group member
 * is ranked between 0 and (nmembers-1), this allows a very 
 * simple addressing scheme. 
 */
typedef int         ce_rank_t ;

/*! The type of logical time. Used in defining view id's.
 */
typedef int         ce_ltime_t ;

/*! The type of message length, an integer. 
 */
typedef int         ce_len_t ;

/*! The type of application environments. An application can set its
 * envrionmet for a specific C-interface, each callback on that C-interface
 * will use this variable. 
 */
typedef void       *ce_env_t ;

/*! The type of time. 
 */
typedef double      ce_time_t ;

/*! The type of endpoint names. This name does not change throughout an
 * endpoint's life.
 */
typedef char*       ce_endpt_t;

/*! The type of addresses. 
 */
typedef char*       ce_addr_t;

/*! The type of data.
 */
typedef char       *ce_data_t;

/*! An Io-vector array.
 * ce_iovec_t is defined in mm.h.
 */
typedef ce_iovec_t *ce_iovec_array_t;

/*! Arrays of endpoints, these are null terminated arrays of pointers to
 * ce_endpt_t.
 */
typedef ce_endpt_t *ce_endpt_array_t ;

/*! Arrays of ranks.
 */
typedef ce_rank_t  *ce_rank_array_t ;

/*! Arrays of addresses. A null terminated array containing pointers to
 * addresses. 
 */
typedef ce_addr_t  *ce_addr_array_t ;

/*! 
 * The view_id structure describes the logical view id. 
 * The basic Ensemble supported abstraction is a group, where members
 * can join and leave dynamically. Each membership change is also called
 * a view change, because it changes the composition of the group.
 * Each view has a view_id which is composed of the group
 * leader, and the logical time. A view_id is unique, and there is a
 * partial order on view_id's.
 */
typedef struct ce_view_id_t {
    ce_ltime_t ltime ;
    ce_endpt_t endpt ;
} ce_view_id_t ;

/*! A null terminated array of pointers view_ids.
 */
typedef ce_view_id_t **ce_view_id_array_t;

/*! 
 * The view_state describes the current state of the group, it
 * includes the Ensemble version number, the group name, the rank of the
 * coordinator, and more.
*/
typedef struct ce_view_state_t {
  char* version ;                /*!< The Ensemble version number */
  char* group ;                  /*!< The group name */
  ce_rank_t coord ;              /*!< The rank of the coordinator */
  int ltime ;                    /*!< The logical time of this view */
  ce_bool_t primary ;            /*!< Is this a primary view? */
  char* proto ;                  /*!< The protocol stack in use */
  ce_bool_t groupd ;             /*!<  Are we using the group daemon? */
  ce_bool_t xfer_view ;          /*!<  Is this an xfer view? */
  char* key ;                    /*!<  The security key */
  int num_ids ;                  /*!<  The number of ids in prev_ids */
  ce_view_id_array_t prev_ids ;  /*!<  The set of previous view_id's */
  char *params;                  /*!<  The parameters used */
  ce_time_t uptime ;             /*!<  The time since this group was initiated */
  ce_endpt_array_t view ;        /*!<  The set of endpoints in the view */
  ce_addr_array_t address ;      /*!<  The addresses of group members */
} ce_view_state_t ;

/*! 
 * The local state describes the group-state pertaining to the local
 * member. 
 */
typedef struct ce_local_state_t {
  ce_endpt_t endpt ;             /*!< My endpoint name */
  ce_addr_t addr ;               /*!< My address */
  ce_rank_t rank ;               /*!< My rank in the group */
  char* name ;                   /*!< My name */
  int nmembers ;                 /*!< The number of members in the view */
  ce_view_id_t *view_id ;        /*!< The current view_id */
  ce_bool_t am_coord ;           /*!< Am I the coordinator? */
} ce_local_state_t ;

/*! 
 * A request structure that describes the list of properties an application
 * wishes from a created endpoint. 
 */
typedef struct ce_jops_t {
  ce_time_t hrtbt_rate ;         /*!< The heartbeat rate */
  char *transports ;             /*!< The transport protocols [UDP,TCP,MCAST] */
  char *protocol ;               /*!< The protocol stack to use */
  char *group_name ;             /*!< The group name */
  char *properties ;             /*!< The set of properties */
  ce_bool_t use_properties ;     /*!< Use the properties, instead of the protocol ? */
  ce_bool_t groupd ;             /*!< Use the group daemon? */
  char *params ;                 /*!< The set of parameters */
  ce_bool_t debug ;              /*!< Use the debugging version */
  ce_bool_t client;              /*!< Are we a Client? */
  char *endpt ;                  /*!< the requested endpoint name */
  char *princ ;                  /*!< My principal name (security) */
  char *key ;                    /*!< The security key */
  ce_bool_t secure ;             /*!< Do we want a secure stack (encryption + authentication? */
} ce_jops_t;

/*!  
 * The default set of layers. 
 */
#define CE_DEFAULT_PROTOCOL "Top:Heal:Switch:Leave:Inter:Intra:Elect:Merge:Slander:Sync:Suspect:Stable:Vsync:Frag_Abv:Top_appl:Frag:Pt2ptw:Mflow:Pt2pt:Mnak:Bottom"


/*! The default set of properties. A stack built with these properties
 * will provide relibale sender-ordered multicast and point-to-point
 * communication, as well as virtual synchrony. 
 */
#define CE_DEFAULT_PROPERTIES "Gmp:Sync:Heal:Switch:Frag:Suspect:Flow:Slander"

/**************************************************************/
/*
 * Utilities
 */

/*! Create a record.
 */
#define record_create(type, var) ((type)malloc(sizeof(*var)))

/*! Free a record. 
 */ 
#define record_free(rec) free(rec)

/*! Clear a record.
 */
#define record_clear(rec) memset(rec, 0, sizeof(*rec))

/*! copy a C string.
 * @param str : a C string (ends with '\0')
 */
char *ce_copy_string(char *str);

/*! Free a local-state and a view-state.
 * @param ls  A local-state structure.
 * @param vs  A view-state structure. 
 */
void ce_view_full_free(ce_local_state_t *ls, ce_view_state_t* vs);

/*! Free a jops structure.
 * @param jops A join-options structure. 
 */
void ce_jops_free(ce_jops_t*) ;

/**************************************************************/
/*! The application interface. An application has to define several callbacks
 * in order to create an application interface. 
 */

/*! Install is called whenever a new view is installed.
 */
typedef void (*ce_appl_install_t)(ce_env_t, ce_local_state_t*, ce_view_state_t*);

/*! Exit is called when the member leaves. 
 */
typedef void (*ce_appl_exit_t)(ce_env_t) ;

/*! ReceiveCast is called whenever a mulicast message arrives.
 * The iovec array is not owned by the application and should be freed.
 * It can be used for read-only operations, and cannot be assumed to
 * exist after the callback returns. 
 */
typedef void (*ce_appl_receive_cast_t)(ce_env_t, ce_rank_t, int, ce_iovec_array_t) ;

/*! ReceiveSend is called whenever a point-to-point message arrives. 
 * The iovec array is not owned by the application and should be freed.
 * It can be used for read-only operations, and cannot be assumed to
 * exist after the callback returns. 
 */
typedef void (*ce_appl_receive_send_t)(ce_env_t, ce_rank_t, int, ce_iovec_array_t) ;

/*! FlowBlock is called whenever there are flow-control problems, and
 * the application should refrain from sending messages until further
 * notice.
 */
typedef void (*ce_appl_flow_block_t)(ce_env_t, ce_rank_t, ce_bool_t) ;

/*! Block is called whenever a view change is forthcoming. All
 * applications are blocked,  the old view is stabilized,
 * cleaned, and way is made for the new view. 
 */
typedef void (*ce_appl_block_t)(ce_env_t) ;

/*! Heartbeat is called every timeout. The timeout is specified in the jops
 * structure. 
 */
typedef void (*ce_appl_heartbeat_t)(ce_env_t, ce_time_t) ;

/*! The type of application interface. This is created by the constructor
 * ce_create_intf. There is no need for a destructor because Ensemble
 * frees the interface-structure and all related memory once the Exit 
 * callback is called. An application interface is an opaque handle
 * which allows using Ensemble stacks. 
 */
typedef struct ce_appl_intf_t ce_appl_intf_t ;

/**
 * A constructor for application interfaces. 
 * @param env The application environemt, includes application specific data.
 *            All callbacks on this interface will be made with the variable.
 * @param exit       The callback used when the stack is destroyed.
 * @param install    The callback performed when a new view is installed.
 * @param flow_block The callback used when flow-control requires
 *                   the application to block, or unblock. This callback
 *                   is only a recommendation, it does not actually block
 *                   or unblock the application.
 * @param block      A callback used prior to performing a view change. After
 *                   block is called, applications cannot send messages,
 *                   though they may receive them. The application is unblocked *                   when a new view is installed.
 * @param cast       Received a multicast a message. 
 * @param send       Received a point-to-point message. 
 * @param heartbeat  A callback performed periodically. The timeout duration
 *                   is passed to Ensemble in the ce_jops_t structure. 
 * @param ops        A structure describing the join options for this stack.
 *                   Consumed.
 *                   
 */
ce_appl_intf_t*
ce_create_intf(ce_env_t env, 
	       ce_appl_exit_t exit,
	       ce_appl_install_t install,
	       ce_appl_flow_block_t flow_block,
	       ce_appl_block_t block,
	       ce_appl_receive_cast_t cast,
	       ce_appl_receive_send_t send,
	       ce_appl_heartbeat_t heartbeat
	       );

/**************************************************************/

/*! Initialize the Ensemble data structures, and process the
 * command line arguemnts.
 */
void ce_Init(
        int argc,
        char **argv
) ;

/*!  Transfer control to Ensemble, and start the main loop.
 */
void ce_Main_loop (
);
			 
/*! Join a group. 
 * @param ops  A structure describing the join options for this stack. Consumed.
 * @param c_appl An application-interface created earlier.
 */ 
void ce_Join(
        ce_jops_t *ops,
	ce_appl_intf_t *c_appl
) ;

/**************************************************************/
/* The set of actions supported on a group. 
 */

/*! Leave a group.  After this downcall, the context becomes invalid.
 * @param c_appl The stack that should be closed.
 */
void ce_Leave(ce_appl_intf_t *c_appl) ;

/*!  Send a multicast message to the group.
 * @param c_appl The C-interface.
 * @param num The length of the iovec array.
 * @param iovl an array of io-vectors. The iovl array is consumed.
 */
void ce_Cast(
	ce_appl_intf_t *c_appl,
	int num,
	ce_iovec_array_t iovl
) ;

/*!  Send a point-to-point message to a set of group members.
 * @param c_appl The C-interface.
 * @param dests A null terminated sequence of integers.
 * @param num_dests The number of destinations.
 * @param num The length of the iovec array.
 * @param iovl an array of io-vectors. The iovl array is consumed.
 */
void ce_Send(
	ce_appl_intf_t *c_appl,
	int num_dests,
	ce_rank_array_t dests,
	int num,
	ce_iovec_array_t iovl
) ;


/*!  Send a point-to-point message to the specified group member.
 * @param c_appl The C-interface.
 * @param dest The destination.
 * @param num The length of the iovec array.
 * @param iovl an array of io-vectors. The iovl array is consumed.
 */
void ce_Send1(
	ce_appl_intf_t *c_appl,
	ce_rank_t dest,
	int num,
	ce_iovec_array_t iovl
) ;

/*!  Ask for a new View.
 * @param c_appl The C-interface.
 */
void ce_Prompt(
	ce_appl_intf_t *c_appl
);

/*!  Report specified group members as failure-suspected.
 * @param c_appl The C-interface.
 * @param num The length of the suspects array
 * @param suspects A list of member ranks. The array is consumed.
 */
void ce_Suspect(
	ce_appl_intf_t *c_appl,
	int num,
	ce_rank_array_t suspects
);
	
/*!  Inform Ensemble that the state-transfer is complete. 
 * @param c_appl The C-interface.
 */
void ce_XferDone(
	ce_appl_intf_t *c_appl
) ;

/*!  Ask the system to rekey.
 * @param c_appl The C-interface.
 */
void ce_Rekey(
	ce_appl_intf_t *c_appl
) ;

/*!  Request a protocol change.
 * @param c_appl The C-interface.
 * @param protocol_name a string describing the new protocol.
 * The string is a colon separated list of layers, for example: 
 *    "Top:Heal:Switch:Leave:
 *     Inter:Intra:Elect:Merge:Sync:Suspect:
 *     Stable:Vsync:Frag_Abv:Top_appl:
 *     Frag:Pt2ptw:Mflow:Pt2pt:Mnak:Bottom"
 * The protocl_name is consumed.
 */
void ce_ChangeProtocol(
        ce_appl_intf_t *c_appl,
	char *protocol_name
) ;


/*!  Request a protocol change (specify properties).
 * @param c_appl The C-interface.
 * @param properties a string contaning a colon separated list of
 *    properties. For example: "Gmp:Sync:Heal:Switch:Frag:Suspect:Flow:Xfer"
 * The properties string is consumed.
 */
void ce_ChangeProperties(
        ce_appl_intf_t *c_appl,
	char *properties
) ;

/**************************************************************/
/*!  Auxiliary functions.
 */

/*! Allows overriding the default ML value printer.
 * For the power-user.
 */
void ce_MLPrintOverride(
	void (*handler)(char *msg)
) ;

/*! Allows overriding the default ML exception handler.
 * For the power-user.
 */
void ce_MLUncaughtException(
	void (*handler)(char *info)
) ;

/**************************************************************/
/*! CE_Socket allows an os-independent representation for
 * sockets.
 */
#ifdef _WIN32
typedef SOCKET CE_SOCKET ;
#else
typedef int    CE_SOCKET ;
#endif

/*! A handler called when there is input to process on a socket. 
 */
typedef void (*ce_handler_t)(void*);

/*! This call adds a socket to the list Ensemble listens to. 
 * When input on the socket occurs, this handler will be invoked
 * on the specified environment variable.
 * @param socket The socket to listen to.
 * @param handler A handler.
 * @param env An envrionment variable. 
 */
void ce_AddSockRecv(
		    CE_SOCKET socket,
		    ce_handler_t handler,
		    ce_env_t env
		    );

/*! Remove a socket from the list Ensemble listens to.
 *@param socket The socket to remove. 
*/
void ce_RmvSockRecv(
		    CE_SOCKET socket
		    );

/**************************************************************/
/* Here is a simpler "flat" inteface.
 * No iovec's are used, as above, things are zero-copy.
 */





/*! FlatReceiveCast is called whenever a mulicast message arrives.
 * The received message is NOT owned by the application, it can only be used
 * for read-only operations. It can be assumed to exists for the duration of
 * the callback.
 */
typedef void (*ce_appl_flat_receive_cast_t)(ce_env_t, ce_rank_t, ce_len_t, ce_data_t) ;

/*! FlatReceiveSend is called whenever a point-to-point message arrives. 
 * The received message is NOT owned by the application, it can only be used
 * for read-only operations. It can be assumed to exists for the duration of
 * the callback.
 */
typedef void (*ce_appl_flat_receive_send_t)(ce_env_t, ce_rank_t, ce_len_t, ce_data_t) ;

/*! Create an application interface using flat callbacks. 
 */
ce_appl_intf_t*
ce_create_flat_intf(ce_env_t env, 
	       ce_appl_exit_t exit,
	       ce_appl_install_t install,
	       ce_appl_flow_block_t flow_block,
	       ce_appl_block_t block,
	       ce_appl_flat_receive_cast_t cast,
	       ce_appl_flat_receive_send_t send,
	       ce_appl_heartbeat_t heartbeat
	       );


/*!  Send a multicast message to the group.
 * @param c_appl The C-interface.
 * @param len The length of the message.
 * @param buf The data to send. The buffer is consumed.
 */void ce_flat_Cast(
	ce_appl_intf_t *c_appl,
	ce_len_t len, 
	ce_data_t buf
) ;

/*!  Send a point-to-point message to a set of group members.
 * @param c_appl The C-inteface.
 * @param dests A null terminated sequence of integers.
 * @param num_dests The number of destinations.
 * @param len The length of the message.
 * @param buf The data to send. The buffer is consumed.
 */
void ce_flat_Send(
	ce_appl_intf_t *c_appl,
	int num_dests,
	ce_rank_array_t dests,
	ce_len_t len, 
	ce_data_t buf
) ;


/*!  Send a point-to-point message to the specified group member.
 * @param c_appl The C-inteface.
 * @param dest The destination.
 * @param len The length of the message.
 * @param buf The data to send. The buffer is consumed.
 */
void ce_flat_Send1(
	ce_appl_intf_t *c_appl,
	ce_rank_t dest,
	ce_len_t len, 
	ce_data_t buf
) ;

#endif  /* __CE_H__ */

/**************************************************************/

