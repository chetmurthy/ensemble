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
// $Header: /cvsroot/ensemble/maestro/Maestro_Config.h,v 1.1.1.1 2003/08/24 06:52:17 nystrom Exp $  

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
//#define MAESTRO_MESSAGE_TYPECHECKING 1


/*************************** default values *********************************/

// Protocol properties used by default by Maestro_GroupMember and derived classes.
#define MAESTRO_DEFAULT_PROTOCOL_PROPERTIES "Gmp:Sync:Heal:Switch:Frag:Suspect:Flow"

#define MAESTRO_DEFAULT_TRANSPORTS "UDP"
#define MAESTRO_DEFAULT_HEARTBEAT_RATE 5000 // msec

#ifdef _WIN32
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
