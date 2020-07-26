/**************************************************************/
/* SKT.H */
/* Authors: Mark Hayden, Robbert van Renesse, 8/97 */
/**************************************************************/

#include <errno.h>
#ifdef _WIN32
#include <winsock2.h>
#include <io.h>
#include <stdio.h>
//#include <ws2tcpip.h>
#else
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <sys/uio.h>
#include <assert.h>
#include <memory.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/un.h>
#define h_errno errno
#endif

#include <assert.h>
#include <string.h>
#include "caml/config.h"
#include "caml/mlvalues.h"
#include "caml/misc.h"
#include "caml/alloc.h"
#include "caml/memory.h"
#include "caml/fail.h"
#include "caml/callback.h"

/**************************************************************/
/* Include the memory functions.
 */
#include "e_iovec.h"
#include "mm.h"

/* Include the socket descriptor handles.
 */
#include "sockfd.h"

/**************************************************************/
//#define SKTTRACE(x) printf x; fflush(stdout)
#define SKTTRACE(x) {}
//#define SKTTRACE2(x) printf x; fflush(stdout)
#define SKTTRACE2(x) {}
/**************************************************************/

/* A set of errors to ignore on receiving a UDP or a TCP packet.
 */
void skt_udp_recv_error(void);
int skt_tcp_recv_error(char *debug);

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

extern void serror(const char * cmdname);

/* Begin: from minor_gc.h */
extern char *young_start, *young_ptr, *young_end, *young_limit;
#define Is_young(val) \
  ((addr)(val) > (addr)young_start && (addr)(val) < (addr)young_end)
extern void minor_collection(void);
/* End: from minor_gc.h */


#ifdef HAS_SOCKETS
#include <sys/types.h>

#ifndef _WIN32
#include <sys/socket.h>
#include <sys/un.h>
#include <netinet/in.h>
#endif

#define GET_INET_ADDR(v) (*((uint32 *) (v)))

void skt_recv_error(void) ;

/* Defined inside CAML win32unix library
 */
/* BEGIN: Copied from ocaml/otherlibs/unix/socketaddr.[h].
 */
union sock_addr_union {
  struct sockaddr s_gen;
#ifndef _WIN32
  struct sockaddr_un s_unix;
#endif
  struct sockaddr_in s_inet;
};

extern union sock_addr_union sock_addr;

#ifdef HAS_SOCKLEN_T
typedef socklen_t socklen_param_type;
#else
typedef int socklen_param_type;
#endif

extern void get_sockaddr(value mladr,
			 union sock_addr_union * adr /*out*/,
			 socklen_param_type * adr_len /*out*/);

#endif /* HAS_SOCKETS */
