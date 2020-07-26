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
/* On Unix, these are just Ocaml integers.
 */
value skt_int_of_file_descr(value fd_v) { /* ML */
  return fd_v ;
}

#else

/* Heap-allocation of Windows file handles.
 * Copied from win32unix/unixsupport.c
 */
value skt_win_alloc_handle(HANDLE h)
{
  value res = alloc_small(sizeof(HANDLE) / sizeof(value), Abstract_tag);
  Handle_val(res) = h;
  return res;
}

/* Return an integer representation of the handle.
 */
value skt_int_of_file_descr(value fd_v) { /* ML */
  return Val_long((long)Socket_val(fd_v)) ;
}

#endif

