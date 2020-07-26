/**************************************************************/
/* SENDRECV.C */
/* Author: Ohad Rodeh  9/2001 */
/* This is a complete rewrite of previous code by Mark Hayden */
/**************************************************************/
#include "skt.h"
/**************************************************************/

/* BUG:
 * This MUST be the same as Buf.max_msg_len
 */
#define MAX_MSG_SIZE 8*1024

#define SIZE_INT32 sizeof(uint32)

/* Peeking to read the first two integers. 
 */
#define HEADER_PEEK   2 * SIZE_INT32

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

/**************************************************************/

skt_sendto_info_t *skt_Sendto_info_val(value info_v){
  return (skt_sendto_info_t*) Field(info_v,1);
}

void skt_Sendto_info_free(value info_v){
  free(skt_Sendto_info_val(info_v));
}

value skt_Val_create_sendto_info(
	value sock_v,
	value sina_v
) {
  skt_sendto_info_t *info ;
  ocaml_skt_t sock ;
  int naddr ;
  int i ;
  union sock_addr_union sock_addr ;
  int sock_addr_len ; 
  int size;
  CAMLparam2(sock_v, sina_v) ;
  CAMLlocal1(info_v) ;

  sock = Socket_val(sock_v) ;
  naddr = Wosize_val(sina_v) ;
  size = sizeof(skt_sendto_info_t) + naddr * sizeof(struct sockaddr);

  info = (skt_sendto_info_t*) malloc(size);
  memset((char*)info, 0, size);

  info->sock  = sock ;
  info->naddr = naddr ;
  info->addrlen = IP_ADDR_LEN ;	/* always IP_ADDR_LEN */

  for(i=0;i<naddr;i++) {
    get_sockaddr(Field(sina_v,i), &sock_addr, &sock_addr_len) ;
    assert(sock_addr_len == IP_ADDR_LEN) ;
    memcpy(&info->sa[i], &sock_addr, IP_ADDR_LEN) ;
  }
  info_v = alloc_final(2, skt_Sendto_info_free, 1, sizeof(skt_sendto_info_t)) ; 
  Field(info_v, 1) =  (value) info ; 
  CAMLreturn(info_v) ;
}

/**************************************************************/
/**************************************************************/
/* Common static buffers.
 */
#define N_IOVS 100
static ce_iovec_t iov[N_IOVS] ;
static ce_iovec_t recv_iov[3] ;
static char peek_buf[HEADER_PEEK]; 

/* This is used in the flat versions
 */
static char iobuf[MAX_MSG_SIZE];
static int iobuf_len;


static INLINE
int iovl_len(value iova_v){
  int i, nvecs, len=0;
  value t_v, iov_v;
  
  nvecs = Wosize_val(iova_v) ;	
  for(i=0;i<nvecs;i++) {
    t_v = Field(iova_v,i) ; // Extract Basic_iov.t
    iov_v = Field(t_v,1) ;  // Extract Basic_iov.iovec
    len += Int_val(Field(iov_v,0));
  }

  return len;
}

static INLINE
void prepare_send_header(value len_v, value iova_v){
  *((int*)((char*)peek_buf)) = htonl(Int_val(len_v));
  *((int*)((char*)peek_buf + SIZE_INT32)) = htonl(iovl_len(iova_v));
}

/* Add a header describing the length of the ML/Iovec parts.
 */
static INLINE
int gather(value iova_v){
  value t_v, iov_v;
  int i, nvecs, iovlen ;
  int len;
  char *buf;

  nvecs = Wosize_val(iova_v) ;	
  assert(nvecs +1 <= N_IOVS) ;
  iovlen  = nvecs +1;

  /* Write the ML/Iovec length.
   */
  prepare_send_header(Val_int(0), iova_v);
  Iov_len(iov[0]) = HEADER_PEEK;
  Iov_buf(iov[0]) = peek_buf;
  
  for(i=0;i<nvecs;i++) {
    t_v = Field(iova_v,i) ; // Extract Basic_iov.t
    iov_v = Field(t_v,1) ; // Extract Basic_iov.iovec
    len   = Int_val(Field(iov_v,0)) ;
    buf   = mm_Cbuf_val(Field(iov_v,1));

    Iov_len(iov[i+1])  = len ;
    Iov_buf(iov[i+1]) = buf ;
  }

  return iovlen;
}


