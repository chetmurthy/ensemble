/**************************************************************/
/*
 *  Ensemble, (Version 0.70p1)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
#define string_length string_length_hide
#include "skt.h"
#undef string_length

/* Ethernet is only supported on Linux.  You need the packet driver
 * installed.
 */
#if defined(linux) && defined(RAW_ETH)

#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <sys/ioctl.h>
#include <linux/if.h>
#include <linux/if_packet.h>
#include <linux/if_ether.h>
#include <sys/socket.h>
#include <sys/uio.h>
#include <netinet/in.h>
#include <assert.h>

/* From byterun/str.c.  We have our own copy here
 * so that it will be inlined.
 */
static INLINE
mlsize_t string_length(value s) {
  mlsize_t temp;
  temp = Bosize_val(s) - 1;
  assert(Byte (s, temp - Byte (s, temp)) == 0);
  return temp - Byte (s, temp);
}

typedef struct {
    char raw[ETH_ALEN] ;
} eth_addr_t ;

/* An ethernet header.
 */
typedef struct {
    char dst[ETH_ALEN] ;
    char src[ETH_ALEN] ;
    unsigned short prot ;
} eth_hdr_t ;

typedef struct {
    ocaml_skt sock ;
    int flags ;
    struct sockaddr_pkt addr ;
    struct msghdr msghdr ;
    int nhdr ;
    eth_hdr_t hdr[0] ;
} eth_msg_t ;

/* Adapted from mlvalues.h */
#define Wosize_bosize(sz) ((sz) / sizeof (value))

/* Ethernet appears to be supported.
 */
value ens_eth_supported(value ignored) {
    return Val_true ;
}

/* Open an ethernet packet socket on the specified
 * interface.
 */
value ens_eth_init(
        value interface_v,
	value addr_v
) {
    struct sockaddr sa;
    struct ifreq ifr;
    int sock ;
    int ret ;

    assert(Tag_val(interface_v) == String_tag) ;
    assert(Tag_val(addr_v) == String_tag) ;
    assert(string_length(addr_v) == ETH_ALEN) ;

    /* BUG: check that args are strings, lengths.
     */
    sock = socket(AF_PACKET, SOCK_PACKET, htons(ETH_P_ALL)) ;
    if (sock == -1) {
	serror("socket(AF_PACKET,SOCK_PACKET,ETH_P_ALL)", Nothing) ;
    }

    /* Bind the socket to the named interface.
     */
    memset(&sa, 0, sizeof(sa));
    sa.sa_family = AF_INET;
    (void)strncpy(sa.sa_data, String_val(interface_v), sizeof(sa.sa_data));
    ret = bind(sock, &sa, sizeof(sa)) ;
    if (ret == -1) {
	serror("bind", Nothing) ;
    }

    /* Get the address.
     */
    memset(&ifr, 0, sizeof(ifr));
    strncpy(ifr.ifr_name, String_val(interface_v), sizeof(ifr.ifr_name));
    if (ioctl(sock, SIOCGIFHWADDR, &ifr) < 0 ) {
	serror("ioctl(SIOCGIFHWADDR)", Nothing) ;
    }
    memcpy(String_val(addr_v), ifr.ifr_hwaddr.sa_data, ETH_ALEN);

    return skt_socket_of_fd(Val_int(sock)) ;
}

/* Preprocess information for sending to a set of ethernet
 * addresses.
 */
value ens_eth_sendto_info(
	value sock_v,
	value interface_v,
	value flags_v,
	value src_v,
	value dsta_v
) {
    eth_msg_t *msg ;
    value msg_v ;
    ocaml_skt sock ;
    int flags ;
    int size ;
    int ndst ;
    int i ;

    CAMLparam4(sock_v, interface_v, src_v, dsta_v) ;
    sock = Socket_val(sock_v) ;
    flags = Int_val(flags_v) ;
    ndst = Wosize_val(dsta_v) ;
    
    size = Wosize_bosize(sizeof(*msg) + sizeof(msg->hdr[0]) * ndst + 8/*?*/) ;
  
    /* Allocate and zero the message.
     */
    msg_v = alloc(size, Abstract_tag) ;
    
    msg = (eth_msg_t*) &Byte(msg_v, 0) ;

    /* It is necessary to zero this because of the msghdr.
     */
    memset((char*)msg, 0, size) ;

    msg->sock = sock ;
    msg->flags = flags ;
    msg->nhdr = ndst ;

    /* Fill in "address."  This specifies the interface to use.
     */
    msg->addr.spkt_family = AF_PACKET ;
    msg->addr.spkt_protocol = 0 ;
    strcpy((void*)&msg->addr.spkt_device, "eth0") ; /* BUG */

    /* Note that we cannot point the msghdr at the address
     * because this structure may be moved by a GC.
     */
    msg->msghdr.msg_namelen = sizeof(msg->addr) ;

    /* Fill in the headers.
     */
    for(i=0;i<ndst;i++) {
	memcpy(msg->hdr[i].dst, String_val(Field(dsta_v,i)), ETH_ALEN) ;
	memcpy(msg->hdr[i].src, String_val(src_v), ETH_ALEN) ;
	msg->hdr[i].prot = htons(ENSEMBLE_ETH_PROTO) ;
    }

    CAMLreturn(msg_v) ;
}


