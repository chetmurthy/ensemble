/**************************************************************/
/*
 *  Ensemble, 2_00
 *  Copyright 2004 Cornell University, Hebrew University
 *           IBM Israel Science and Technology
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
/**************************************************************/
/* ENS.H */
/* Author: Ohad Rodeh 10/2003 */
/**************************************************************/
/*
 * CE is a C-interface to the Ensemble system. It attempt to 
 * provide a simple to use basis from which to build Ensemble
 * applications. To use this interface, one has to read 
 * this H file, and link with the ce library --- libens.a on
 * Unix systems, and libens.lib on WIN32.
 */
/**************************************************************/

#ifndef __ENS_H__
#define __ENS_H__

#include <memory.h>

#ifdef _WIN32
#include <winsock2.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif


/* The maximal number of destinations in an suspect/send event.
 */
#define ENS_DESTS_MAX_SIZE 10

/* Maximal sizes for the various parameters 
 */
#define ENS_PROTOCOL_MAX_SIZE 256
#define ENS_GROUP_NAME_MAX_SIZE 64
#define ENS_PROPERTIES_MAX_SIZE 128
#define ENS_PARAMS_MAX_SIZE 256
#define ENS_ENDPT_MAX_SIZE 48
#define ENS_ADDR_MAX_SIZE 48
#define ENS_PRINCIPAL_MAX_SIZE 32
#define ENS_NAME_MAX_SIZE (ENS_ENDPT_MAX_SIZE+24)
#define ENS_VERSION_MAX_SIZE 8

// The maximal message size
#define ENS_MSG_MAX_SIZE  (32 * 1024)

/* Booleans: represented as integers. If the value is 1 --> TRUE, if the
 * value is 0 --> FALSE.
 * 
 * Member rank: represented as an integer. Each group member
 * is ranked between 0 and (nmembers-1), this allows a very 
 * simple addressing scheme. 
 */

/* The type of endpoint names. This name does not change throughout an
 * endpoint's life.
 */
typedef struct ens_endpt_t {
    char name[ENS_ENDPT_MAX_SIZE];
} ens_endpt_t;
    
/*! The type of addresses. 
 */
typedef struct ens_addr_t {
    char name[ENS_ADDR_MAX_SIZE];
} ens_addr_t;

/* 
 * The view_id structure describes the logical view id. 
 * The basic Ensemble supported abstraction is a group, where members
 * can join and leave dynamically. Each membership change is also called
 * a view change, because it changes the composition of the group.
 * Each view has a view_id which is composed of the group
 * leader, and the logical time. A view_id is unique, and there is a
 * partial order on view_id's.
 */
typedef struct ens_view_id_t {
    int        ltime ;
    ens_endpt_t endpt ;
} ens_view_id_t ;


/*
 * The view_state describes the current state of the group, it
 * includes the Ensemble version number, the group name, the rank of the
 * coordinator, and more.
 */
typedef struct ens_view_t {
    int nmembers ;                           /* The number of members in the view */
    char version[ENS_VERSION_MAX_SIZE] ;     /* The Ensemble version number */
    char group[ENS_GROUP_NAME_MAX_SIZE] ;    /* The group name */
    char proto[ENS_PROTOCOL_MAX_SIZE] ;      /* The protocol stack in use */
    int ltime ;                              /* The logical time of this view */
    int primary ;                            /* Is this a primary view? */
    char params[ENS_PARAMS_MAX_SIZE];        /* The parameters used */
    ens_addr_t  *address ;                   /* The addresses of group members */
    ens_endpt_t *endpts ;                    /* The set of endpoints in the view */
    
    ens_endpt_t endpt ;                      /* My endpoint name */
    ens_addr_t addr ;                        /* My address */
    int rank ;                               /* My rank in the group */
    char name[ENS_NAME_MAX_SIZE];            /* My name */
    ens_view_id_t view_id ;                  /* The current view_id */
} ens_view_t ;

