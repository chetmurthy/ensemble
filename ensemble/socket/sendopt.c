/**************************************************************/
/* SENDOPT.C: optimized send/sendto/sendmsg stubs. */
/* Author: Mark Hayden, 10/97 */
/**************************************************************/
#define string_length string_length_hide
#include "skt.h"
#undef string_length
/**************************************************************/

#ifdef HAS_SOCKETS

/* Print out a warning (once).
 */
void linux_warning(const char *debug) {
  static int warned = 0 ;
  if (!warned) {
    warned = 1 ;
    fprintf(stderr,"ENSEMBLE:%s:warning:working around a Linux error\n",debug) ;
    fprintf(stderr,"  (see ensemble/BUGS for more information)\n") ;
  }
}

/* From ocaml/byterun/str.c.  We have our own copy here
 * so that it will be inlined.
 */
static INLINE
mlsize_t string_length(value s) {
  mlsize_t temp;
  temp = Bosize_val(s) - 1;
  assert(Byte (s, temp - Byte (s, temp)) == 0);
  return temp - Byte (s, temp);
}

/* BEGIN: Copied from ocaml/otherlibs/unix/socketaddr.[ch].
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

static void get_sockaddr(value mladdr,
                  union sock_addr_union * addr /*out*/,
                  socklen_param_type * addr_len /*out*/)
{
  switch(Tag_val(mladdr)) {
#ifndef _WIN32
  case 0:                       /* ADDR_UNIX */
    invalid_argument("sendopt:unix_address") ;
    break; 
#endif
  case 1:                       /* ADDR_INET */
    {
      char * p;
      int n;
      for (p = (char *) &addr->s_inet, n = sizeof(addr->s_inet);
           n > 0; p++, n--)
        *p = 0;
      addr->s_inet.sin_family = AF_INET;
      addr->s_inet.sin_addr.s_addr = GET_INET_ADDR(Field(mladdr, 0));
      addr->s_inet.sin_port = htons(Int_val(Field(mladdr, 1)));
      *addr_len = sizeof(struct sockaddr_in);
      break;
    }
  }
}
/* END: Copied from ocaml/otherlibs/unix/socketaddr.[ch].
 */

#ifdef BIG_ENDIAN		/* for SP2 */
#undef BIG_ENDIAN
#endif

#ifdef HAS_SENDMSG
#include <sys/uio.h>
#endif

#ifdef SKT_PROTO
#ifdef HAS_SENDMSG
extern int sendmsg(int s, const struct msghdr *msg, unsigned int flags) ;
#endif
extern int sendto(int s, const void *msg, int len, unsigned int flags, const struct sockaddr *to, int tolen) ;
extern char *memset(void *s, int c, size_t n) ;
extern memcpy(void *dest, const void *src, size_t n) ;
#endif

typedef struct {
  ocaml_skt sock ;
  int flags ;
  int naddr ;
  int addrlen ;
  struct sockaddr sa[0];
} skt_msg ;

#define IP_ADDR_LEN (sizeof(struct sockaddr_in))

/* Adapted from mlvalues.h */
#define Wosize_bosize(sz) ((sz) / sizeof (value))

value skt_send_info(
	value sock_v,
	value flags_v,
	value sina_v
) {
  skt_msg *msg ;
  value msg_v ;
  ocaml_skt sock ;
  int flags ;
  int size ;
  int naddr ;
  int i ;
  union sock_addr_union sock_addr ;
  socklen_param_type sock_addr_len ; 

  CAMLparam2(sock_v, sina_v) ;
  sock = Socket_val(sock_v) ;
  flags = Int_val(flags_v) ;
  naddr = Wosize_val(sina_v) ;
 
  size = Wosize_bosize(sizeof(*msg) + sizeof(struct sockaddr) * naddr + 8) ;

  /* Allocate and zero the message.
   */
  msg_v = alloc(size, Abstract_tag) ;

  msg = (skt_msg*) &Byte(msg_v, 0) ;
  memset((char*)msg, 0, size) ;

  msg->sock  = sock ;
  msg->flags = flags ;
  msg->naddr = naddr ;
  msg->addrlen = IP_ADDR_LEN ;	/* always IP_ADDR_LEN */

  for(i=0;i<naddr;i++) {
    get_sockaddr(Field(sina_v,i), &sock_addr, &sock_addr_len) ;
    assert(sock_addr_len == IP_ADDR_LEN) ;
    memcpy(&msg->sa[i], &sock_addr, IP_ADDR_LEN) ;
  }
  CAMLreturn(msg_v) ;
}

