/**************************************************************/
#include "skt.h"
/**************************************************************/

#ifndef HAS_SOCKETS
#error This platform does not support sockets, cannot compile optimized socket
library.
#endif
/**************************************************************/
/**************************************************************/
/* Unix part
 */
#ifndef  _WIN32

/* Set size of send buffers.
 */
value skt_setsockopt_sendbuf(	/* ML */
	value sock_v,
	value size_v
) {
  int size = Int_val(size_v) ;
  int sock = Socket_val(sock_v) ;
  int ret ;

  ret = setsockopt(sock, SOL_SOCKET, SO_SNDBUF, (void*)&size, sizeof(size)) ;

  if (ret < 0) serror("setsockopt:sendbuf");
  return Val_int(ret) ;
}

/* Set size of receive buffers.
 */
value skt_setsockopt_recvbuf(	/* ML */
	value sock_v,
	value size_v
) {
  int size = Int_val(size_v) ;
  int sock = Socket_val(sock_v) ;
  int ret ;

  ret = setsockopt(sock, SOL_SOCKET, SO_RCVBUF, (void*)&size, sizeof(size)) ;

  if (ret < 0) serror("setsockopt:recvbuf");
  return Val_int(ret) ;
}

/* Set/reset nonblocking flag on a socket.  
 * Author: JYH.
 */
value skt_setsockopt_nonblock(	/* ML */
        value sock_v,
	value blk_v
) {
  int ret, sock ;
  int flag ;

  sock = Socket_val(sock_v) ;
  if (Bool_val(blk_v))
    flag = O_NONBLOCK ;
  else
    flag = 0 ;
  ret = fcntl(sock, F_SETFL, flag) ;
  
  if (ret < 0) serror("set_sock_nonblock");
  return Val_unit ;
}

/* Support for disabling ICMP error reports on Linux.  See
 * ensemble/BUGS.  Also see in the Linux kernel excerpted below:
  
 *   Various people wanted BSD UDP semantics. Well they've come back
 *   out because they slow down response to stuff like dead or
 *   unreachable name servers and they screw term users something
 *   chronic. Oh and it violates RFC1122. So basically fix your client
 *   code people.
 *   (linux/net/ipv4/udp.c, line ~545)
	 
 */
value skt_setsockopt_bsdcompat(	/* ML */
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
  if (ret < 0) serror("setsockopt:bsdcompat");
#endif
  return Val_unit ;
}

value skt_setsockopt_reuse(value sock_v, value onoff_v){
  invalid_argument("calling: skt_setsockopt on a Unix platform");
}

value skt_socket(value domain_v, value type_v, value proto_v){
  invalid_argument("calling: skt_socket on a Unix platform");
}

value skt_connect(value sock_v, value address){
  invalid_argument("calling: skt_connect on a Unix platform");
}

value skt_bind(value sock_v, value addr_v){
  invalid_argument("calling: skt_bind on a Unix platform");
}

value skt_close(value sock_v){
  invalid_argument("calling: skt_close on a Unix platform");
}

value skt_listen(value sock_v, value backlog_v){
  invalid_argument("calling: skt_listen on a Unix platform");
}

value skt_accept(value sock_v){
  invalid_argument("calling: skt_accept on a Unix platform");
}
#else
/**************************************************************/
/**************************************************************/
/* WIN32 part
 */

/* Set size of send buffers.
 */
value skt_setsockopt_sendbuf(	/* ML */
	value sock_v,
	value size_v
) {
  int size = Int_val(size_v) ;
  int sock = Socket_val(sock_v) ;
  int ret ;

  ret = setsockopt(sock, SOL_SOCKET, SO_SNDBUF, (void*)&size, sizeof(size)) ;
  if (ret < 0) serror("setsockopt:sendbuf");
  return Val_int(ret) ;
}

/* Set size of receive buffers.
 */
value skt_setsockopt_recvbuf(	/* ML */
	value sock_v,
	value size_v
) {
  int size = Int_val(size_v) ;
  int sock = Socket_val(sock_v) ;
  int ret ;

  ret = setsockopt(sock, SOL_SOCKET, SO_RCVBUF, (void*)&size, sizeof(size)) ;
  if (ret < 0) serror("setsockopt:recvbuf");
  return Val_int(ret) ;
}

/* Set size of receive buffers.
 */
