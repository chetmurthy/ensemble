/**************************************************************/
/* SENDRECV.C */
/* Author: Ohad Rodeh  9/2001 */
/* This is a complete rewrite of previous code by Mark Hayden */
/**************************************************************/
#include "skt.h"
/**************************************************************/
#define N_IOVS (100)
static mm_iovec_t send_iova[N_IOVS];
static mm_iovec_t recv_iova[3];
static char peek_buf[HEADER_PEEK]; 
static int header_peek = (int) HEADER_PEEK; // casts unsigned into signed
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
    recv_iova,
    3,
    NULL,
    0
} ;


static struct msghdr send_msghdr = {
    NULL,/*(caddr_t) &sin,*/
    0,/*sizeof(sin),*/
    send_iova,
    0,
    NULL,
    0
} ;

/**************************************************************/
/* TCP section
 */

value skt_tcp_send(
    value sock_v,
    value buf_v,
    value ofs_v,
    value len_v
    )
{
    ocaml_skt_t sock;
    int len ;
    int ofs ;
    int ret ;
    char *buf ;
    
    SKTTRACE(("skt_tcp_send("));
    sock = Socket_val(sock_v);
    ofs = Int_val(ofs_v) ;
    len = Int_val(len_v) ;
    buf = ((char*)&Byte(buf_v,ofs)) ;
    
    ret = send(sock, buf, len, 0) ;
    if (-1 == ret) {
        skt_tcp_error("skt_send_p");
        return Val_int(0);
    }
    SKTTRACE((")\n"));
    return Val_int(ret) ;
}

value skt_tcp_sendv(
    value sock_v,
    value iova_v
    )
{
    int ret=0;
    ocaml_skt_t sock;
    int nvecs = Wosize_val(iova_v) ;
    
    SKTTRACE(("skt_sendv_p("));
    skt_gather(send_iova, 0, iova_v);
    sock = Socket_val(sock_v);
    send_msghdr.msg_iovlen = nvecs;
    send_msghdr.msg_namelen = 0; 
    send_msghdr.msg_name = NULL;
    ret = sendmsg(sock, &send_msghdr, MSG_DONTWAIT) ;
    if (-1 == ret) {
        skt_tcp_error("skt_tcp_sendv");
        return Val_int(0);
    }
    SKTTRACE((")\n"));
    return(Val_int(ret));
}

value skt_tcp_sendsv(
    value sock_v,
    value prefix_v,
    value ofs_v,
    value len_v,
    value iova_v
    )
{
    int ret=0;
    ocaml_skt_t sock=0 ;
    int nvecs = Wosize_val(iova_v) ;
    
    SKTTRACE(("skt_tcp_sendsv("));
    skt_add_ml_hdr(send_iova, 0, prefix_v, ofs_v, len_v);
    skt_gather(send_iova, 1, iova_v);
    send_msghdr.msg_iovlen = nvecs+1;
    send_msghdr.msg_namelen = 0; 
    send_msghdr.msg_name = NULL;
    sock = Socket_val(sock_v);
    ret = sendmsg(sock, &send_msghdr, MSG_DONTWAIT) ;
    if (-1 == ret) {
        skt_tcp_error("skt_tcp_sendsv");
        return Val_int(0);
    }
    SKTTRACE((")\n"));
    return (Val_int(ret));
}

value skt_tcp_sends2v_native(
    value sock_v,
    value prefix1_v,
    value prefix2_v,
    value ofs2_v,
    value len2_v,
    value iova_v
    )
{
    int ret=0;
    ocaml_skt_t sock=0 ;
    int nvecs = Wosize_val(iova_v) ;
    
    SKTTRACE(("skt_tcp_sends2v("));
    skt_add_string(send_iova, 0, prefix1_v);
    skt_add_ml_hdr(send_iova, 1, prefix2_v, ofs2_v, len2_v);
    skt_gather(send_iova, 2, iova_v);
    send_msghdr.msg_iovlen = nvecs+2;
    send_msghdr.msg_namelen = 0; 
    send_msghdr.msg_name = NULL;
    sock = Socket_val(sock_v);
    ret = sendmsg(sock, &send_msghdr, MSG_DONTWAIT) ;
    if (-1 == ret) {
        skt_tcp_error("skt_tcp_sends2v");
        return Val_int(0);
    }
    SKTTRACE(("len=%d)\n", ret));
    return (Val_int(ret));
}

value skt_tcp_sends2v_bytecode(value *argv, int argn){
    return skt_tcp_sends2v_native(argv[0], argv[1], argv[2], argv[3],
                                  argv[4], argv[5]);
}


