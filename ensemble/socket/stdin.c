/**************************************************************/
/*
 *  Ensemble, 1.10
 *  Copyright 2001 Cornell University, Hebrew University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
/**************************************************************/
/* STDIN.C */
/* Author: Robbert van Renesse, 10/97 */
/**************************************************************/
#include "skt.h"

#if defined(_WINSOCKAPI_) && defined(HAS_SOCKETS)

/* This software solves the following problem.  We would like applications
 * to be able to run as DOS applications using a command window.  This rules
 * out using Windows window handles and event driven programming (the new
 * SDK contains a separate events package which is supported by Winsock2, but
 * for portability/availability reasons, I haven't considered that option yet).
 * The winsock library has a select() function, but it only works on sockets.
 * You cannot do a select on stdin!  So to make everything work, I'm using a
 * thread that reads stdin, and then sends it to a socket.  The socket handle
 * is used by the Socket library and called Socket.stdin.  This way, it appears
 * as if it's actually reading input.  Beware though:  the thread eats your type
 * ahead!
 */

#define SKT_BUFSIZE 128

static ocaml_skt skt_stdin;
static struct sockaddr_in skt_addr;

/* This thread waits for input, and sends it to socket skt_stdin.
 */
static DWORD skt_input_thread(LPDWORD p){
  char buf[SKT_BUFSIZE];
  int n;
  
  for (;;) {
    n = _read(0, buf, sizeof(buf));
    if (n <= 0) 
      break;
    n = sendto(skt_stdin, buf, n, 0, (struct sockaddr *) &skt_addr,
	       sizeof(skt_addr));
    if (n <= 0) {
      printf("sendto --> %d %d\n", n, h_errno);
      break;
    }
  }
  closesocket(skt_stdin);
  ExitThread(0);
  return 0;
}

/* This function returns Socket.stdin.  It creates a socket for this, and a
 * thread that sends messages to this socket.
 */
value skt_start_input(value unit){
  int fromlen;
  char buf[SKT_BUFSIZE];
  DWORD tid;
  struct sockaddr_in from;
  struct hostent *h;
  
  skt_stdin = socket(AF_INET, SOCK_DGRAM, 0);
  if (skt_stdin < 0)
    serror("start_input:socket", Nothing);
  memset(&skt_addr, 0, sizeof(skt_addr));
  skt_addr.sin_family = AF_INET;
  skt_addr.sin_port = 0;
  gethostname(buf, sizeof(buf));
  h = gethostbyname(buf);
  if (h == 0)
    serror("start_input:gethostbyname", Nothing);
  memcpy(&skt_addr.sin_addr, *h->h_addr_list, h->h_length);
  if (bind(skt_stdin, (struct sockaddr *) &skt_addr,
	   sizeof(skt_addr)) < 0)
    serror("start_input:bind", Nothing);
  fromlen = sizeof(from);
  getsockname(skt_stdin, (struct sockaddr *) &from, &fromlen);
  skt_addr.sin_port = from.sin_port;
  CreateThread(0, 0, (LPTHREAD_START_ROUTINE) skt_input_thread,
	       0, 0, &tid);
  return win_alloc_handle((HANDLE) skt_stdin);
}

#else

value skt_start_input(value unit) { return Val_int(0); }

#endif
