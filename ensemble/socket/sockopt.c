/**************************************************************/
/*
 *  Ensemble, (Version 1.00)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
/**************************************************************/
#include "skt.h"
/**************************************************************/

#ifdef HAS_SOCKETS

/**************************************************************/

/* Set size of send buffers.
 */
value skt_setsock_sendbuf(	/* ML */
	value sock_v,
	value size_v
) {
  int size = Int_val(size_v) ;
  int sock = Socket_val(sock_v) ;
  int ret ;

  ret = setsockopt(sock, SOL_SOCKET, SO_SNDBUF, (void*)&size, sizeof(size)) ;
  if (ret < 0) serror("setsockopt:sendbuf", Nothing) ;

  return Val_int(ret) ;
}

/**************************************************************/

/* Set size of receive buffers.
 */
value skt_setsock_recvbuf(	/* ML */
	value sock_v,
	value size_v
) {
  int size = Int_val(size_v) ;
  int sock = Socket_val(sock_v) ;
  int ret ;

  ret = setsockopt(sock, SOL_SOCKET, SO_RCVBUF, (void*)&size, sizeof(size)) ;
  if (ret < 0) serror("setsockopt:recvbuf", Nothing) ;

  return Val_int(ret) ;
}

/**************************************************************/

/* Set/reset nonblocking flag on a socket.  
 * Author: JYH.
 */
value skt_setsock_nonblock(	/* ML */
        value sock_v,
	value blk_v
) {
  int ret, sock ;
  sock = Socket_val(sock_v) ;
  
#ifdef _WIN32
  {
    u_long flag ;
    flag = Bool_val(blk_v) ;
    ret = ioctlsocket(sock, FIONBIO, &flag) ;
  }
#else
  {
    int flag ;
    if (Bool_val(blk_v))
      flag = O_NONBLOCK ;
    else
      flag = 0 ;
    ret = fcntl(sock, F_SETFL, flag) ;
  }
#endif
  
  if (ret < 0)
    serror("set_sock_nonblock", Nothing) ;
  return Val_unit ;
}

/**************************************************************/

/* Support for disabling ICMP error reports on Linux.  See
 * ensemble/BUGS.  Also see in the Linux kernel excerpted below:
  
 *   Various people wanted BSD UDP semantics. Well they've come back
 *   out because they slow down response to stuff like dead or
 *   unreachable name servers and they screw term users something
 *   chronic. Oh and it violates RFC1122. So basically fix your client
 *   code people.
 *   (linux/net/ipv4/udp.c, line ~545)
	 
 */
value skt_setsock_bsdcompat(	/* ML */
        value sock_v,
	value bool_v
) {
#ifdef SO_BSDCOMPAT
  int sock ;
  int ret ;
  int flag ;
  sock = Socket_val(sock_v) ;
  flag = Bool_val(bool_v) ;
  ret = setsockopt(sock, SOL_SOCKET, SO_BSDCOMPAT, &flag, sizeof(flag)) ;
  if (ret < 0) serror("setsockopt:bsdcompat", Nothing) ;
#endif
  return Val_unit ;
}

/**************************************************************/

#else /* HAS_SOCKETS */

value skt_setsock_sendbuf() { invalid_argument("setsock_sendbuf not implemented"); }
value skt_setsock_recvbuf() { invalid_argument("setsock_recvbuf not implemented"); }
value skt_setsock_nonblock() { invalid_argument("setsock_nonblock not implemented"); }

#endif /* HAS_SOCKETS */

/**************************************************************/
