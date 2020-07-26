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
/* ENS_COMM.C */
/* Author: Ohad Rodeh 10/2003 */
/**************************************************************/
/* This module contains all low-level TCP socket code.
 */
/**************************************************************/

#ifndef __ENS_COMM_H__
#define __ENS_COMM_H__

#include "ens.h"

#ifdef _WIN32
#include <process.h>
#include <winsock2.h>
#else
#include <sys/socket.h>
#endif

/**************************************************************/
// Definitions for io-vectors

#ifndef _WIN32
#include <sys/types.h>
#include <sys/socket.h>
typedef struct iovec mm_iovec_t ;
#define Iov_len(iov) (iov).iov_len
#define Iov_buf(iov) (iov).iov_base

#else
#include <winsock2.h>
typedef WSABUF mm_iovec_t ;
#define Iov_len(iov) (iov).len
#define Iov_buf(iov) (iov).buf
#endif
/**************************************************************/

/* The basic definition of a socket is different in Windows and Unix.
 */
#ifdef _WIN32
typedef SOCKET ens_sock_t;
#else
typedef int ens_sock_t;
#endif

/* connect to an existing Ensemble server through TCP.
 * Return 0 on success, -1 on error.
 */
int EnsTcpInit(int port, /*OUT*/ ens_sock_t *sock);

/* Basic TCP (blocking) send and recv. They return 0 on success, 1 on error.
 */
ens_rc_t EnsTcpRecv(ens_sock_t sock, int len, char *buf);

ens_rc_t EnsTcpSend(ens_sock_t sock, int len, char *buf);
ens_rc_t EnsTcpSendIovecl(ens_sock_t s,
                          int len1, char *buf1,
                          int len2, char *buf2,
                          int len3, char *buf3);


/* Check if there is input on the socket.
 * Return:
 *   -1  error
 *    0  no data available
 *    1  there is data to read
 */
int EnsPoll(ens_sock_t sock, int milliseconds);

#endif 