/* 
 * A request structure that describes the list of properties an application
 * wishes from a created endpoint.
 *
 * The format for the string arguments is that they are either all zeros, or, look
 * like a C-string: set of non-zero characters at the beginning, followed by zeros.
 * There has to be at a terminating NULL character.
 */
typedef struct ens_jops_t {
    char group_name[ENS_GROUP_NAME_MAX_SIZE] ; /* The group name */
    char properties[ENS_PROPERTIES_MAX_SIZE] ; /* The set of properties */
    char params[ENS_PARAMS_MAX_SIZE] ;         /* The set of parameters */
    char princ[ENS_PRINCIPAL_MAX_SIZE] ;       /* My principal name (security) */
    int secure ;                               /* Do we want a secure stack (encryption + authentication? */
} ens_jops_t ;

/* The default set of properties. A stack built with these properties
 * will provide relibale sender-ordered multicast and point-to-point
 * communication, as well as virtual synchrony. 
 */
#define ENS_DEFAULT_PROPERTIES "Vsync"

/* The current member status
 */
typedef enum ens_status_t {
    Pre,           /* the initial status */
    Joining,       /* we joining the group */
    Normal,        /* Normal operation state, can send/mcast messages */
    Blocked,       /* we are blocked */
    Leaving,       /* we are leaving */
    Left           /* We have left the group and are in an invalid state */
} ens_status_t;

/* The type of a connection to the Ensemble server. It is opaque to
 * the user. To see the internal representation take a look at the implementation.
 */
typedef struct ens_conn_t ens_conn_t;

/* The type of a group member. Member structures are allocated and
 * initialized using the ens_Join operation (see below). To release
 * the memory allocated use the "free" call.
 */
typedef struct ens_member_t {
 // For internal use. Linked-lists are used to keep track of live members.
    struct ens_member_t *next; 
    int id;
    ens_conn_t *conn;        // The connection through which this endpoint is connected
    ens_status_t current_status; // The current status

    int nmembers;               // Internal use: the number of members in the view
    int rank;                   // Internal use: my rank

    void *user_ctx;             // User contex
} ens_member_t;

/**************************************************************/

typedef enum ens_rc_t {
    ENS_OK = 0,        
    ENS_ERROR = 1
} ens_rc_t;

/**************************************************************/
// The default port the daemon is listening on
#define ENS_SERVER_TCP_PORT 5002

/* Connect to the Ensemble server, return a handle for future communication
 * with the server.
 *
 * @return An opaqe connection structure.
 */
ens_conn_t *ens_Init(int port);

/* Join a group. 
 * @param conn The Ensemble connection.
 * @param memb A prealocated structure that will be set with initial information
 *             about the member.
 * @param ops  A structure describing the join options for this stack.
 * @return     An error code. 
 */ 
ens_rc_t ens_Join(
    ens_conn_t *conn,
    ens_member_t *memb,
    ens_jops_t *ops,
    void *user_ctx
    ) ;

/**************************************************************/
/* The set of actions supported on a group. 
 */

/* Leave a group.  After this downcall, the context becomes invalid.
 * @param memb  A group member.
 * @return      An error code. 
 */
ens_rc_t ens_Leave(
    ens_member_t *memb
    ) ;

/*  Send a multicast message to the group.
 * @param memb  A group member.
 * @param len The length of the message.
 * @param buf The data to send. 
 * @return    An error code. 
 */
ens_rc_t ens_Cast(
    ens_member_t *memb,
    int len, 
    char *buf
    ) ;

/*  Send a point-to-point message to a set of group members.
 * @param memb  A group member.
 * @param dests A sequence of integers.
 * @param num_dests The number of destinations.
 * @param len The length of the message.
 * @param buf The data to send. 
 * @return    An error code. 
 */
ens_rc_t ens_Send(
    ens_member_t *memb,
    int num_dests,
    int *dests,
    int len, 
    char* buf
    ) ;


/*  Send a point-to-point message to the specified group member.
 * @param memb  A group member.
 * @param dest The destination, has to be a valid member rank.
 * @param len The length of the message.
 * @param buf The data to send. 
 * @return          An error code. 
 */
