/**************************************************************/
/* CE_OUTBOARD_COMM.C */
/* Author: Ohad Rodeh 3/2002 */
/* Based on code by Mark Hayden and Alexey Vaysbrud. */
/**************************************************************/
/* This module contains all outboard communication setup code.
 */
/**************************************************************/

#ifndef __CE_COMM_H__
#define __CE_COMM_H__

#include "ce_internal.h"
#ifdef _WIN32
#include "process.h"
#else
#include <stdarg.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <sys/types.h>
#include <sys/wait.h>
#endif

/* Need a well-known port for connect to server */
#define OUTBOARD_TCP_PORT 5002

/* connect to an existing Ensemble server through TCP
 */
void ens_tcp_init(void *env, char * argv[], /*OUT*/ int *fd);

/* Create a socket for internal process communication
 */
void ce_internal_sock(CE_SOCKET *sock, struct sockaddr_in *addr);

/* Basic TCP (blocking) send and recv. 
 */
void tcp_recv(CE_SOCKET s, int len, char *buf);
void tcp_send(CE_SOCKET s, int len, char *buf);


/* TCP (blocking) send/recv for iovectors.
 */

/* The iovector is allocated by the caller, and its length field
 * is already set. The function (blocing) reads all bytes until
 * completion, or, until an error occurs. 
 */
void tcp_recv_iov(CE_SOCKET s, int len, char *buf, ce_iovec_t *iov);

/* Send an Iovec [iovl], prefixed by a buffer [buf] of length [len].
 */
void tcp_send_iov(CE_SOCKET s, int len, char *buf, int num, ce_iovec_array_t iovl);

#endif /*__CE_COMM_H__*/