// Read from a TCP socket into a string.
value skt_tcp_recv(value sock_v, value buf_v, value ofs_v, value len_v) 
{
    int ret;
    
    SKTTRACE(("skt_tcp_recv("));
    ret = recv(Socket_val(sock_v), &Byte(buf_v, Long_val(ofs_v)), Int_val(len_v),0) ;
    if (-1 == ret) {
        skt_tcp_error("skt_tcp_recv");
        return Val_int(0);
    }
    SKTTRACE(("len=%d)\n",ret));
    return Val_int(ret);
}

// Read from a TCP socket into an iovec.
value skt_tcp_recv_iov(value sock_v, value iov_v, value ofs_v, value len_v) 
{
    int ret;
    ocaml_skt_t sock = Socket_val(sock_v);
    char* buf = mm_Cptr_of_iovec(iov_v);
    int len_iov = mm_Len_of_iovec(iov_v);
    int len = Int_val(len_v);
    int ofs = Int_val(ofs_v);
        
    assert(len <= len_iov);
    
    SKTTRACE(("skt_tcp_recv_iov("));
    ret = recv(sock, buf+ofs, len, 0) ;
    if (-1 == ret) {
        skt_tcp_error("skt_recv_iov");
        return Val_int(0);
    }
    SKTTRACE(("len=%d)\n", ret));
    return Val_int(ret);
}


value skt_tcp_recv_packet(
    value sock_v, 
    value buf_v, 
    value ofs_v,
    value len_v,
    value iov_v
    )
{
    int ret=0;
    
    SKTTRACE(("skt_tcp_recv_packet("));
    recv_msghdr.msg_namelen = 0; 
    recv_msghdr.msg_name = NULL;
    recv_msghdr.msg_iovlen  = 2;
    Iov_len(recv_iova[0]) =  Int_val(len_v);
    Iov_buf(recv_iova[0]) = (char*)&Byte(buf_v, Int_val(ofs_v)) ;
    Iov_len(recv_iova[1]) = mm_Len_of_iovec(iov_v);
    Iov_buf(recv_iova[1]) = mm_Cptr_of_iovec(iov_v);
    SKTTRACE(("ml_len=%d, iov_len=%d, ", Int_val(len_v), mm_Len_of_iovec(iov_v)));
    ret = recvmsg(Socket_val(sock_v), &recv_msghdr, 0);
    if (-1 == ret) {
        skt_tcp_error("skt_tcp_recv_packet");
        return Val_int(0);
    }
    SKTTRACE((" len=%d)\n", ret));
    return Val_int(ret);
}

/**************************************************************/
/**************************************************************/
/* UDP section
 */

value skt_udp_send(
    value info_v,
    value buf_v,
    value ofs_v,
    value len_v
    )
{
    int len, ofs, i, ret =0;
    skt_sendto_info_t *info ;
    int naddr ;
    char *buf ;

    info = skt_Sendto_info_val(info_v);
    ofs = Int_val(ofs_v) ;
    len = Int_val(len_v) ;
    buf = ((char*)&Byte(buf_v,ofs)) ;
    SKTTRACE(("skt_udp_send(len=%d ofs=%d", len, ofs));
    
    naddr = info->naddr ;
    
    for (i=0;i<naddr;i++) {
	/* Send the message.  Assume we don't block or get interrupted.  
	 */
	ret = sendto(info->sock, buf, len, 0, &info->sa[i], info->addrlen) ;
	    
	SKTTRACE(("  <sent_len=%d (port=%d,addr=%s)>",
                  ret, 
                  ntohs(((struct sockaddr_in*)&(info->sa[i]))->sin_port),
                  inet_ntoa(((struct sockaddr_in*)&(info->sa[i]))->sin_addr)
                     ));
	
	if (-1 == ret) skt_udp_error("skt_udp_send");
    }
    SKTTRACE((")\n"));
    return Val_unit;
}


value skt_udp_mu_sendsv(
    value info_v,
    value prefix_v,
    value ofs_v,
    value len_v,
    value iova_v
    )
{
    int naddr=0, i, ret=0, len=0;
    ocaml_skt_t sock=0 ;
    skt_sendto_info_t *info ;
    int nvecs = Wosize_val(iova_v) ;
    
    SKTTRACE(("skt_udp_mu_sendsv("));
    info = skt_Sendto_info_val(info_v);
    send_msghdr.msg_iovlen = nvecs+2;
    send_msghdr.msg_namelen = info->addrlen ;
    skt_prepare_send_header(send_iova, peek_buf, Int_val(len_v), skt_iovl_len(iova_v));
    skt_add_ml_hdr(send_iova, 1, prefix_v, ofs_v, len_v);
    skt_gather(send_iova, 2, iova_v) ;
    
    sock = info->sock ;
    naddr = info->naddr ;
    
    for (i=0;i<naddr;i++) {
	/* Send the message.  Assume we don't block or get interrupted.  
	 */
	send_msghdr.msg_name = (char*) &info->sa[i] ;
	ret = sendmsg(sock, &send_msghdr, MSG_DONTWAIT) ;
/*	{
	    int j;
	    struct sockaddr_in *addr = (struct sockaddr_in*) &info->sa[i];
	    
	    for(j=0; j<nvecs+2; j++) {
		SKTTRACE((" <iov[%d].len=%d> ", j, Iov_len(send_iova[j])));
	    }
	    SKTTRACE(("\n sock=%d  iovlen=%d sent_len=%d", sock, nvecs+2, len));
	    SKTTRACE(("\n port=%d ip=%s", ntohs(addr->sin_port),
		      inet_ntoa(addr->sin_addr)));
                      }*/
	if (-1 == ret) skt_udp_error("skt_udp_mu_sendsv");
    }
    
    SKTTRACE((")\n"));
    return Val_unit;
}

