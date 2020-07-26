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
/* MISCSUPP.C: miscelaneous support functions */
/* Author: Mark Hayden, 10/97 */
/* Changes: Ohad Rodeh 10/2002 */
/**************************************************************/
#include "skt.h"
/**************************************************************/

value skt_substring_eq(
    value s1_v,
    value ofs1_v,
    value s2_v,
    value ofs2_v,
    value len_v
    )
{
    long len ;
    long ret ;
    char *s1 ;
    char *s2 ;
    
    len = Long_val(len_v) ;
    s1 = ((char*)String_val(s1_v)) + Long_val(ofs1_v) ;
    s2 = ((char*)String_val(s2_v)) + Long_val(ofs2_v) ;
    ret = !memcmp(s1,s2,len) ;
    return Val_bool(ret) ;
}

/**************************************************************/
/* A set of errors to ignore on receiving a UDP packet.
 */
void skt_udp_recv_error(char *debug) {
    switch (h_errno) {
#ifdef EPIPE
    case EPIPE:
#endif
	
#ifdef EINTR
    case EINTR:
#endif
#ifdef EAGAIN
    case EAGAIN:
#endif
	
#ifdef ECONNREFUSED
    case ECONNREFUSED:
#endif

#ifdef ECONNRESET
    case ECONNRESET:
#endif
	
#ifdef ENETUNREACH
    case ENETUNREACH:
#endif
	
#ifdef EHOSTDOWN
    case EHOSTDOWN:
#endif
	
	
#ifdef EISCONN
    case EISCONN:
#endif

	/* Do nothing */
	break ;
    default:
	serror(debug);
	break ;
    }
}

/* Some errors need to be ignored
 */
void skt_tcp_recv_error(char *debug) {
    switch (h_errno) {
    case EAGAIN:
//    case EWOULDBLOCK:
	/* Do nothing */
	break ;

    default:
	serror(debug);
	break;
    }
}

/* unix_error is from unixsupport.c */
extern void uerror(char *cmdname, value cmdarg);

void serror(char *cmdname)
{
    uerror(cmdname, Nothing);
}