static INLINE
int prefixed_gather(value prefix_v, value ofs_v, value len_v, value iova_v){
  value t_v, iov_v;
  int i, nvecs, len, iovlen;
  char *buf;

  nvecs = Wosize_val(iova_v) ; /* inspired by array.c */
  assert(nvecs + 2 <= N_IOVS) ;
  iovlen = nvecs + 2 ;

  /* Write the ML/Iovec length.
   */
  prepare_send_header(len_v, iova_v);
  Iov_len(iov[0]) = HEADER_PEEK;
  Iov_buf(iov[0]) = peek_buf;
  
  /* Fill in for the prefix. 
   */
  Iov_len(iov[1])  = Int_val(len_v);
  Iov_buf(iov[1]) = (char*) &Byte(prefix_v,Int_val(ofs_v)) ;

  for(i=0;i<nvecs;i++) {
    t_v = Field(iova_v,i) ; // Extract Basic_iov.t
    iov_v = Field(t_v,1) ; // Extract Basic_iov.iovec
    len   = Int_val(Field(iov_v,0)) ;
    buf   = mm_Cbuf_val(Field(iov_v,1));

    Iov_buf(iov[i+2]) = buf ;
    Iov_len(iov[i+2])  = len ;
  }

  return iovlen;
}

static INLINE
int gather_p(value iova_v){
  value t_v, iov_v;
  int i, nvecs, iovlen ;
  int len;
  char *buf;

  nvecs = Wosize_val(iova_v) ;	
  assert(nvecs <= N_IOVS) ;
  iovlen  = nvecs ;

  for(i=0;i<nvecs;i++) {
    t_v = Field(iova_v,i) ;   // Extract Basic_iov.t
    iov_v = Field(t_v,1) ;      // Extract Basic_iov.iovec
    len   = Int_val(Field(iov_v,0)) ;
    buf   = mm_Cbuf_val(Field(iov_v,1));

    Iov_len(iov[i]) = len ;
    Iov_buf(iov[i]) = buf ;
  }
  return iovlen;
}

static INLINE
int prefixed_gather_p(value prefix_v, value ofs_v, value len_v, value iova_v){
  value t_v, iov_v;
  int i, nvecs, len, iovlen;
  char *buf;

  nvecs = Wosize_val(iova_v) ; /* inspired by array.c */
  assert(nvecs + 1 <= N_IOVS) ;
  iovlen = nvecs + 1 ;

  /* Fill in for the prefix. 
   */
  Iov_len(iov[0])  = Int_val(len_v);
  Iov_buf(iov[0]) = (char*) &Byte(prefix_v,Int_val(ofs_v)) ;

  for(i=0;i<nvecs;i++) {
    t_v = Field(iova_v,i) ;   // Extract Basic_iov.t
    iov_v = Field(t_v,1) ;      // Extract Basic_iov.iovec
    len   = Int_val(Field(iov_v,0)) ;
    buf   = mm_Cbuf_val(Field(iov_v,1));

    Iov_len(iov[i+1])  = len ;
    Iov_buf(iov[i+1]) = buf ;
  }
  return iovlen;
}



static INLINE
int prefixed2_gather_p(value prefix1_v, value prefix2_v, value ofs2_v,
		       value len2_v, value iova_v){
  value t_v, iov_v;
  int i, nvecs, len, iovlen;
  char *buf;

  nvecs = Wosize_val(iova_v) ; /* inspired by array.c */
  assert(nvecs + 2 <= N_IOVS) ;
  iovlen = nvecs + 2 ;

  /* Fill in for the prefix.
   */
  Iov_len(iov[0]) = string_length(prefix1_v) ;
  Iov_buf(iov[0]) = String_val(prefix1_v) ;
  Iov_len(iov[1]) = Int_val(len2_v) ;
  Iov_buf(iov[1]) = (char*) &Byte(prefix2_v, Int_val(ofs2_v)) ;

  for(i=0;i<nvecs;i++) {
    t_v = Field(iova_v,i) ;     // Extract Basic_iov.t
    iov_v = Field(t_v,1) ;      // Extract Basic_iov.iovec
    len   = Int_val(Field(iov_v,0)) ;
    buf   = mm_Cbuf_val(Field(iov_v,1));

    Iov_len(iov[i+2])  = len ;
    Iov_buf(iov[i+2]) = buf ;
  }
  return iovlen;
}

/**************************************************************/
/* The flat versions come here.
 */
static INLINE
void gather_p_flat(value iova_v){
  value t_v, iov_v;
  int i, nvecs;
  int len, ofs;
  char *buf;

  nvecs = Wosize_val(iova_v) ;	
  assert(nvecs <= N_IOVS) ;
  
  ofs =0;
  for(i=0;i<nvecs;i++) {
    t_v = Field(iova_v,i) ;   // Extract Basic_iov.t
    iov_v = Field(t_v,1) ;      // Extract Basic_iov.iovec
    len   = Int_val(Field(iov_v,0)) ;
    buf   = mm_Cbuf_val(Field(iov_v,1));

    Iov_len(iov[i]) = len ;
    Iov_buf(iov[i]) = buf ;
    memcpy((char*)iobuf + ofs, buf, len);
    ofs +=len;
  }
  /* Set the length of the "returned" buffer.
   */
  iobuf_len = ofs;
}