#define N_IOVS 20

/* Send to ethernet addresses.
 */
value ens_eth_sendtovs(
	value msg_v,
	value iova_v,
	value suffix_v
) {
    struct iovec iov[N_IOVS] ;
    eth_msg_t *msg ;
    int ret ;
    int ofs ;
    int len ;
    value buf_v ;
    value iov_v ;
    int flags ;
    int nvecs ;
    int i ;

    msg = (eth_msg_t*) &Byte(msg_v, 0) ;

    if (msg->nhdr == 0) {
	printf("alsdkjfsdlkjfsdlkfjsdlksdjflksdj\n") ;
	return Val_unit ;
    }

    flags = msg->flags ;

    /* The address length was set above.
     */
    msg->msghdr.msg_name = &msg->addr ;

    nvecs = Wosize_val(iova_v) ; /* inspired by array.c */
    assert(nvecs + 1 <= N_IOVS) ;
    
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

    if (string_length(suffix_v) > 0) {
	iov[nvecs+1].iov_base = String_val(suffix_v) ;
	iov[nvecs+1].iov_len  = string_length(suffix_v) ;
	nvecs ++ ;
    }

    iov[0].iov_len = ETH_HLEN ;

    msg->msghdr.msg_control = NULL ;
    msg->msghdr.msg_controllen = 0 ;
    msg->msghdr.msg_flags = 0 ;
    msg->msghdr.msg_iov = iov ;
    msg->msghdr.msg_iovlen = nvecs + 1 ;

#if 0
    { 
	int len = 0 ;
	for (i=0;i<msg->msghdr.msg_iovlen;i++) {
	    iov[0].iov_base = &msg->hdr[0] ;
	    len += iov[i].iov_len ;
	    printf("%d:%d (base=%08x)\n", i, iov[i].iov_len, (unsigned)iov[i].iov_base) ;
	}
	printf("total:%d\n", len) ;
    }
#endif

#if 0
    { 
	int i, j ;
	printf("ETH:") ;
	iov[0].iov_base = &msg->hdr[0] ;
	for (i=0;i<msg->msghdr.msg_iovlen;i++) {
	    for (j=0;j<iov[i].iov_len;j++) {
		printf("%02x", ((unsigned char*)iov[i].iov_base)[j]) ;
	    }
	    printf(":") ;
	}
	printf("\n") ;
    }
#endif

    for (i=0;i<msg->nhdr;i++) {
	iov[0].iov_base = &msg->hdr[i] ;
	ret = sendmsg(msg->sock, &msg->msghdr, flags) ;
	if (ret == -1) {
	    perror("sendmsg(eth)") ;
	}
    }
    return Val_unit ;
}

/* Similar to udp_recv, except that we bump the offset up by 2 and
 * expect messages to be of (len mod 4 = 2) because of that darn
 * ethernet header.
 */
value ens_eth_recv(		/* ML */
        value sock_v,
	value buf_v,
	value ofs_v,
	value len_v
) {
  int ret ;
  int len ;
  int ofs ;
  eth_hdr_t *hdr ;
  SKTTRACE;
  ofs = Long_val(ofs_v) ;
  len = Long_val(len_v) ;

#ifdef _WIN32
  /* Windows/NT seems to prefer that we use recvfrom(), even though recv()
   * should be ok.
   */
  ret = recvfrom(Socket_val(sock_v), &Byte(buf_v, ofs + 2), len, 0, NULL, NULL) ;
#else
  ret = recv(Socket_val(sock_v), &Byte(buf_v, ofs + 2), len, 0) ;
#endif

  /* First, check if everything is OK and if so quickly return.
   * Note that ((ret&3)==2) implies (ret!=(-1)).
   */
  if ((ret < len) && ((ret & 3) == 2)) {
    assert(ret != -1) ;
    hdr = (void*) &Byte(buf_v, ofs + 2) ;
    /* Check that the protocol matches.
     */
    if (hdr->prot != htons(ENSEMBLE_ETH_PROTO)) {
	return Val_int(0) ;
    }
    return Val_int(ret + 2) ;
  }

  /* Check for truncated messages.
   */
  if (ret == len) {
    fprintf(stderr,"SOCKET:eth_recv:warning:got packet that is maximum size (probably truncated), dropping (len=%d)\n", ret) ;
    return Val_int(0) ;
  }

  /* Check for non-4byte-word aligned messages.
   */
  if (ret != -1 && ((ret & 3) != 2)) {
#if 0
    /* This actually happens for ethernet.
     */
    fprintf(stderr,"SOCKET:eth_recv:warning:got packet that is not 4-byte aligned, dropping (len=%d)\n", ret) ;
#endif
    return Val_int(0) ;
  }

  /* Handle remaining errors.
   */
  assert(ret == -1) ;
  skt_recv_error() ;
  return Val_int(0) ;
}

#else

value ens_eth_supported() { return Val_false ; }
value ens_eth_init()      { invalid_argument("eth_init not implemented") ; }
value ens_eth_recv()      { invalid_argument("eth_recv not implemented") ; }
value ens_eth_sendto_info() { invalid_argument("eth_sendto_info not implemented") ; }
value ens_eth_sendtovs()  { invalid_argument("eth_sendtovs not implemented") ; }


#endif