/**************************************************************/

value skt_sendto(
	value msg_v,
	value buf_v,
	value ofs_v,
	value len_v
) {
  int len, ofs, i, ret, flags ;
  ocaml_skt sock ;
  skt_msg *msg ;
  int naddr ;
  char *buf ;

  SKTTRACE ;
  msg = (skt_msg*) &Byte(msg_v, 0) ;
  ofs = Int_val(ofs_v) ;
  len = Int_val(len_v) ;
  buf = ((char*)&Byte(buf_v,ofs)) ;

  sock = msg->sock ;
  flags = msg->flags ;
  naddr = msg->naddr ;

  for (i=0;i<naddr;i++) {
    /* Send the message.  Assume we don't block or get interrupted.  
     */
    ret = sendto(sock, buf, len, flags, &msg->sa[i], msg->addrlen) ;
    
#ifdef ECONNREFUSED
    /* See ensemble/BUGS.
     */
    if (ret == -1 && h_errno == ECONNREFUSED) {
      linux_warning("sendto:sendto") ;
      ret = sendto(sock, buf, len, flags, &msg->sa[i], msg->addrlen) ;
    }
#endif
  }
  return Val_unit ;
}

value skt_sendp(
	value msg_v,
	value buf_v,
	value ofs_v,
	value len_v
) {
  int len ;
  int ofs ;
  int ret ;
  skt_msg *msg ;
  char *buf ;

  SKTTRACE ;
  msg = (skt_msg*) &Byte(msg_v, 0) ;
  ofs = Int_val(ofs_v) ;
  len = Int_val(len_v) ;
  buf = ((char*)&Byte(buf_v,ofs)) ;

  /* Send the message.  Assume we don't block or get interrupted.  
   */
  ret = send(msg->sock, buf, len, msg->flags) ;
  if (ret == -1) serror("send",Nothing) ;
  return Val_int(ret) ;
}

/**************************************************************/

#ifdef HAS_SENDMSG

#define N_IOVS 20
static struct iovec iov[N_IOVS] ;

static struct msghdr msghdr = {
  NULL,/*(caddr_t) &sin,*/
  0,/*sizeof(sin),*/
  iov,
  0,
  NULL,
  0
} ;

static INLINE
void gather(value iova_v) {
  value iov_v, buf_v ;
  int i, nvecs ;
  int len, ofs ;

  nvecs = Wosize_val(iova_v) ;	/* inspired by array.c */
  assert(nvecs <= N_IOVS) ;
  msghdr.msg_iovlen  = nvecs ;

  assert(iov == msghdr.msg_iov) ;
  for(i=0;i<nvecs;i++) {
    iov_v = Field(iova_v,i) ;
    ofs   = Int_val(Field(iov_v,IOV_OFS)) ;
    len   = Int_val(Field(iov_v,IOV_LEN)) ;
    buf_v = Field(Field(iov_v,IOV_BUF),REFCNT_OBJ) ;

    iov[i].iov_base = (caddr_t) &Byte(buf_v,ofs) ;
    iov[i].iov_len  = len ;
  }
}

static INLINE
void prefixed_gather(value prefix_v, value iova_v) {
  value iov_v, buf_v ;
  int i, nvecs ;
  int len, ofs ;
  int prefix_len ;

  nvecs = Wosize_val(iova_v) ; /* inspired by array.c */
  assert(nvecs + 1 <= N_IOVS) ;
  msghdr.msg_iovlen = nvecs + 1 ;

  /* Fill in for the prefix.  The prefix should be a multiple
   * of 4 bytes in length.
   */
  prefix_len = string_length(prefix_v) ;
  assert((prefix_len & 3) == 0) ;

  assert(iov == msghdr.msg_iov) ;
  iov[0].iov_base = String_val(prefix_v) ;
  iov[0].iov_len  = prefix_len ;

  for(i=0;i<nvecs;i++) {
    iov_v = Field(iova_v,i) ;
    ofs   = Int_val(Field(iov_v,IOV_OFS)) ;
    len   = Int_val(Field(iov_v,IOV_LEN)) ;
    buf_v = Field(Field(iov_v,IOV_BUF),REFCNT_OBJ) ;

    /* Could optimize this away.
     */
    iov[i+1].iov_base = (caddr_t) &Byte(buf_v,ofs) ;
    iov[i+1].iov_len  = len ;
  }
}