static INLINE
void prefixed_gather_p_flat(value prefix_v, value ofs_v, value len_v, value iova_v){
  value t_v, iov_v;
  int i, nvecs, len, iovlen, ofs, len1;
  char *buf;

  nvecs = Wosize_val(iova_v) ; /* inspired by array.c */
  assert(nvecs + 1 <= N_IOVS) ;
  iovlen = nvecs + 1 ;

  /* Fill in for the prefix. 
   */
  len1 = Int_val(len_v);
  memcpy(iobuf, (char*) &Byte(prefix_v,Int_val(ofs_v)), len1);

  ofs = len1;
  for(i=0;i<nvecs;i++) {
    t_v = Field(iova_v,i) ;   // Extract Basic_iov.t
    iov_v = Field(t_v,1) ;      // Extract Basic_iov.iovec
    len   = Int_val(Field(iov_v,0)) ;
    buf   = mm_Cbuf_val(Field(iov_v,1));
    memcpy((char*)iobuf + ofs, buf, len);
    ofs +=len;
  }
  /* Set the length of the "returned" buffer.
   */
  iobuf_len = ofs;
}


static INLINE
void prefixed2_gather_p_flat(value prefix1_v, value prefix2_v, value ofs2_v, value len2_v, value iova_v) {
  value t_v, iov_v;
  int i, nvecs, len, len1, len2, ofs=0;
  char *buf;

  nvecs = Wosize_val(iova_v) ; 
  assert(nvecs + 2 <= N_IOVS) ;

  len1 = string_length(prefix1_v);
  memcpy(iobuf, String_val(prefix1_v), len1);
  len2 = Int_val(len2_v);
  memcpy((char*)iobuf + len1,(char*) &Byte(prefix2_v, Int_val(ofs2_v)), len2);

  ofs = len1+len2;
  for(i=0;i<nvecs;i++) {
    t_v = Field(iova_v,i) ;     // Extract Basic_iov.t
    iov_v = Field(t_v,1) ;      // Extract Basic_iov.raw
    len   = Int_val(Field(iov_v,0)) ;
    buf   = mm_Cbuf_val(Field(iov_v,1));
    memcpy((char*)iobuf + ofs, buf, len);
    ofs +=len;
  }
  /* Set the length of the "returned" buffer.
   */
  iobuf_len = ofs;
}

/**************************************************************/
/**************************************************************/


#ifndef _WIN32

/**************************************************************/
/* Receive a packet, allocated a user buffer and read the data into
 * it. ML has a preallocated buffer. Return Some(iov) on success,
 * None on failure. 
 *
 * No allocation on the ML heap is performed here. 
 * No exceptions are raised. 
 *
 * The ML string is preallocated, it looks like the following:
 *
 * The string is formatted as follows:
 * [len_buf] [len_iov] [actual ml data]
 */

static struct msghdr recv_msghdr = {
  NULL,/*(caddr_t) &sin,*/
  0,/*sizeof(sin),*/
  recv_iov,
  3,
  NULL,
  0
} ;

/* Try to read a packet from the network.
 * sock_v : a socket
 * cbuf_v : a memory pointer in which to write user date.
 */
