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
/* COMMON.H */
/* Author: Ohad Rodeh  10/2002 */
/* Based on code by Mark Hayden */
/**************************************************************/
#ifndef __SKT_H__
#define __SKT_H__

#include "caml/config.h"
#include "caml/mlvalues.h"
#include "caml/misc.h"
#include "caml/alloc.h"
#include "caml/memory.h"
#include "caml/fail.h"
#include "caml/callback.h"

// This is for zero-copy marshaling.
#include "caml/intext.h"

/* The type of iovec's. On each system, they are defined in
 * some native form.
 */
/**************************************************************/
/* We currently assume that all unixes define iovec in 
 * sys/socket.h
 */
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

#define mm_Cbuf_val(cbuf_v) ((char*) Field(cbuf_v,0))
#define mm_Cbuf_of_iovec(iov_v) (mm_Cbuf_val(Field(Field(iov_v,0),0)))
#define mm_Ofs_of_iovec(iov_v) (Int_val(Field(iov_v,1)))
#define mm_Len_of_iovec(iov_v) (Int_val(Field(iov_v,2)))
#define mm_Cptr_of_iovec(iov_v) (mm_Cbuf_of_iovec(iov_v) + mm_Ofs_of_iovec(iov_v))

/* An empty iovec.
 */
value mm_empty(void);

/* Marshaling/unmarshaling from/to C buffers
 */
value mm_output_val(value obj_v, value cbuf_v, value ofs_v, value len_v, value flags_v);
value mm_input_val(value cbuf_v, value ofs_v, value len_v);
/**************************************************************/

// Include the socket descriptor handles.
#include "sockfd.h"

// Include things specific to the machine (nt/unix)
#include "platform.h"
/**************************************************************/
//* Debugging macros. 

//#define SKTTRACE(x) { printf x; fflush(stdout); }
#define SKTTRACE(x) {}
//#define SKTTRACE2(x) printf x; fflush(stdout)
#define SKTTRACE2(x) {}
/**************************************************************/
/* A set of errors to ignore on receiving a UDP or a TCP packet.
 */
void skt_udp_error(char *debug);
void skt_tcp_error(char *debug);

/**************************************************************/

extern void serror(char * cmdname);

#define GET_INET_ADDR(v) (*((uint32 *) (v)))

/* Defined inside CAML win32unix library
 *
 * BEGIN: Copied from ocaml/otherlibs/unix/{socketaddr.h,unixsupport.h}
 */
#define Nothing ((value) 0)

//extern union sock_addr_union sock_addr;

#ifdef HAS_SOCKLEN_T
typedef socklen_t socklen_param_type;
#else
typedef int socklen_param_type;
#endif

extern void get_sockaddr(value mladr,
			 union sock_addr_union * adr /*out*/,
			 socklen_param_type * adr_len /*out*/);

extern value alloc_sockaddr(union sock_addr_union * adr /*in*/,
			    socklen_param_type adr_len);

/**************************************************************/
typedef fd_set file_descr_set;

file_descr_set *fdarray_to_fdset(value fdinfo, file_descr_set *fdset );
void fdset_to_fdarray(value fdinfo, file_descr_set *fdset );
/**************************************************************/


/* A structure containing pre-processed information for
 * sending on a socket to several destinations. 
 */
typedef struct skt_sendto_info_t {
    int sock ;
    int naddr ;
    int addrlen ;
    struct sockaddr sa[0]; /* An array of addresses comes here. 
			    * Since we do not know its size, we 
			    * cannot pre-allocate it. 
			    */
} skt_sendto_info_t ;

#define IP_ADDR_LEN (sizeof(struct sockaddr_in))


INLINE static skt_sendto_info_t *skt_Sendto_info_val(value info_v)
{
    return (skt_sendto_info_t*) Field(info_v,1);
}

value skt_Val_create_sendto_info( value sock_v, value sina_v);


/**************************************************************/
/* BUG:
 * This MUST be the same as Buf.max_msg_len
 */
#define MAX_MSG_SIZE     (8*1024)

/**************************************************************/

#define SIZE_INT32       (sizeof(uint32))

/* Peeking to read the first two integers.  This is signed (versus
 * unsigned) because we are comparing against the received length to
 * see if enough bytes have been received from the packet.
 */
#define HEADER_PEEK   ((int32)(2 * SIZE_INT32))
/**************************************************************/

static INLINE int skt_iovl_len(value iova_v)
{
    int i, nvecs, len=0;
    value iov_v;
    
    nvecs = Wosize_val(iova_v) ;	
    for(i=0;i<nvecs;i++) {
	iov_v = Field(iova_v,i) ; // Extract Basic_iov.t
	len += mm_Len_of_iovec(iov_v);
    }
    
    return len;
}

static INLINE void skt_prepare_send_header(
    mm_iovec_t iova[],
    char peek_buf[HEADER_PEEK],
    int ml_len,
    int iov_len
    )
{
    *((int*)((char*)peek_buf)) = htonl(ml_len);
    *((int*)((char*)peek_buf + SIZE_INT32)) = htonl(iov_len);

    Iov_len(iova[0]) = (int)HEADER_PEEK;
    Iov_buf(iova[0]) = peek_buf;
}

/* Add a header describing the length of the ML/Iovec parts.
 */
static INLINE void skt_gather(mm_iovec_t iov_a[], int pos, value iova_v)
{
    value iov_v;
    int i;
    int nvecs = Wosize_val(iova_v) ;	
    
    for(i=0; i<nvecs; i++, pos++) {
	iov_v = Field(iova_v,i) ; // Extract Basic_iov.t
	Iov_len(iov_a[pos]) = mm_Len_of_iovec(iov_v);
	Iov_buf(iov_a[pos]) = mm_Cptr_of_iovec(iov_v);
    }
}


static INLINE void skt_add_string( mm_iovec_t iov_a[], int pos, value prefix_v)
{
    Iov_len(iov_a[pos]) = string_length(prefix_v);
    Iov_buf(iov_a[pos]) = (char*) &Byte(prefix_v,0);
}

static INLINE void skt_add_ml_hdr(mm_iovec_t iov_a[], int pos, 
                                  value prefix_v, value ofs_v, value len_v)
{
    Iov_len(iov_a[pos]) = Int_val(len_v);
    Iov_buf(iov_a[pos]) = (char*) &Byte(prefix_v,Int_val(ofs_v)) ;
}

/**************************************************************/
#endif

