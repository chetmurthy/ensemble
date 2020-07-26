/**************************************************************/
/*
 *  Ensemble, (Version 0.70p1)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
/**************************************************************/
/* MULTICAST.C: support for IPMC operations. */
/* Author: Mark Hayden, 10/96 */
/**************************************************************/
/* Include these here so that the IPM_BASE
 * option will work.
 */
#ifdef UNIX
#include <sys/ioctl.h>
#endif
/**************************************************************/

#include "skt.h"

#if defined(HAS_SOCKETS) && defined(HAS_IP_MULTICAST) && defined (IP_ADD_MEMBERSHIP)

#ifdef BIG_ENDIAN		/* for SP2 */
#undef BIG_ENDIAN
#endif

#ifdef SKT_PROTO
int setsockopt(int s, int level, int optname, const char *optval, int optlen) ;
#endif

value skt_has_ip_multicast() {	/* ML */
  return Val_true ; 
}

/**************************************************************/

/* Do whatever is appropriate to prepare multicast sockets.
 */
value skt_setsock_multicast(	/* ML */
        value sock_v,
	value loopback_v
) {
  ocaml_skt sock = Socket_val(sock_v) ;
  int ret ;
  char char_value ;

  /* Set the time-to-live value to 4:  only within site.
   */
#ifndef WIN32
  char_value = 4 ;
  ret = setsockopt(sock,
		   IPPROTO_IP, IP_MULTICAST_TTL,
		   &char_value, sizeof(char_value)) ;
  if (ret < 0) 
    serror("setsockopt(time-to-live)", Nothing) ;
#endif

#if 0
  {
      /* Set whether or not this socket will have loopback.
       */
      unsigned int int_value ;
      int_value = Bool_val(loopback_v) ;
      ret = setsockopt(sock, IPPROTO_IP, IP_MULTICAST_LOOP,
		       (void*) &int_value, sizeof(int_value)) ;
      if (ret < 0)
	  serror("setsockopt(loopback)", Nothing);
  }
#endif

  return Val_unit ;
}

/**************************************************************/

/* Join an IP multicast group.
 */
value skt_setsock_join(		/* ML */
        value sock_v,
	value group_v
) {
  struct ip_mreq mreq ;
  ocaml_skt sock = Socket_val(sock_v) ;
  int ret ;

  mreq.imr_multiaddr.s_addr = GET_INET_ADDR(group_v) ;
  mreq.imr_interface.s_addr = INADDR_ANY ;

#ifdef NOT_IN_MULTICAST
  /* I can't figure out what is going wrong here, but
   * this check does not seem to work correctly.
   */
  if (!IN_MULTICAST(mreq.imr_multiaddr.s_addr)) {
    serror("setsockopt:join:invalid multicast address", Nothing) ;
  }
#endif
  
  ret = setsockopt(sock, IPPROTO_IP, IP_ADD_MEMBERSHIP, (void*)&mreq, sizeof(mreq)) ;
  if (ret < 0) serror("setsockopt:join", Nothing) ;


#ifdef WIN32
  {
      int ttl ;
      ttl = 31;
      ret = setsockopt(sock,
		       IPPROTO_IP, IP_MULTICAST_TTL,
		       (void *)&ttl, sizeof(ttl)) ;
      if (ret < 0) 
	  serror("setsockopt(time-to-live)", Nothing) ;
  }
#endif
      
  return Val_unit ;
}

/**************************************************************/

/* Leave an IP multicast group.
 */
value skt_setsock_leave(	/* ML */
	value sock_v,
	value group_v
) {
  struct ip_mreq mreq ;
  ocaml_skt sock = Socket_val(sock_v) ;
  int ret ;
  
  mreq.imr_multiaddr.s_addr = GET_INET_ADDR(group_v) ;
  mreq.imr_interface.s_addr = INADDR_ANY ;

#ifdef NOT_IN_MULTICAST
  if (!IN_MULTICAST(mreq.imr_multiaddr.s_addr))
    serror("setsockopt:leave:invalid multicast address", Nothing) ;
#endif

  ret = setsockopt(sock, IPPROTO_IP, IP_DROP_MEMBERSHIP, (void*)&mreq, sizeof(mreq)) ;
  if (ret < 0) serror("setsockopt:leave", Nothing) ;

  return Val_int(ret) ;
}

/**************************************************************/

#else /* HAS_SOCKETS */

value skt_has_ip_multicast()  { return Val_false ; }
value skt_setsock_multicast() { invalid_argument("setsock_multicast not implemented"); }
value skt_setsock_leave()     { invalid_argument("setsock_leave not implemented"); }
value skt_setsock_join()      { invalid_argument("setsock_join not implemented"); }

#endif /* HAS_SOCKETS */

/**************************************************************/