/* Receive a UDP packet into a preallocated string
 */
value skt_udp_mu_recv_packet_into_str(value sock_v, value buf_v)
{
    ocaml_skt_t sock = Socket_val(sock_v);
    int usr_len=0, ml_len=0, len=0;
    char *buf = String_val(buf_v);
    
    SKTTRACE(("skt_udp_mu_recv_packet_into_str("));

    len = recvfrom(sock, buf, MAX_MSG_SIZE, 0, NULL, 0);
    if (-1 == len) {
	skt_udp_error("skt_udp_recv_packet_into_str");
	goto dump_packet;
    }
    
    if (0 == len || len < header_peek)
	goto dump_packet;

    ml_len = ntohl (*(uint32*) &(buf[0]));
    usr_len = ntohl (*(uint32*) &(buf[SIZE_INT32]));

    // A bogus packet, or a packet with a non-empty iovec.
    if (usr_len > 0 ||
        ml_len > (int)(MAX_MSG_SIZE-HEADER_PEEK) ||
        0 == ml_len)
	goto dump_packet;

    // Move the data to the beginning of the preallocated ML buffer
    memmove(buf, (char*)buf + HEADER_PEEK, ml_len);

 ret:
    SKTTRACE((" len=%d  ml_len=%d  usr_len=%d)\n", len, ml_len, usr_len));
    return(Val_int(ml_len));

 dump_packet:
    SKTTRACE(("<dump_packet>"));
    ml_len = 0;
    goto ret;
}

/* Receive a udp packet into a preallocated buffer.
 */
void skt_udp_mu_recv_packet(
    value sock_v,
    value ret_len_v,
    value ml_buf_v,
    value cbuf_v,
    value ofs_v
    )
{
    ocaml_skt_t sock = Socket_val(sock_v);
    char *buf = mm_Cbuf_val(cbuf_v) + Int_val(ofs_v);
    int usr_len=0, ml_len=0, len=0;
    
    SKTTRACE(("skt_udp_mu_recv_packet("));
    
    // This version if for debugging, it prints out the source IP 
/*    {
	struct sockaddr_in from;
	int from_len = sizeof(struct sockaddr_in);
	memset((char*)&from, 0, sizeof(struct sockaddr_in));
        
	len = recvfrom(sock, buf, MAX_MSG_SIZE, 0, (struct sockaddr*)&from, &from_len);
	SKTTRACE(("from=(%d,%s)", ntohs(from.sin_port), inet_ntoa(from.sin_addr)));
        }  */
    
    len = recvfrom(sock, buf, MAX_MSG_SIZE, 0, NULL, 0);
    if (-1 == len) {
	skt_udp_error("skt_udp_recv_packet");
	goto dump_packet;
    }

    if (0 == len || len < header_peek)
	goto dump_packet;

    ml_len = ntohl (*(uint32*) &(buf[0]));
    usr_len = ntohl (*(uint32*) &(buf[SIZE_INT32]));
    
    // A bogus packet, dump it.
    if (ml_len + usr_len > (int)(MAX_MSG_SIZE-HEADER_PEEK) ||
        (ml_len ==0 && usr_len ==0))
	goto dump_packet;
    
    // Copy the ML data into the preallocated ML buffer
    if (ml_len > 0) 
        memcpy(String_val(ml_buf_v), (char*)buf + HEADER_PEEK, ml_len);

    // Write the return length values
    Field(ret_len_v, 0) = Val_int(ml_len);
    Field(ret_len_v, 1) = Val_int(usr_len);
    
 ret:
    SKTTRACE((" len=%d  ml_len=%d  usr_len=%d)\n", len, ml_len, usr_len));
    return;
    
    /* PREF: should probably convert this into an exception
     */
 dump_packet:
    SKTTRACE(("<dump_packet>"));
    Field(ret_len_v, 0) = Val_int(0);
    Field(ret_len_v, 1) = Val_int(0);
    goto ret;
}

/**************************************************************/