static INLINE
void suffixed_gather(value iova_v, value suffix_v) {
  value iov_v, buf_v ;
  int i, nvecs ;
  int len, ofs ;
  int suffix_len ;

  nvecs = Wosize_val(iova_v) ; /* inspired by array.c */
  assert(nvecs + 1 <= N_IOVS) ;
  msghdr.msg_iovlen = nvecs + 1 ;

  /* Fill in for the suffix.  The suffix should be a multiple
   * of 4 bytes in length.
   */
  suffix_len = string_length(suffix_v) ;
  assert((suffix_len & 3) == 0) ;

  assert(iov == msghdr.msg_iov) ;
  iov[nvecs].iov_base = String_val(suffix_v) ;
  iov[nvecs].iov_len  = suffix_len ;

  for(i=0;i<nvecs;i++) {
    iov_v = Field(iova_v,i) ;
    ofs   = Int_val(Field(iov_v,IOV_OFS)) ;
    len   = Int_val(Field(iov_v,IOV_LEN)) ;
    buf_v = Field(Field(iov_v,IOV_BUF),REFCNT_OBJ) ;

    /* Could optimize this away.
     */
    iov[i].iov_base = (caddr_t) &Byte(buf_v,ofs) ;
    iov[i].iov_len  = len ;
  }
}


value skt_sendtov(
	value msg_v,
	value iova_v
) {
  int naddr, i, ret, flags ;
  ocaml_skt sock ;
  skt_msg *msg ;
  SKTTRACE ;
  gather(iova_v) ;

  msg = (skt_msg*) &Byte(msg_v, 0) ;

  msghdr.msg_namelen = msg->addrlen ;

  sock = msg->sock ;
  naddr = msg->naddr ;
  flags = msg->flags ;

  for (i=0;i<naddr;i++) {
    /* Send the message.  Assume we don't block or get interrupted.  
     */
    msghdr.msg_name = (char*) &msg->sa[i] ;
    ret = sendmsg(sock, &msghdr, flags) ;
    
#ifdef ECONNREFUSED
    /* See ensemble/BUGS.
     */
    if (ret == -1 && h_errno == ECONNREFUSED) {
      linux_warning("sendtov:sendmsg") ;
      sendmsg(msg->sock, &msghdr, flags) ;
    }
#endif
  }

  return Val_unit ;
}

value skt_sendtosv(
	value msg_v,
	value prefix_v,
	value iova_v
) {
  int naddr, i, ret, flags ;
  ocaml_skt sock ;
  skt_msg *msg ;
  SKTTRACE ;
  prefixed_gather(prefix_v, iova_v) ;

  msg = (skt_msg*) &Byte(msg_v, 0) ;

  msghdr.msg_namelen = msg->addrlen ;

  sock = msg->sock ;
  flags = msg->flags ;
  naddr = msg->naddr ;

  for (i=0;i<naddr;i++) {
    /* Send the message.  Assume we don't block or get interrupted.  
     */
    msghdr.msg_name = (char*) &msg->sa[i] ;
    ret = sendmsg(sock, &msghdr, flags) ;
    
#ifdef ECONNREFUSED
    /* See ensemble/BUGS.
     */
    if (ret == -1 && h_errno == ECONNREFUSED) {
      linux_warning("sendtov:sendmsg") ;
      sendmsg(sock, &msghdr, flags) ;
    }
#endif
  }

  return Val_unit ;
}

