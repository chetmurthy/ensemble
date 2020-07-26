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
/* SOCKFD.C: socket/fd conversion function. */
/* Author: Mark Hayden, 10/97 */
/**************************************************************/
#include "skt.h"
/**************************************************************/

ocaml_skt_t socket_val(value sock_v) {
  /*assert(Is_block(sock_v)) ;*/
  return Socket_val(sock_v) ;
}

/* On Unix, these are just Ocaml integers.
 */
value skt_int_of_file_descr(value fd_v) { /* ML */
  return fd_v ;
}