value skt_udp_recv_packet(
			  value sock_v,
			  value cbuf_v
			  ){
  int len =0, ml_len, usr_len;
  ocaml_skt_t sock;
  char *usr_buf  = NULL, *ml_buf = NULL;
  CAMLparam2(sock_v, cbuf_v);
  CAMLlocal3(buf_v, iov_v, ret_v);

  SKTTRACE2(("Udp_recv_packet(\n"));
  sock = Socket_val(sock_v);
  
  /* Peek to read the headers. 
   */
  len = recvfrom(sock, peek_buf, HEADER_PEEK, MSG_PEEK,
		 NULL, 0);

  SKTTRACE2(("SENDRECV:recvfrom (peek), len=%d\n", len));
  
  /* Header is too short, read the rest of the packet and dump
   * it. 
   */
  if (len < HEADER_PEEK) {
    printf ("Packet too short.\n"); 
    len = recvfrom(sock,  peek_buf, HEADER_PEEK, 0,
		 NULL, 0);
    goto dump_packet;
  }

  ml_len = ntohl (*(uint32*) &(peek_buf[0]));
  usr_len = ntohl (*(uint32*) &(peek_buf[SIZE_INT32]));

  SKTTRACE(("SENDRECV:udp_recv: ml_len=%d usr_len=%d\n", ml_len, usr_len));

  /* The headers read will be too long. This is a bogus
   * packet, dump it. 
   */
  if ((ml_len + usr_len) >= MAX_MSG_SIZE) {
    printf ("Hdr length too long.\n"); 
    len = recvfrom(sock,  peek_buf, HEADER_PEEK, 0,
		 NULL, 0);
    goto dump_packet;
  }

  if (ml_len ==0 && usr_len ==0) {
    printf ("No msg body.\n"); 
    len = recvfrom(sock,  peek_buf, HEADER_PEEK, 0,
		 NULL, 0);
    goto dump_packet;
  }

  //  {
  //    int i;
  //    printf("recv_scribble --- ");
  //    for(i=0; i<HEADER_PEEK; i++)
  //      printf("%d:", ctx->recv_hd[i]);
  //    printf("\n");
  //
  //    printf("ml_len=%d, msg_len=%d\n", ml_len, usr_len);
  //  }


  /* Preparing the receiving IO-vector.
   * PERF: The 0'th buffer could be precomputed. 
   */

  Iov_len(recv_iov[0]) =  HEADER_PEEK ;
  Iov_buf(recv_iov[0]) = peek_buf ;
  
  /* Allocate an ML buffer.
   */
  recv_msghdr.msg_iovlen  = 3;
  if (ml_len > 0) {
    buf_v = alloc_string(ml_len);
    ml_buf = String_val(buf_v);
  }

  /* The user-buffer has already been allocated, no
   * need to allocate it. 
   */
  usr_buf = mm_Cbuf_val(cbuf_v);

  
  Iov_len(recv_iov[1]) =  ml_len ;
  Iov_buf(recv_iov[1]) = ml_buf ;
  Iov_len(recv_iov[2]) =  usr_len ;
  Iov_buf(recv_iov[2]) = usr_buf ;

  SKTTRACE2(("SENDRECV: ml buffer=%d\n", string_length(buf_v)));
  
  /*  
  printf("iovlen=%d\n", ctx->recv_msghdr.msg_iovlen);
  printf("total_len=%d\n", 
	 ctx->recv_msghdr.msg_iov[0].iov_len + 
	 ctx->recv_msghdr.msg_iov[1].iov_len + 
	 ctx->recv_msghdr.msg_iov[2].iov_len);
  */

  len = recvmsg(sock, &recv_msghdr, 0) ;   

  if (len != HEADER_PEEK + ml_len + usr_len) {
    printf("len2=%d, bad packet length, dumping the packet\n", len);
    goto dump_packet;
  }

  if (usr_len > 0)
    iov_v =  mm_Raw_of_len_buf(usr_len, usr_buf);
  else
    iov_v = mm_empty();
  
  ret_v = alloc_small(2, 0);
  Field(ret_v, 0) = buf_v;
  Field(ret_v, 1) = iov_v;
    
 ret:
  SKTTRACE2((")\n"));
  CAMLreturn(ret_v);

  /* PREF: Could precompute some of this stuff.
   */
 dump_packet:
  ret_v = alloc_small(2, 0);
  Field(ret_v, 0) = alloc_string(0);
  Field(ret_v, 1) = mm_empty ();
  if (len == -1) skt_udp_recv_error () ;
  // printf("dump_packet)\n"); fflush (stdout);
  goto ret;
}

/* Not needed on unix.
 */
value skt_recvfrom(sock, buff, ofs, len) /* ML */
     value sock, buff, ofs, len;
{
  invalid_argument("calling: skt_recvfrom on a Unix platform");
}

/* Not needed on unix.
 */
value skt_recvfrom2(sock, buff, ofs, len) /* ML */
     value sock, buff, ofs, len;
{
  invalid_argument("calling: skt_recvfrom2 on a Unix platform");
}

/**************************************************************/
/**************************************************************/

value skt_sendto(
	value info_v,
	value buf_v,
	value ofs_v,
	value len_v
) {
  int len, ofs, i, ret =0;
  skt_sendto_info_t *info ;
  int naddr ;
  char *buf ;

  info = skt_Sendto_info_val(info_v);
  ofs = Int_val(ofs_v) ;
  len = Int_val(len_v) ;
  buf = ((char*)&Byte(buf_v,ofs)) ;

  naddr = info->naddr ;

  SKTTRACE2(("skt_sendto\n"));
  for (i=0;i<naddr;i++) {
    /* Send the message.  Assume we don't block or get interrupted.  
     */
    ret = sendto(info->sock, buf, len, 0, &info->sa[i], info->addrlen) ;
  }
  return Val_unit;
}


/**************************************************************/

static struct msghdr send_msghdr = {
  NULL,/*(caddr_t) &sin,*/
  0,/*sizeof(sin),*/
  iov,
  0,
  NULL,
  0
} ;

