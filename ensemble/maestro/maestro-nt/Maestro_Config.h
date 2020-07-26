// $Header: /cvsroot/ensemble/maestro/maestro-nt/Maestro_Config.h,v 1.5 2002/10/13 10:06:40 orodeh Exp $  

/***************************************************************/
//
//   Author:  Alexey Vaysburd  December 96
//
//   This file contains compile-time parameters for Maestro
//
/***************************************************************/

// define this to have debugging info printed out (used in putd function):
#define MAESTRO_DEBUG 1

// define this to have run-time typechecking on messages:
// NOTE:  This should NEVER be defined if building for CORBA applications.
// #define MAESTRO_MESSAGE_TYPECHECKING 1     


/*************************** default values *********************************/

// Protocol properties used by default by Maestro_GroupMember and derived classes.
#define MAESTRO_DEFAULT_PROTOCOL_PROPERTIES "Gmp:Sync:Heal:Switch:Frag:Suspect:Flow"

#define MAESTRO_DEFAULT_TRANSPORTS "UDP"
#define MAESTRO_DEFAULT_HEARTBEAT_RATE 5000 // msec

#ifdef WIN32
#define MAESTRO_DEFAULT_OUTBOARD_MODULE "SPAWN"
#else
#define MAESTRO_DEFAULT_OUTBOARD_MODULE "FORK"
#endif

#ifdef INLINE
#define MAESTRO_INLINE inline
#else
#define MAESTRO_INLINE
#endif

// Define this to enable performance tests.
// #define PERFTEST