value skt_sendtovs(
	value msg_v,
	value iova_v,
	value suffix_v
) {
  int naddr, i, ret, flags ;
  ocaml_skt sock ;
  skt_msg *msg ;
  SKTTRACE ;
  suffixed_gather(iova_v, suffix_v) ;

  msg = (skt_msg*) &Byte(msg_v, 0) ;

  msghdr.msg_namelen = msg->addrlen ;

  sock = msg->sock ;
  flags = msg->flags ;
  naddr = msg->naddr ;

  for (i=0;i<naddr;i++) {
    /* Send the message.  Assume we don't block or get interrupted.  
     */
    msghdr.msg_name = (char*) &msg->sa[i] ;
    ret = sendmsg(sock, &msghdr, flags) ;
    
#ifdef ECONNREFUSED
    /* See ensemble/BUGS.
     */
    if (ret == -1 && h_errno == ECONNREFUSED) {
      linux_warning("sendtov:sendmsg") ;
      sendmsg(sock, &msghdr, flags) ;
    }
#endif
  }

  return Val_unit ;
}

value skt_sendv(
	value msg_v,
	value iova_v
) {
  int ret ;
  skt_msg *msg ;
  SKTTRACE ;

  gather(iova_v) ;

  msg = (skt_msg*) &Byte(msg_v, 0) ;

  /* Send the message.  Assume we don't block or get interrupted.  
   */
  msghdr.msg_name = NULL ;
  msghdr.msg_namelen = 0 ;
  ret = sendmsg(msg->sock, &msghdr, msg->flags) ;
  if (ret == -1) serror("sendmsg",Nothing) ;
  return Val_int(ret) ;
}

#else /* HAS_SENDMSG */

#define FLATTEN_LEN (10 * 1024)
static char flatten_buf[FLATTEN_LEN] ;

static
char *flatten(value prefix_v, value iova_v, value suffix_v, int *len_out) {
  int nvecs, i, len ;
  int iov_ofs, iov_len ;
  char *buf ;
  value iov_v, iov_buf_v ;

  nvecs = Wosize_val(iova_v) ;	/* inspired by array.c */

  /* Calculate length.
   */
  len = prefix_v ? string_length(prefix_v) : 0 ;
  for (i=0;i<nvecs;i++) {
    iov_v = Field(iova_v,i) ;
    len  += Int_val(Field(iov_v,IOV_LEN)) ;
  }
  len += suffix_v ? string_length(suffix_v) : 0 ;

  /* Either use a preallocated buffer or allocate temporary buffer.  
   */
  if (len < FLATTEN_LEN) {
    buf = flatten_buf ;
  } else {
    buf = stat_alloc(len) ;
  }
  
  len = 0 ;

  /* Copy the prefix, if any.
   */
  if (prefix_v) {
    iov_buf_v = prefix_v ;
    iov_ofs = 0 ;
    iov_len = string_length(prefix_v) ;
    memcpy(&buf[len], &Byte(iov_buf_v,iov_ofs), iov_len) ;
    len += iov_len ;
  }

  /* Copy vectors.
   */
  for(i=0;i<nvecs;i++) {
    iov_v     = Field(iova_v,i) ;
    iov_ofs   = Int_val(Field(iov_v,IOV_OFS)) ;
    iov_len   = Int_val(Field(iov_v,IOV_LEN)) ;
    iov_buf_v = Field(Field(iov_v,IOV_BUF),REFCNT_OBJ) ;
    memcpy(&buf[len], &Byte(iov_buf_v,iov_ofs), iov_len) ;
    len += iov_len ;
  }

  /* Copy the suffix, if any.
   */
  if (suffix_v) {
    iov_buf_v = suffix_v ;
    iov_ofs = 0 ;
    iov_len = string_length(suffix_v) ;
    memcpy(&buf[len], &Byte(iov_buf_v,iov_ofs), iov_len) ;
    len += iov_len ;
  }

  *len_out = len ;
  return buf ;
}

/* Version without sendmsg
 */
