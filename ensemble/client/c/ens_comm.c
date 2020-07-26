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
/* CE_OUTBOARD_COMM.C */
/* Author: Ohad Rodeh 3/2002 */
/* Based on code by Mark Hayden and Alexey Vaysbrud. */
/**************************************************************/
/* This module contains all outboard communication setup code.
 */
/**************************************************************/
#include "ens_utils.h"
#include "ens_comm.h"

#include <stdio.h>

#ifndef _WIN32
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdarg.h>
#include <unistd.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <sys/types.h>
#include <sys/wait.h>
#endif
/**************************************************************/
#define NAME "COMM"
/**************************************************************/
static mm_iovec_t send_iova[3];
static mm_iovec_t recv_iova[3];

#ifndef _WIN32
static struct msghdr send_msghdr = {
    NULL,/*(caddr_t) &sin,*/
    0,/*sizeof(sin),*/
    send_iova,
    0,
    NULL,
    0
} ;
#endif

INLINE static void gather(mm_iovec_t iova[],
                     int len1, char *buf1,
                     int len2, char *buf2,
                     int len3, char *buf3)
{
    Iov_len(iova[0]) = len1;
    Iov_buf(iova[0]) = buf1;
    Iov_len(iova[1]) = len2;
    Iov_buf(iova[1]) = buf2;
    Iov_len(iova[2]) = len3;
    Iov_buf(iova[2]) = buf3;
}

/**************************************************************/

static void InitWinsock(void);

/**************************************************************/
#ifndef _WIN32

static void InitWinsock(void)
{
    return;
}

#else

//#define inet_ntoa inet_addr
static void inet_aton(const char *addr,  struct in_addr *in)
{
    in->S_un.S_addr= inet_addr(addr);
}

static void InitWinsock(void)
{
    static int done = 0;
    WSADATA         wsaData;

    if (done == 0) {
	//printf("initializing winsock2\n");
	/* Call Windows socket initialization function */
	if (WSAStartup(0x202,&wsaData) == SOCKET_ERROR) {
	    fprintf(stderr,"WSAStartup failed with error %d",WSAGetLastError());
	    WSACleanup();
	    EnsPanic("WSAStartup");
	}
	done = 1;
    }
}
#endif

/**************************************************************/

int EnsTcpInit(int port, /*OUT*/ ens_sock_t *sock)
{
    int result ;
    int sinlen ;
    struct hostent *hep ;
    char  my_host[64];
    struct sockaddr_in sin;
    ens_sock_t s;
    
    EnsTrace(NAME,"ens_tcp_init");

    /* Call Windows socket initialization function */
    InitWinsock();

    /* Get my host name in preparation for connect */
    result = gethostname(my_host, 64);
    if (result < 0)
	EnsPanic("gethostname");
    
    /* Use my host name to get hostent in preparation for connect */
    
    memset(&sin, 0, sizeof(sin)) ;
    hep = gethostbyname(my_host);
    inet_aton("127.0.0.1",&(sin.sin_addr));
    sin.sin_family = AF_INET;
    sin.sin_port = ntohs(port);
    sinlen = sizeof(sin);  
    
    printf("TCP connect to %s port %d\n",
	   inet_ntoa(sin.sin_addr), ntohs(sin.sin_port)); fflush(stdout);
    
    /* Create our socket.
     */
    s = socket(AF_INET, SOCK_STREAM, 0);
    if (s < 0) {
	EnsTrace(NAME,"socket");
	return -1;
    }
    
    /* Now call connect, waiting for accept
     */
    result = connect(s, (struct sockaddr *)&sin, sinlen) ;
    if (result < 0) {
	EnsTrace(NAME,"connect") ;
	return -1;
    }

    // Set the output parameter
    *sock = s;
    
    EnsTrace(NAME,"TCP connected");
    return 0;
}

/**************************************************************/
/* Basic TCP (blocking) send and recv. 
 */
ens_rc_t EnsTcpRecv(ens_sock_t s, int len, char *buf)
{
    int result, ofs;
    
    EnsTrace(NAME,"tcprecv: %d",len);
    for (ofs=0 ; ofs < len ; ofs += result) {
	result = recv(s, buf+ofs, len-ofs, 0);
	EnsTrace(NAME,"tcprecv: got %d bytes", result);
	
	if (result == 0) {
	    EnsTrace(NAME,"lost connection to server") ;
	    return ENS_ERROR;
	}
	
	if (result == -1) {
#ifdef EINTR
	    if (errno == EINTR) continue ;
#endif
	    EnsTrace(NAME,"recv: lost connection to server") ;
	    return ENS_ERROR;
	}
    }
    return ENS_OK;
}

ens_rc_t EnsTcpSend(ens_sock_t s, int len, char *buf)
{
    int result, ofs;
    
    EnsTrace(NAME,"tcpsend: %d", len);
    for (ofs=0 ; ofs < len ; ofs += result) {
	result = send(s, buf+ofs, len-ofs, 0);
	if (result == -1) {
#ifdef EINTR
	    if (errno == EINTR) continue ;
#endif
	    EnsTrace(NAME,"send: lost connection to outboard") ;
	    return ENS_ERROR;
	}
    }

    return ENS_OK;
}

/**************************************************************/
ens_rc_t EnsTcpSendIovecl(ens_sock_t s,
                          int len1, char *buf1,
                          int len2, char *buf2,
                          int len3, char *buf3)
{
    int nvecs = 0;
    int total_len = len1 + len2 + len3;
    int ret = 0, len=0;
    
    EnsTrace(NAME,"tcpsend_iovecl: %d %d %d", len1, len2, len3);
    if (len3>0) nvecs =3;
    else nvecs=2;
    gather(send_iova, len1, buf1, len2, buf2, len3, buf3);
        
#ifndef _WIN32
    send_msghdr.msg_iovlen = nvecs;
    ret = sendmsg(s, &send_msghdr, 0) ;
    if (-1 == ret)
        return ENS_ERROR;
    if (ret != total_len) EnsPanic("Error, did not send everything");
#else
    ret = WSASend(s, send_iova, nvecs, &len, 0, NULL, NULL);

    if (SOCKET_ERROR == ret)
        return ENS_ERROR;        
    if (len != total_len) EnsPanic("Error, did not send everything");
#endif
    
    return ENS_OK;
}

/**************************************************************/

int EnsPoll(ens_sock_t s, int milliseconds)
{
    fd_set readfs;
    struct timeval tv;
    int retcode;
    int rc;

    tv.tv_sec = milliseconds / 1000;
    tv.tv_usec = (milliseconds - tv.tv_sec*1000) * 1000;

    EnsTrace(NAME, "sec=%d  usec=%d", tv.tv_sec, tv.tv_usec);
 again:
    FD_ZERO(&readfs);
    FD_SET(s, &readfs);
#ifdef _WIN32
    retcode = select(FD_SETSIZE, &readfs, NULL, NULL, &tv) ;
#else
    retcode = select(s+1, &readfs, NULL, NULL, &tv) ;
#endif    
#ifdef EINTR    
    if (EINTR == retcode)
	goto again;
#endif
#ifdef WSAEINTR
    if (WSAEINTR == retcode)
	goto again;
#endif    
    
    EnsTrace(NAME, "EnsPoll, retcode=%d", retcode);
    
    // Error case
    if (retcode == -1)
        rc = -1;
    // There is data on the socket
    else if (FD_ISSET(s, &readfs))
	rc = 1;
    // There is no data available
    else
        rc = 0;

    EnsTrace(NAME, "Poll=%d", rc);
    return rc;
}

/**************************************************************/