value skt_setsockopt_reuse(	/* ML */
	value sock_v,
	value onoff_v
) {
  BOOL size = Int_val(onoff_v) ;
  int sock = Socket_val(sock_v) ;
  int ret ;

  ret = setsockopt(sock, SOL_SOCKET, SO_REUSEADDR,(char*)&size, sizeof(size)) ;

  SKTTRACE(("skt_sock_resuse\n"));
  if (ret == -1) serror("setsockopt:reuse");
  return Val_unit;
}


/* Set/reset nonblocking flag on a socket.  
 * Author: JYH.
 */
value skt_setsockopt_nonblock(	/* ML */
        value sock_v,
	value blk_v
) {
  int ret, sock ;
  u_long flag ;

  sock = Socket_val(sock_v) ;
  flag = Bool_val(blk_v) ;
  ret = ioctlsocket(sock, FIONBIO, &flag) ;
  
  SKTTRACE(("skt_sock_nonblock\n"));
  if (ret == -1) serror("set_sock_nonblock");
  return Val_unit ;
}


value skt_setsockopt_bsdcompat(value sock_v, value bool_v) {
  return Val_unit ;
}


//  These are already defined inside CAML.
/*
int socket_domain_table[] = {
  PF_UNIX, PF_INET
};

int socket_type_table[] = {
  SOCK_STREAM, SOCK_DGRAM, SOCK_RAW, SOCK_SEQPACKET
};
*/

extern int socket_domain_table[];
extern int socket_type_table[];

value skt_socket(value domain_v, value type_v, value proto_v){
  SOCKET sock;
  
  sock = WSASocket(socket_domain_table[Int_val(domain_v)],
	    socket_type_table[Int_val(type_v)],
	    Int_val(proto_v),
	    NULL, 0, 0);

  if (sock == INVALID_SOCKET) serror("skt_socket");

  SKTTRACE(("skt_socket: sock=%d\n", sock));
  return Val_socket(sock);
}

value skt_connect(value sock_v, value address){
  union sock_addr_union addr;
  socklen_param_type addr_len;
  int ret;
  
  get_sockaddr(address, &addr, &addr_len);
  ret = WSAConnect(Socket_val(sock_v), &addr.s_gen, addr_len,
		   NULL, NULL, NULL, NULL);

  if (ret < 0) serror("skt_connect") ;
  SKTTRACE(("skt_connect\n"));
  return Val_unit;
}

value skt_bind(value sock_v, value addr_v)
{
  int ret;
  union sock_addr_union addr;
  socklen_param_type addr_len;

  get_sockaddr(addr_v, &addr, &addr_len);
  ret = bind(Socket_val(sock_v), &addr.s_gen, addr_len);
  if (ret == -1) serror("bind");
  SKTTRACE(("bind\n"));
  return Val_unit;
}

value skt_close(value sock_v, value addr_v){
  int ret;
  
  ret = closesocket(Socket_val(sock_v));
  if (ret == -1) serror("socketclose");
  SKTTRACE(("skt_close\n"));
  return Val_unit;
}

value skt_listen(value sock_v, value backlog_v){
  int ret;
  
  SKTTRACE(("skt_listen(\n"));
  ret = listen(Socket_val(sock_v), Int_val(backlog_v));
  SKTTRACE2(("skt_listen)\n"));
  if (ret == -1) serror("listen");
  return Val_unit;
}

/* Defined in sockaddr.c
 */
extern value alloc_sockaddr(union sock_addr_union * adr /*in*/,
			    socklen_param_type adr_len);

value skt_accept(value sock_v){
  SOCKET news;
  union sock_addr_union addr;
  socklen_param_type addr_len;
  CAMLparam1(sock_v);
  CAMLlocal3(pair_v, addr_v, news_v);
  
  SKTTRACE(("skt_accept(\n"));
  news = accept(Socket_val(sock_v),  &addr.s_gen, &addr_len);
  SKTTRACE2((")\n"));

  if (news == INVALID_SOCKET) serror("accept");

  addr_v = alloc_sockaddr(&addr, addr_len);
  news_v = Val_socket(news);
  pair_v = alloc_small(2,0);
  Field(pair_v,0) = news_v;
  Field(pair_v,1) = addr_v;

  CAMLreturn(pair_v);
}
#endif
/**************************************************************/
