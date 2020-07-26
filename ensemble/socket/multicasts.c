/**************************************************************/
/* MULTICAST.C: support for IPMC operations. */
/* Author: Ohad Rodeh 7/2001 */
/* Based on code by Mark Hayden */
/**************************************************************/
#include "skt.h"

#ifndef _WIN32
#ifdef HAS_SOCKETS

/* Include these here so that the IPM_BASE
 * option will work.
 */
#ifdef UNIX
#include <sys/ioctl.h>
#endif

/**************************************************************/
value skt_has_ip_multicast() {	/* ML */
  return Val_true ; 
}

/**************************************************************/
/* Is the address a D class address?
 */
value skt_in_multicast(
		       value inet_addr_v
		       )
{
  int ret;
  uint32 inet_addr = GET_INET_ADDR(inet_addr_v);

  ret = IN_MULTICAST(ntohl(inet_addr));
 
  return Val_bool(ret);
}	   

/**************************************************************/

value skt_setsockopt_ttl(	
		     value sock_v,
		     value ttl_v
) {
  int sock = Int_val(sock_v);
  int ttl = Int_val(ttl_v);
  int ret ;
  unsigned char char_value ;

  char_value = (unsigned char) ttl ;
  ret = setsockopt(sock,
		   IPPROTO_IP, IP_MULTICAST_TTL,
		   &char_value, sizeof(char_value)) ;
  if (ret < 0) 
    serror("setsockopt(time-to-live)", Nothing);

  return Val_unit;
}


/**************************************************************/
/* Join an IP multicast group.
 */
value skt_setsockopt_join(		
		      value sock_v,
		      value group_inet_v
) {
  int sock = Int_val(sock_v);
  uint32 group_inet = GET_INET_ADDR(group_inet_v);
  struct ip_mreq mreq ;
  int ret ;

  if (!(IN_MULTICAST(ntohl(group_inet))))
    serror("setsockopt:join address is not a class D address", Nothing);
  
  mreq.imr_multiaddr.s_addr = group_inet;
  mreq.imr_interface.s_addr = htonl(INADDR_ANY) ;

  ret = setsockopt(sock, IPPROTO_IP, IP_ADD_MEMBERSHIP,
		   (void*)&mreq, sizeof(mreq)) ;
  if (ret < 0) 
    serror("setsockopt:join", Nothing);

  return Val_unit;
}

/**************************************************************/
/* Set the loopback switch.
 */
value skt_setsockopt_loop(
		 value sock_v,
		 value onoff_v)
{
  int sock = Int_val(sock_v);
  int onoff = Int_val(onoff_v);
  int ret ;
  u_char flag;

  flag = onoff;
  ret = setsockopt(sock, IPPROTO_IP, IP_MULTICAST_LOOP,
		   (const char*)&flag, sizeof(flag));

  if (ret < 0)
    serror ("setsockopt:loopback",  Nothing);

  return Val_unit;
}

/**************************************************************/

/* Leave an IP multicast group.
 */
value skt_setsockopt_leave(	/* ML */
	value sock_v,
	value group_inet_v
) {
  struct ip_mreq mreq ;
  uint32 group_inet = GET_INET_ADDR(group_inet_v);
  int sock = Int_val(sock_v) ;
  int ret ;
  
  mreq.imr_multiaddr.s_addr = group_inet ;
  mreq.imr_interface.s_addr = INADDR_ANY ;

  ret = setsockopt(sock, IPPROTO_IP, IP_DROP_MEMBERSHIP,
		   (void*)&mreq, sizeof(mreq)) ;
  if (ret < 0)
    serror("setsockopt:leave", Nothing) ;

  return Val_unit ;
}




/**************************************************************/

#else
value skt_has_ip_multicast()  { return Val_false ; }
value skt_setsockopt_ttl() { invalid_argument("setsockopt_ttl not implemented"); }
value skt_setsockopt_loop() { invalid_argument("setsockopt_loop not implemented"); }
value skt_setsockopt_join() { invalid_argument("setsockopt_join not implemented"); }
value skt_setsockopt_leave() { invalid_argument("setsockopt_leave not implemented"); }
#endif /* HAS_SOCKETS */
/**************************************************************/
/**************************************************************/
/**************************************************************/
#else /* WIN32 */

#define IN_CLASSD(i)            (((long)(i) & 0xf0000000) == 0xe0000000)
#define IN_MULTICAST(i)         IN_CLASSD(i)

/**************************************************************/

value skt_has_ip_multicast() {	/* ML */
  return Val_true ; 
}

/**************************************************************/
/* Is the address a D class address?
 */
value skt_in_multicast(
		       value inet_addr_v
		       )
{
  int ret;
  uint32 inet_addr = GET_INET_ADDR(inet_addr_v);

  ret = IN_MULTICAST(ntohl(inet_addr));
  return Val_bool(ret);
}	   

/**************************************************************/

value skt_setsockopt_ttl(	
		     value sock_v,
		     value ttl_v
) {
  int sock = Socket_val(sock_v);
  int ttl = Int_val(ttl_v);
  int ret ;

  return(setsockopt(sock, IPPROTO_IP, IP_MULTICAST_TTL,
		    (const char*)&ttl, sizeof(ttl)));

  if (ret < 0) 
    serror("setsockopt(time-to-live)", Nothing);

  return Val_unit;
}


/**************************************************************/
/* Join an IP multicast group.
 */
value skt_setsockopt_join(		
		      value sock_v,
		      value group_inet_v
) {
  int sock = Socket_val(sock_v);
  uint32 group_inet = GET_INET_ADDR(group_inet_v);
  struct ip_mreq mreq ;
  int ret ;

  if (!(IN_MULTICAST(ntohl(group_inet))))
    serror("setsockopt:join address is not a class D address", Nothing);

  mreq.imr_multiaddr.s_addr = group_inet;
  mreq.imr_interface.s_addr = htonl(INADDR_ANY) ;

  ret = setsockopt(sock, IPPROTO_IP, IP_ADD_MEMBERSHIP,
		   (const char *)&mreq, sizeof(mreq));

  if (ret < 0) 
    serror("setsockopt:join", Nothing);

  return Val_unit;
}

/**************************************************************/
/* Set the loopback switch.
 */
value skt_setsockopt_loop(
		 value sock_v,
		 value onoff_v)
{
  int sock = Socket_val(sock_v);
  int onoff = Int_val(onoff_v);
  int ret ;
  BOOL flag;

  flag = (BOOL) onoff;
  ret = setsockopt(sock, IPPROTO_IP, IP_MULTICAST_LOOP,
		   (const char*)&flag, sizeof(flag));

  if (ret < 0)
    serror ("setsockopt:loopback",  Nothing);

  return Val_unit;
}

/**************************************************************/

/* Leave an IP multicast group.
 */
value skt_setsockopt_leave(	/* ML */
	value sock_v,
	value group_inet_v
) {
  struct ip_mreq mreq ;
  uint32 group_inet = GET_INET_ADDR(group_inet_v);
  int sock = Socket_val(sock_v) ;
  int ret ;
  
  mreq.imr_multiaddr.s_addr = group_inet ;
  mreq.imr_interface.s_addr = INADDR_ANY ;

  ret = setsockopt(sock, IPPROTO_IP, IP_DROP_MEMBERSHIP,
		   (const char*)&mreq, sizeof(mreq)) ;
  if (ret < 0)
    serror("setsockopt:leave", Nothing) ;

  return Val_unit ;
}

#endif /* WIN32 */

/**************************************************************/