/**************************************************************/

value skt_sendtov(
	value info_v,
	value iova_v
) {
  int naddr, i, ret=0;
  skt_sendto_info_t *info ;
  ocaml_skt_t sock;

  info = skt_Sendto_info_val(info_v);
  send_msghdr.msg_iovlen = gather(iova_v);

  send_msghdr.msg_namelen = info->addrlen ;
  sock = info->sock ;
  naddr = info->naddr ;

  SKTTRACE2(("skt_sendtov\n"));
  for (i=0;i<naddr;i++) {
    /* Send the message.  Assume we don't block or get interrupted.  
     */
    send_msghdr.msg_name = (char*) &info->sa[i] ;
    ret = sendmsg(sock, &send_msghdr, 0) ;
  }

  return Val_unit;
}

value skt_sendtosv(
	value info_v,
	value prefix_v,
	value ofs_v,
	value len_v,
	value iova_v
) {
  int naddr=0, i, ret=0;
  ocaml_skt_t sock=0 ;
  skt_sendto_info_t *info ;

  info = skt_Sendto_info_val(info_v);
  send_msghdr.msg_iovlen = prefixed_gather(prefix_v, ofs_v, len_v, iova_v); 

  send_msghdr.msg_namelen = info->addrlen ;
  sock = info->sock ;
  naddr = info->naddr ;

  for (i=0;i<naddr;i++) {
    /* Send the message.  Assume we don't block or get interrupted.  
     */
    send_msghdr.msg_name = (char*) &info->sa[i] ;
    ret = sendmsg(sock, &send_msghdr, 0) ;
  }

  /*  {
    int ilen = iovl_len(iova_v);
    ///struct sockaddr_in *sa = (struct sockaddr_in*)&info->sa[0];

    if (ilen > 0) {
      printf("SENDRECV:sendtosv: (len=%d) (iovec=%d)\n", 
	     Int_val(len_v), ilen);
      //printf("trg: IP=%s port=%d\n",
      //inet_ntoa(sa->sin_addr),
      //ntohs(sa->sin_port));
    }
    }*/

  return Val_unit;
}

/**************************************************************/
/* TCP stuff goes here.
 * 
 * Exceptions are thrown, and the length acually sent matters.
 * This is very similar to the above functions for UDP. 
 */

/* Read from a TCP socket into a string.
 */
value skt_recv(sock, buff, ofs, len) /* ML */
     value sock, buff, ofs, len;
{
  int ret;

  SKTTRACE(("skt_recv(\n"));
  ret = recv(Socket_val(sock), &Byte(buff, Long_val(ofs)), Int_val(len),0) ;
  if (ret == -1) serror("skt_recv");
  SKTTRACE2(("len=%d)\n",ret));
  return Val_int(ret);
}

/* Read from a TCP socket into an iovec.
 */
value skt_recv_iov(sock_v, iov_v, ofs_v, len_v) /* ML */
     value sock_v, iov_v, ofs_v, len_v;
{
  int ret;
  ocaml_skt_t sock = Socket_val(sock_v);
  char* cbuf = mm_Cbuf_val(Field(iov_v,1));
  int ofs = Int_val(ofs_v);
  int len = Int_val(len_v);

  SKTTRACE(("skt_recv_iov\n"));
  ret = recv(sock, (char*)cbuf + ofs, len, 0) ;
  if (ret == -1) serror("recv_iov");
  return Val_int(ret);
}


value skt_send_p(
	value sock_v,
	value buf_v,
	value ofs_v,
	value len_v
) {
  ocaml_skt_t sock;
  int len ;
  int ofs ;
  int ret ;
  char *buf ;

  sock = Socket_val(sock_v);
  ofs = Int_val(ofs_v) ;
  len = Int_val(len_v) ;
  buf = ((char*)&Byte(buf_v,ofs)) ;

  ret = send(sock, buf, len, 0) ;
  if (ret == -1) serror("send_p");
  return Val_int(ret) ;
}

value skt_sendv_p(
	value sock_v,
	value iova_v
) {
  int ret=0;
  ocaml_skt_t sock;
  

  send_msghdr.msg_iovlen = gather_p(iova_v) ;
  send_msghdr.msg_namelen = 0; 
  sock = Socket_val(sock_v);
  send_msghdr.msg_name = NULL;

  ret = sendmsg(sock, &send_msghdr, 0) ;
  if (ret == -1) serror("sendv_p");
  return(Val_int(ret));
}