ens_rc_t ens_Send1(
    ens_member_t *memb,
    int dest,
    int len, 
    char* buf
    ) ;

/*  Report specified group members as failure-suspected.
 * @param memb  A group member.
 * @param num The length of the suspects array, the maximal size is ENS_DESTS_MAX_SIZE.
 * @param suspects A list of member ranks. 
 * @return          An error code. 
 */
ens_rc_t ens_Suspect(
    ens_member_t *memb,
    int num,
    int *suspects
     );

/*  Tell the system we will no longer send messages in this view. Should
 * be sent as a reponse to a Block message.
 *
 * @param memb  A group member.
 * @return          An error code. 
 */
ens_rc_t ens_BlockOk(
    ens_member_t *memb
    ) ;

/**************************************************************/
/* Receiving messages from Ensemble
 */

/**
 * The type of a server-to-client message. 
 * 
 * Messages from Ensemble.  Must match the ML side.
 */
typedef enum ens_up_msg_t {
    VIEW = 1,      /* A new view has arrived from the server. */
    CAST = 2,      /* A multicast message */
    SEND = 3,      /* A point-to-point message */
    BLOCK = 4,     /* A block requeset, prior to the installation of a new view */
    EXIT = 5       /* A final notification that the member is no longer valid */
} ens_up_msg_t;


typedef struct ens_msg_t {
    ens_member_t *memb;        /* endpoint this message blongs to */
    ens_up_msg_t mtype ;       /* message type */
    union {
	struct {               /* The variant for VIEW: */
	    int     nmembers;  /* the number of members in a view */    
	} view;
	struct {               /* The variant for a point-to-point message */
	    int     msg_size;  /* length of a bulk-data */
	} send;
	struct {               /* The variant for multicast message */
	    int     msg_size;  /* length of a bulk-data */
	} cast;
    } u;
} ens_msg_t;


/* Receive a message. The user needs to preallocate the
 * message structure.
 *
 * @param conn      The Ensemble connection.
 * @param msg       A strucutre allocated by the user to contain message meta-data.
 * @return          An error code. 
 */
ens_rc_t ens_RecvMetaData(ens_conn_t *conn, ens_msg_t *msg);

/* Receive a view. This call is made directly after an
 * ens_RecvMetaData call. The user is expected
 * to allocate enough space so that Ensemble will be able to copy view
 * data into the view structure.
 *
 * @param conn      The Ensemble connection.
 * @param memb      The member receiving this view. Has to match previous
 *                  ens_RecvMetaData call.
 * @param view      A preallocated data structure that has enough space to hold the
 *                  number of members as indicated in the previous ens_RecvMetaData
 *                  call.
 * @return          An error code. 
 */
ens_rc_t ens_RecvView(ens_conn_t *conn, ens_member_t *memb, /*OUT*/ ens_view_t *view);

/* Receive a message. This call is made directly after an
 * ens_RecvMetaData call. The user is expected to allocate enough space
 * so that Ensemble will be able to copy bulk-message data into
 * user buffers.
 *
 * @param conn      The Ensemble connection.
 * @param buf       A buffer allocated by the user for holding recieved bulk-data.
 *                  Has to be at least of the size indicated by the previous
 *                  ens_RecvMetaData call.
 * @return          An error code. 
 */
ens_rc_t ens_RecvMsg(ens_conn_t *conn, /*OUT*/ int *origin, char *buf);

/* Check if there are pending messages.
 *
 * @param conn      The Ensemble connection.
 * @param milliseconds  The number of milliseconds to wait for input. Can be zero.
 * @param data_available  output argument. 1 if there is data, 0 otherwise.
 * @return          An error code. 
 */
ens_rc_t ens_Poll(ens_conn_t *conn, int milliseconds, /*OUT*/ int *data_available);

/**************************************************************/
#ifdef __cplusplus
}
#endif

#endif  /* __ENS_H__ */

/**************************************************************/

