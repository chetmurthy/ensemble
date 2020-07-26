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
/* SOCKFD.C: socket/fd conversion function. */
/* Author: Mark Hayden, 10/97 */
/**************************************************************/
#include "skt.h"
/**************************************************************/

ocaml_skt socket_val(value sock_v) {
  /*assert(Is_block(sock_v)) ;*/
  return Socket_val(sock_v) ;
}

#ifndef _WIN32
/* We wrap file descriptor in an abstract object to get the same
 * behavior for Sockets on Unix as on Windows.  
 */
value skt_socket_of_fd(value fd_v) { /* ML */
  value res = alloc(1, Abstract_tag) ;
  Field(res,0) = fd_v ;
  return res;
}

value skt_fd_of_socket(value sock_v) { /* ML */
  return Field(sock_v,0) ;
}

#if 0
/* Get the file descriptor inside the wrapper.
 */
ocaml_skt Socket_val(value sock_v) {
  return Int_val(Field(sock_v,0)) ;
}
#endif

/* On Unix, these are just Ocaml integers.
 */
value skt_int_of_file_descr(value fd_v) { /* ML */
  return fd_v ;
}

#else

/* Sockets and file descriptors are the same thing under Windows.  
 */
value skt_socket_of_fd(value fd_v) { return fd_v ; } /* ML */
value skt_fd_of_socket(value sock_v) { return sock_v ; } /* ML */

#if 0
/* Get the file descriptor inside the wrapper.
 */
#define Handle_val(v) (*((HANDLE *)(v))) /* from unixsupport.h */
ocaml_skt Socket_val(value sock_v) {
  return Handle_val(sock_v) ;
}
#endif

/* Return an integer representation of the handle.
 */
value skt_int_of_file_descr(value fd_v) { /* ML */
  return Val_long((long)Socket_val(fd_v)) ;
}

#endif