value skt_sendsv_p(
	value sock_v,
	value prefix_v,
	value ofs_v,
	value len_v,
	value iova_v
) {
  int ret=0;
  ocaml_skt_t sock=0 ;

  send_msghdr.msg_iovlen = prefixed_gather_p(prefix_v, ofs_v, len_v, iova_v) ;
  send_msghdr.msg_namelen = 0;
  sock = Socket_val(sock_v);
  send_msghdr.msg_name = NULL;

  ret = sendmsg(sock, &send_msghdr, 0) ;
  if (ret == -1) serror("sendsv_p");
  return (Val_int(ret));
}

value skt_sends2v_p_native(
	value sock_v,
	value prefix1_v,
	value prefix2_v,
	value ofs2_v,
	value len2_v,
	value iova_v
) {
  int ret=0;
  ocaml_skt_t sock=0 ;


  send_msghdr.msg_iovlen = prefixed2_gather_p(prefix1_v, prefix2_v, ofs2_v, len2_v, iova_v) ;
  sock = Socket_val(sock_v);
  send_msghdr.msg_namelen = 0; 
  send_msghdr.msg_name = NULL;

  ret = sendmsg(sock, &send_msghdr, 0) ;
  if (ret == -1) serror("sends2v_p");
  return (Val_int(ret));
}

value skt_sends2v_p_bytecode(value *argv, int argn){
  return skt_sends2v_p_native(argv[0], argv[1], argv[2], argv[3],
			     argv[4], argv[5]);
}

/**************************************************************/
value skt_tcp_recv_packet(
         value sock_v, 
	 value buf_v, 
	 value ofs_v,
	 value len_v,
	 value iov_v
	 ){
  int len;

  recv_msghdr.msg_namelen = 0; 
  recv_msghdr.msg_name = NULL;
  recv_msghdr.msg_iovlen  = 2;
  Iov_len(recv_iov[0]) =  Int_val(len_v);
  Iov_buf(recv_iov[0]) = (char*)&Byte(buf_v, Int_val(ofs_v)) ;
  Iov_len(recv_iov[1]) =  Int_val(Field(iov_v,0));
  Iov_buf(recv_iov[1]) = mm_Cbuf_val(Field(iov_v,1));

  SKTTRACE(("skt_tcp_recv_packet, len=%d, iov_len=%d (\n",  
	    Int_val(len_v), Int_val(Field(iov_v,0))));
  len = recvmsg(Socket_val(sock_v), &recv_msghdr, 0);   
  SKTTRACE(("recv_len=%d )\n", len));

  if (len == -1) serror("skt_tcp_recv_packet");
  return Val_int(len);
}

/**************************************************************/
/**************************************************************/
/**************************************************************/

#else /* WIN32 */

/* Read from a TCP socket into a string.
 */
value skt_recv(sock, buff, ofs, len) /* ML */
     value sock, buff, ofs, len;
{
  int ret;

  SKTTRACE(("skt_recv(\n"));
  ret = recv(Socket_val(sock), &Byte(buff, Long_val(ofs)), Int_val(len),0) ;
  if (ret == -1) serror("recv");
  SKTTRACE2(("len=%d)\n",ret));
  return Val_int(ret);
}

/* Read from a TCP socket into an iovec.
 */
value skt_recv_iov(sock_v, iov_v, ofs_v, len_v) /* ML */
     value sock_v, iov_v, ofs_v, len_v;
{
  int ret;
  ocaml_skt_t sock = Socket_val(sock_v);
  char* cbuf = mm_Cbuf_val(Field(iov_v,1));
  int ofs = Int_val(ofs_v);
  int len = Int_val(len_v);

  SKTTRACE(("skt_recv_iov\n"));
  ret = recv(sock, (char*)cbuf + ofs, len, 0) ;
  if (ret == -1) serror("recv");
  return Val_int(ret);
}


value skt_send_p(
	value sock_v,
	value buf_v,
	value ofs_v,
	value len_v
) {
  ocaml_skt_t sock;
  int len ;
  int ofs ;
  int ret ;
  char *buf ;

  sock = Socket_val(sock_v);
  ofs = Int_val(ofs_v) ;
  len = Int_val(len_v) ;
  buf = ((char*)&Byte(buf_v,ofs)) ;

  ret = send(sock, buf, len, 0) ;
  if (ret == -1) serror("send_p");
  return Val_int(ret) ;
}


value skt_sendto(
	value info_v,
	value buf_v,
	value ofs_v,
	value len_v
) {
  int len, ofs, i, ret =0;
  skt_sendto_info_t *info ;
  int naddr ;
  char *buf ;

  info = skt_Sendto_info_val(info_v);
  ofs = Int_val(ofs_v) ;
  len = Int_val(len_v) ;
  buf = ((char*)&Byte(buf_v,ofs)) ;

  naddr = info->naddr ;

  for (i=0;i<naddr;i++) {
    /* Send the message.  Assume we don't block or get interrupted.  
     */
    ret = sendto(info->sock, buf, len, 0, &info->sa[i], info->addrlen) ;
    SKTTRACE2(("skt_sendto, ret=%d  addr=%s\n", ret,
	       inet_ntoa(((struct sockaddr_in*)&(info->sa[i]))->sin_addr)
	      ));
  }
  return Val_unit;
}