value skt_sendtov(
	value msg_v,
	value iova_v
) {
  int i, ret, len, flags ;
  ocaml_skt sock ;
  skt_msg *msg ;
  char *buf ;
  int naddr ;
  SKTTRACE ;

  buf = flatten((value)NULL, iova_v, (value)NULL, &len) ;

  msg = (skt_msg*) &Byte(msg_v, 0) ;

  sock = msg->sock ;
  naddr = msg->naddr ;
  flags = msg->flags ;

  for (i=0;i<naddr;i++) {
    /* Send the message.  Assume we don't block or get interrupted.  
     */
    ret = sendto(sock, buf, len, flags, &msg->sa[i], msg->addrlen) ;
    
#ifdef ECONNREFUSED
    /* See ensemble/BUGS.
     */
    if (ret == -1 && h_errno == ECONNREFUSED) {
      linux_warning("sendtov:sendto") ;
      sendto(sock, buf, len, flags, &msg->sa[i], msg->addrlen) ;      
    }
#endif
  }
  
  if (buf != flatten_buf) {
    stat_free(buf) ;
  }
  
  return Val_unit ;
}    

/* Version without sendmsg
 */
value skt_sendtosv(
	value msg_v,
	value prefix_v,
	value iova_v
) {
  int i, ret, len, flags ;
  ocaml_skt sock ;
  skt_msg *msg ;
  char *buf ;
  int naddr ;
  SKTTRACE ;

  buf = flatten(prefix_v, iova_v, (value)NULL, &len) ;

  msg = (skt_msg*) &Byte(msg_v, 0) ;

  naddr = msg->naddr ;
  flags = msg->flags ;
  sock = msg->sock ;

  for (i=0;i<naddr;i++) {
    /* Send the message.  Assume we don't block or get interrupted.  
     */
    ret = sendto(sock, buf, len, flags, &msg->sa[i], msg->addrlen) ;
    
#ifdef ECONNREFUSED
    /* See ensemble/BUGS.
     */
    if (ret == -1 && errno_h == ECONNREFUSED) {
      linux_warning("sendtov:sendto") ;
      sendto(sock, buf, len, flags, &msg->sa[i], msg->addrlen) ;      
    }
#endif
  }
  
  if (buf != flatten_buf) {
    stat_free(buf) ;
  }
  
  return Val_unit ;
}    

/* Version without sendmsg
 */
value skt_sendtovs(
	value msg_v,
	value iova_v,
	value suffix_v
) {
  int i, ret, len, flags ;
  ocaml_skt sock ;
  skt_msg *msg ;
  char *buf ;
  int naddr ;
  SKTTRACE ;

  buf = flatten((value)NULL, iova_v, suffix_v, &len) ;

  msg = (skt_msg*) &Byte(msg_v, 0) ;

  naddr = msg->naddr ;
  flags = msg->flags ;
  sock = msg->sock ;

  for (i=0;i<naddr;i++) {
    /* Send the message.  Assume we don't block or get interrupted.  
     */
    ret = sendto(sock, buf, len, flags, &msg->sa[i], msg->addrlen) ;
    
#ifdef ECONNREFUSED
    /* See ensemble/BUGS.
     */
    if (ret == -1 && errno_h== ECONNREFUSED) {
      linux_warning("sendtov:sendto") ;
      sendto(sock, buf, len, flags, &msg->sa[i], msg->addrlen) ;      
    }
#endif
  }
  
  if (buf != flatten_buf) {
    stat_free(buf) ;
  }
  
  return Val_unit ;
}    

/* Version without sendmsg
 */
value skt_sendv(
	value msg_v,
	value iova_v
) {
  int ret, len ;
  skt_msg *msg ;
  char *buf ;
  SKTTRACE ;

  buf = flatten((value)NULL, iova_v, (value)NULL, &len) ;
  
  msg = (skt_msg*) &Byte(msg_v, 0) ;

  /* Send the message.  Assume we don't block or get interrupted.  
   */
  ret = send(msg->sock, buf, len, msg->flags) ;
  
  if (buf != flatten_buf) {
    stat_free(buf) ;
  }

  if (ret == -1) serror("sendmsg",Nothing) ;
  return Val_int(ret) ;
}    

#endif /* HAS_SENDMSG */

/**************************************************************/

#else

value skt_preprocess() { invalid_argument("preprocess not implemented") ; }
value skt_sendto()     { invalid_argument("sendto not implemented") ; }
value skt_sendtov()    { invalid_argument("sendtov not implemented") ; }
value skt_sendp()      { invalid_argument("sendp not implemented") ; }
value skt_sendv()      { invalid_argument("sendv not implemented") ; }

#endif
