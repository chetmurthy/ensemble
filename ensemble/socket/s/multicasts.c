/**************************************************************/
/* MULTICAST.C: support for IPMC operations. */
/* Author: Ohad Rodeh 7/2001 */
/* Based on code by Mark Hayden */
/**************************************************************/
#include "skt.h"

#ifndef _WIN32

#ifndef HAS_SOCKETS
#error No socket support, cannot compile the optimized socket library.
#endif

/* Include these here so that the IPM_BASE
 * option will work.
 */
#ifdef UNIX
#include <sys/ioctl.h>
#endif

/**************************************************************/
value skt_has_ip_multicast(void) {	/* ML */
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
    serror("setsockopt(time-to-live)");

  return Val_unit;
}


/**************************************************************/
/* Join an IP multicast group.
 */
value skt_setsockopt_join(		
		      value sock_v,
		      value group_inet_v,
		      value port_v  // Unused here.
) {
  int sock = Int_val(sock_v);
  uint32 group_inet = GET_INET_ADDR(group_inet_v);
  struct ip_mreq mreq ;
  int ret ;

  if (!(IN_MULTICAST(ntohl(group_inet))))
    serror("setsockopt:join address is not a class D address");
  
  mreq.imr_multiaddr.s_addr = group_inet;
  mreq.imr_interface.s_addr = htonl(INADDR_ANY) ;

  ret = setsockopt(sock, IPPROTO_IP, IP_ADD_MEMBERSHIP,
		   (void*)&mreq, sizeof(mreq)) ;

  if (ret < 0) serror("setsockopt:join");
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

  if (ret < 0) serror ("setsockopt:loopback");
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

  if (ret < 0)  serror("setsockopt:leave");
  return Val_unit ;
}


value skt_socket_mcast(value domain_v, value type_v, value proto_v){
  invalid_argument("calling: skt_socket_mcast on a Unix platform");
}

/**************************************************************/
/**************************************************************/
/**************************************************************/
#else /* WIN32 */

/**************************************************************/

value skt_has_ip_multicast() {	/* ML */
  return Val_true ; 
}

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


value skt_setsockopt_ttl(	
		     value sock_v,
		     value ttl_v
) {
  ocaml_skt_t sock = Socket_val(sock_v);
  int ttl = Int_val(ttl_v);
  char dummy[4];
  int ret ;
  int ret_dummy;

  ret =  WSAIoctl(sock, SIO_MULTICAST_SCOPE,
		  (char*) &ttl, sizeof(int),
		  dummy, 4, &ret_dummy, 0, NULL);

  if (ret < 0) 
    serror("setsockopt(time-to-live)");

  return Val_unit;
}



/* Join an IP multicast group.
 */
value skt_setsockopt_join(		
		      value sock_v,
		      value group_inet_v,
		      value port_v
) {
  ocaml_skt_t sock = Socket_val(sock_v);
  uint32 group_inet = GET_INET_ADDR(group_inet_v);
  int onoff;
  int ret ;
  char dummy[4];
  int ret_dummy;
  struct sockaddr_in addr;

  if (!(IN_MULTICAST(ntohl(group_inet))))
    serror("setsockopt:join address is not a class D address");

    /* Block the socket
   */
  onoff = 0 ;
  ret =  WSAIoctl(sock,   FIONBIO,
		  (char*)&onoff , sizeof(int),
		  dummy, 4, &ret_dummy, 0, NULL);
  if (ret < 0) serror("setsockopt:join:block");

  /* Join
   */
  addr.sin_family = AF_INET;
  addr.sin_port = htons(Int_val(port_v));
  addr.sin_addr.s_addr = GET_INET_ADDR(group_inet_v);
				
  ret = WSAJoinLeaf(sock, (struct sockaddr*)&addr, sizeof(struct sockaddr_in),
		     NULL, NULL, NULL, NULL,
		     JL_BOTH  /* both send and recv */
		     );
  if (ret < 0) {
    printf("Error=%d, sock=%d\n", h_errno, sock);
    serror("setsockopt:join");
  }
  
  /* unblock the socket
   */
  onoff = 1 ;
  ret =  WSAIoctl(sock,   FIONBIO,
		  (char*)&onoff , sizeof(int),
		  dummy, 4, &ret_dummy, 0, NULL);
  if (ret < 0) serror("setsockopt:join:unblock");

  return Val_unit;
}


/* Set the loopback switch.
 */
value skt_setsockopt_loop(
		 value sock_v,
		 value onoff_v)
{
  int sock = Socket_val(sock_v);
  int onoff = Int_val(onoff_v);
  int ret ;
  char dummy[4];
  int ret_dummy;
  BOOL flag;

  flag = (BOOL) onoff;

  ret =  WSAIoctl(sock, SIO_MULTIPOINT_LOOPBACK,
		  (char*) &flag, sizeof(BOOL),
		  dummy, 4, &ret_dummy, 0, NULL);

  if (ret < 0) serror ("setsockopt:loopback");

  return Val_unit;
}

/* Leave an IP multicast group.
 * In winsock2, there is no leave opertaion.
 * We need to close the socket for this. 
 */
value skt_setsockopt_leave(	/* ML */
	value sock_v,
	value group_inet_v
) {
  return Val_unit ;
}


extern int socket_domain_table[];
extern int socket_type_table[];

/* Create a multicast socket. This requires special flags in WINSOCK2.
 */
value skt_socket_mcast(value domain_v, value type_v, value proto_v){
  SOCKET sock;
  
  sock = WSASocket(socket_domain_table[Int_val(domain_v)],
	    socket_type_table[Int_val(type_v)],
	    Int_val(proto_v),
	    NULL, 0, WSA_FLAG_MULTIPOINT_C_LEAF | WSA_FLAG_MULTIPOINT_D_LEAF );

  if (sock == INVALID_SOCKET) serror("skt_socket_mcast");
  SKTTRACE(("skt_socket_mcast: sock=%d\n", sock));
  return Val_socket(sock);
}


#endif /* WIN32 */

/**************************************************************/