value skt_sendtov(
	value info_v,
	value iova_v
) {
  int naddr, i, ret=0, len=0, iovlen;
  skt_sendto_info_t *info ;
  ocaml_skt_t sock;

  info = skt_Sendto_info_val(info_v);
  iovlen = gather(iova_v) ;

  sock = info->sock ;
  naddr = info->naddr ;

  SKTTRACE2(("skt_sendtov\n"));
  for (i=0;i<naddr;i++) {
    /* Send the message.  Assume we don't block or get interrupted.  
     */
    ret = WSASendTo(sock, iov, iovlen, &len, 0,
		    &info->sa[i], info->addrlen, 0, NULL);
  }

  return Val_unit;
}

value skt_sendtosv(
	value info_v,
	value prefix_v,
	value ofs_v,
	value len_v,
	value iova_v
) {
  int naddr=0, i, ret=0, len=0, iovlen;
  ocaml_skt_t sock=0 ;
  skt_sendto_info_t *info ;

  info = skt_Sendto_info_val(info_v);
  iovlen = prefixed_gather(prefix_v, ofs_v, len_v, iova_v) ;

  sock = info->sock ;
  naddr = info->naddr ;

  for (i=0;i<naddr;i++) {
    /* Send the message.  Assume we don't block or get interrupted.  
     */
    ret = WSASendTo(sock, iov, iovlen, &len, 0,
		    &info->sa[i], info->addrlen, 0, NULL);
  }

  return Val_unit;
}

value skt_tcp_recv_packet(
         value sock_v, 
	 value buf_v, 
	 value ofs_v,
	 value len_v,
	 value iov_v
	 ){
  int ret=0, len=0;
  DWORD flags=0;
  
  Iov_len(recv_iov[0]) =  Int_val(len_v);
  Iov_buf(recv_iov[0]) = (char*)&Byte(buf_v, Int_val(ofs_v)) ;
  Iov_len(recv_iov[1]) =  Int_val(Field(iov_v,0));
  Iov_buf(recv_iov[1]) = mm_Cbuf_val(Field(iov_v,1));

  SKTTRACE(("skt_tcp_recv_packet, len=%d, iov_len=%d (\n",  
	    Int_val(len_v), Int_val(Field(iov_v,0))));

  ret = WSARecv(Socket_val(sock_v), recv_iov, 2, &len, &flags , NULL, NULL);

  SKTTRACE(("recv_len=%d )\n", len));

  if (ret == -1) serror("skt_tcp_recv_packt");
  return Val_int(len);
}

/**************************************************************/
/* Receive a packet, allocated a user buffer and read the data into
 * it. 
 *
 * The string is formatted as follows:
 * [len_buf] [len_iov] [actual ml data]

 * sock_v : a socket
 * cbuf_v : a memory pointer in which to write user date.
 *
 * Since NT4 and WIN2000 do not support MSG_PEEK, we need to
 * to receive everthing into the pre-allocated user-buffer.
 */
