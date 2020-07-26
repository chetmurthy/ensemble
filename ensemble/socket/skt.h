/**************************************************************/
/*
 *  Ensemble, (Version 1.00)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
/**************************************************************/
/* SKT.H */
/* Authors: Mark Hayden, Robbert van Renesse, 8/97 */
/**************************************************************/

#include <errno.h>
#ifdef _WIN32
#include <windows.h>
#include <winsock.h>
#include <io.h>
#else
#include <fcntl.h>
#define h_errno errno
#endif

#include <assert.h>
#include <string.h>
#include "caml/config.h"
#include "caml/mlvalues.h"
#include "caml/misc.h"
#include "caml/alloc.h"
#include "caml/memory.h"

/**************************************************************/
/*#define SKTTRACE printf("SOCKET:%s()\n",__FUNCTION__)*/
#define SKTTRACE do {} while(0)
/**************************************************************/

enum refcnt_fields {
  REFCNT_COUNT,
  REFCNT_OBJ,
} ;

enum iovec_fields {
  IOV_BUF,
  IOV_OFS,
  IOV_LEN,
} ;

/**************************************************************/

#ifdef HAS_UNISTD
#include <unistd.h>
#endif

#ifdef HAS_ARPA_INET
#include <arpa/inet.h>
#endif

#ifdef _WIN32
#  define INLINE __inline
#else
#  ifdef INLINE_PRAGMA
#    define INLINE
#  else
#    define INLINE inline
#  endif
#endif
#define Nothing ((value) 0)

#include <stdio.h>

/* From unixsupport.h */
extern void serror(const char * cmdname, value arg);

/* Begin: from minor_gc.h */
extern char *young_start, *young_ptr, *young_end, *young_limit;
#define Is_young(val) \
  ((addr)(val) > (addr)young_start && (addr)(val) < (addr)young_end)
extern void minor_collection(void);
/* End: from minor_gc.h */

/* From fail.h */
void invalid_argument(const char *) Noreturn;

/* From str.h */
mlsize_t string_length(value);


#ifdef HAS_SOCKETS
#include <sys/types.h>

#ifndef _WIN32
#include <sys/socket.h>
#include <sys/un.h>
#include <netinet/in.h>
#endif


void skt_get_sockaddr(value);
value skt_alloc_sockaddr(void);
value skt_alloc_inet_addr(unsigned int);

#define GET_INET_ADDR(v) (*((uint32 *) (v)))

/*#define MSG_UNKNOWN_FLAG	0x20000000*/
/*#define MSG_SAFE		0x10000000*/

/*extern int msg_flag_table[4] ;*/

#ifdef _WIN32

typedef SOCKET ocaml_skt ;

/* Get the file descriptor inside the wrapper.  We define Socket_val
 * in terms of Handle_val() to make it clear what is going on here.
 */
#define Handle_val(v) (*((HANDLE *)(v))) /* from unixsupport.h */
#define Socket_val(v) ((SOCKET) Handle_val(v))

#else

typedef int ocaml_skt ;

/* Get the file descriptor inside the wrapper.
 */
#define Socket_val(sock_v) (Int_val(Field((sock_v),0)))

#endif

ocaml_skt socket_val(value v) ;
value skt_socket_of_fd(value fd_v) ;

void skt_recv_error(void) ;
#define ENSEMBLE_ETH_PROTO (0x08ff)

#endif /* HAS_SOCKETS */
