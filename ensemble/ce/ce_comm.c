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
/* CE_OUTBOARD_COMM.C */
/* Author: Ohad Rodeh 3/2002 */
/* Based on code by Mark Hayden and Alexey Vaysbrud. */
/**************************************************************/
/* This module contains all outboard communication setup code.
 */
/**************************************************************/
#include "ce_comm.h"
#include "ce_trace.h"
#include <stdio.h>
/**************************************************************/
#define NAME "CE_COMM"
/**************************************************************/
#ifndef _WIN32
static void
init_winsock(void)
{
    return;
}

#else

//#define inet_ntoa inet_addr
void
inet_aton(const char *addr,  struct in_addr *in)
{
    in->S_un.S_addr= inet_addr(addr);
}

void
static init_winsock()
{
    static int done = 0;
    WSADATA         wsaData;

    if (done == 0) {
	//printf("initializing winsock2\n");
	/* Call Windows socket initialization function */
	if (WSAStartup(0x202,&wsaData) == SOCKET_ERROR) {
	    fprintf(stderr,"WSAStartup failed with error %d",WSAGetLastError());
	    WSACleanup();
	    ce_panic("WSAStartup");
	}
	done = 1;
    }
}
#endif

/**************************************************************/
#ifndef _WIN32
#include <unistd.h>
#include <fcntl.h>

void
set_nonblocking(CE_SOCKET sock)
{
    int ret;
    
    ret = fcntl(sock, F_SETFL, O_NONBLOCK) ;
    if (ret < 0) {
	perror("set_sock_nonblock");
	exit(1);
    }
}
#else
void
set_nonblocking(CE_SOCKET sock)
{
    int ret ;
    u_long flag = 1 ;
    ret = ioctlsocket(sock, FIONBIO, &flag) ;

    if (ret < 0) {
	perror("set_sock_nonblock");
	exit(1);
    }
}
#endif

void
ce_internal_sock(CE_SOCKET *sock, struct sockaddr_in *addr)
{
    int fromlen;
    struct sockaddr_in from;
    
    init_winsock();

#ifdef _WIN32
    *sock = WSASocket(AF_INET, SOCK_DGRAM, 0, NULL, 0, WSA_FLAG_OVERLAPPED);
#else
    *sock = socket(AF_INET, SOCK_DGRAM, 0);
#endif
    
    if (*sock <= 0)
	ce_panic("Could not create internal socket");
    memset(addr, 0, sizeof(struct sockaddr_in));

    inet_aton("127.0.0.1",&(addr->sin_addr));
    addr->sin_family = AF_INET;
    addr->sin_port = 0;
    if (bind(*sock, (struct sockaddr *) addr, sizeof(struct sockaddr_in)) < 0)
	ce_panic("internal socket:bind");
    fromlen = sizeof(from);
    getsockname(*sock, (struct sockaddr *) &from, &fromlen);
    addr->sin_port = from.sin_port;

    TRACE("setting a non-blocking socket"); 
    set_nonblocking(*sock);
}

/**************************************************************/

void
ens_tcp_init(void *env, char * argv[], /*OUT*/ int *fd)
{
    int result ;
    int sinlen ;
    struct hostent *hep ;
    char  my_host[64];
    struct sockaddr_in sin;
    
    ce_trace(NAME, "ens_tcp_init");

    /* Call Windows socket initialization function */
    init_winsock();

    /* Get my host name in preparation for connect */
    result = gethostname(my_host, 64);
    if (result < 0)
	ce_panic("gethostname");
    
    /* Use my host name to get hostent in preparation for connect */
    
    memset(&sin, 0, sizeof(sin)) ;
    hep = gethostbyname(my_host);
//    if (hep == (struct hostent *)NULL) {
	// try localhost
	inet_aton("127.0.0.1",&(sin.sin_addr));
	//ce_panic("gethostbyname");
//    } else {
	/* Copy hostent's addr into sin_addr.
	 */
//	memcpy(&(sin.sin_addr),hep->h_addr,hep->h_length);
//    }
    
    sin.sin_family = AF_INET;
    sin.sin_port = ntohs(OUTBOARD_TCP_PORT);
    sinlen = sizeof(sin);  
    
    printf("TCP connect to %s port %d", inet_ntoa(sin.sin_addr), ntohs(sin.sin_port)); fflush(stdout);
    
    /* Now call connect, waiting for accept */
    
    {
	int sock ;
	
	/* Create our socket.
	 */
	sock = socket(AF_INET, SOCK_STREAM, 0);
	if (sock < 0) {
	    ce_panic("socket");
	}
	
	result = connect(sock, (struct sockaddr *)&sin, sinlen) ;
	if (result < 0)
	    ce_panic("connect") ;
	
	*fd = (int)sock;
    }
    
    ce_trace(NAME, "TCP connected"); 
}

/**************************************************************/
/* Basic TCP (blocking) send and recv. 
 */
void
tcp_recv(CE_SOCKET s, int len, char *buf)
{
    int result, ofs;
    
    ce_trace(NAME, "tcprecv: %d",len);
    for (ofs=0 ; ofs < len ; ofs += result) {
	result = recv(s, buf+ofs, len-ofs, 0);
	ce_trace(NAME, "tcprecv: got %d bytes", result);
	
	if (result == 0) 
	    ce_panic("lost connection to outboard") ;
	
	if (result == -1) {
#ifdef EINTR
	    if (errno == EINTR) continue ;
#endif
	    ce_panic("recv: lost connection to outboard") ;
	}
    }
}

void
tcp_send(CE_SOCKET s, int len, char *buf)
{
    int result, ofs;
    
    ce_trace(NAME, "tcpsend: %d",len);
    for (ofs=0 ; ofs < len ; ofs += result) {
	result = send(s, buf+ofs, len-ofs, 0);
	if (result == -1) {
#ifdef EINTR
	    if (errno == EINTR) continue ;
#endif
	    ce_panic("send: lost connection to outboard") ;
	}
    }
}

/**************************************************************/
/* TCP (blocking) send/recv for iovectors.
 */

/* The iovector is allocated by the caller, and its length field
 * is already set. The function (blocking) reads all bytes until
 * completion, or, until an error occurs. 
 */
void
tcp_recv_iov(CE_SOCKET s, int len, char *buf, ce_iovec_t *iov)
{
    tcp_recv(s, len, buf);
    tcp_recv(s, Iov_len(*iov), Iov_buf(*iov));
    ce_trace(NAME, "tcp_recv_iov len=%d, iov_len=%d\n", len, Iov_len(*iov));
}


void
tcp_send_iov(CE_SOCKET s, int len, char *buf, int num, ce_iovec_array_t iovl)
{
    int i;

    tcp_send(s, len, buf);
    for(i=0; i<num; i++)
	tcp_send(s, Iov_len(iovl[i]), Iov_buf(iovl[i])); 
}