value skt_udp_recv_packet(
			  value sock_v,
			  value cbuf_v
			  ){
  int len =0, ml_len, usr_len;
  ocaml_skt_t sock;
  char *usr_buf  = NULL, *ml_buf = NULL;
  int ret = 0 ;
  int header_peek = (int) HEADER_PEEK;
  int flags = 0;
  char *cbuf = mm_Cbuf_val(cbuf_v);
  
  CAMLparam2(sock_v, cbuf_v);
  CAMLlocal3(buf_v, iov_v, ret_v);

  SKTTRACE2(("Udp_recv_packet(\n"));
  sock = Socket_val(sock_v);
  
  /* On NT, PEEK does not work, we must read the whole packet.
   */
  len = recvfrom(sock, cbuf, MAX_MSG_SIZE, 0, NULL, 0);
  
  /* Header is too short, read the rest of the packet and dump
   * it. 
   */
  if (len == -1){
    goto dump_packet;
  }
  
  if (len < header_peek) {
    printf ("Packet too short.\n"); 
    goto dump_packet;
  }
  ml_len = ntohl (*(uint32*) &(cbuf[0]));
  usr_len = ntohl (*(uint32*) &(cbuf[SIZE_INT32]));

  SKTTRACE(("SENDRECV:udp_recv: ml_len=%d usr_len=%d\n", ml_len, usr_len));

  /* The headers read will be too long. This is a bogus
   * packet, dump it. 
   */
  if ((ml_len + usr_len) >= MAX_MSG_SIZE) {
    printf ("Hdr length too long.\n"); 
    goto dump_packet;
  }

  if (ml_len ==0 && usr_len ==0) {
    printf ("No msg body.\n"); 
    goto dump_packet;
  }

  /* Allocate an ML buffer.
   */
  if (ml_len > 0) {
    buf_v = alloc_string(ml_len);
    ml_buf = String_val(buf_v);
  }

  /* Place usr_buf at the start of user-data.
   */
  usr_buf = (char*)cbuf + HEADER_PEEK + ml_len;

  /* Copy the ML header.
   */
  memcpy(ml_buf, (char*)cbuf + HEADER_PEEK, ml_len);
	 
  if (usr_len > 0)
    iov_v =  mm_Raw_of_len_buf(usr_len, usr_buf);
  else
    iov_v = mm_empty();
  
  ret_v = alloc_small(2, 0);
  Field(ret_v, 0) = buf_v;
  Field(ret_v, 1) = iov_v;
    
 ret:
  SKTTRACE2((")\n"));
  CAMLreturn(ret_v);

  /* PREF: Could precompute some of this stuff.
   */
 dump_packet:
  ret_v = alloc_small(2, 0);
  Field(ret_v, 0) = alloc_string(0);
  Field(ret_v, 1) = mm_empty ();
  if (len == -1) skt_udp_recv_error () ;
  // printf("dump_packet)\n"); fflush (stdout);
  goto ret;
}

value skt_recvfrom(value sock_v, value buf_v, value ofs_v, value len_v)
{
  CAMLparam4(sock_v, buf_v, ofs_v, len_v);
  CAMLlocal2(pair_v, addr_v);
  int ret;
  union sock_addr_union addr;
  socklen_param_type addr_len;

  SKTTRACE(("skt_recvfrom(\n"));
  ret = recvfrom(Socket_val(sock_v), &Byte(buf_v, Long_val(ofs_v)), Int_val(len_v),
		 0, &addr.s_gen, &addr_len);
  if (ret == -1) serror("recvfrom");
  SKTTRACE2(("len=%d)\n",ret));

  addr_v = alloc_sockaddr(&addr, addr_len);
  pair_v = alloc_small(2, 0);
  Field(pair_v, 0) = Val_int(ret);
  Field(pair_v, 1) = addr_v;
  CAMLreturn (pair_v);
}

value skt_recvfrom2(value sock_v, value buf_v, value ofs_v, value len_v)
{
  int ret;

  SKTTRACE(("skt_recvfrom2(\n"));
  ret = recvfrom(Socket_val(sock_v), &Byte(buf_v, Long_val(ofs_v)), Int_val(len_v),
		 0, NULL, NULL);
  if (ret == -1) serror("recvfrom2");
  SKTTRACE2(("len=%d)\n",ret));

  return (Val_int(ret));
}


value skt_sendv_p(
	value sock_v,
	value iova_v
) {
  int ret=0, len=0, iovlen=0;
  ocaml_skt_t sock;

  iovlen = gather_p(iova_v) ;
  sock = Socket_val(sock_v);
  ret = WSASend(sock, iov, iovlen, &len, 0, NULL, NULL);

  if (ret == -1) serror("sendv_p");
  return(Val_int(len));
}

value skt_sendsv_p(
	value sock_v,
	value prefix_v,
	value ofs_v,
	value len_v,
	value iova_v
) {
  int ret=0, len=0, iovlen=0;
  ocaml_skt_t sock=0 ;

  iovlen = prefixed_gather_p(prefix_v, ofs_v, len_v, iova_v) ;
  sock = Socket_val(sock_v);
  ret = WSASend(sock, iov, iovlen, &len, 0, NULL, NULL);

  if (ret == -1) serror("sendsv_p");
  return (Val_int(len));
}

value skt_sends2v_p_native(
	value sock_v,
	value prefix1_v,
	value prefix2_v,
	value ofs2_v,
	value len2_v,
	value iova_v
) {
  int ret=0, len=0, iovlen=0;
  ocaml_skt_t sock=0 ;

  iovlen = prefixed2_gather_p(prefix1_v, prefix2_v, ofs2_v, len2_v, iova_v) ;
  sock = Socket_val(sock_v);
  ret = WSASend(sock, iov, iovlen, &len, 0, NULL, NULL);
  
  if (ret == -1) serror("sends2v_p");
  return (Val_int(len));
}

value skt_sends2v_p_bytecode(value *argv, int argn){
  return skt_sends2v_p_native(argv[0], argv[1], argv[2], argv[3],
			     argv[4], argv[5]);
}

#endif
/**************************************************************/





