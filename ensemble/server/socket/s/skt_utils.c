/**************************************************************/
/* SKT_UTILS.H: */
/* Author: Ohad Rodeh 12/2003, based on code by Mark Hayden */
/**************************************************************/
/* Notes:
 * 1. Based on otherlibs/unix/select.c in Objective Caml
 * 2. The code has been placed in an H file because some C compilers
 *    respect the INLINE declaration only for H files. 
 */
/**************************************************************/
#include "skt.h"
/**************************************************************/

#ifndef HAS_SOCKETS
#error No socket support, cannot compile the optimized socket library.
#endif

file_descr_set *fdarray_to_fdset(
    value fdinfo,
    file_descr_set *fdset
    )
{
    value sock_arr_v ;
    int i, n ;
    ocaml_skt_t fd ;
    
    /* Go to the socket array.
     */
    sock_arr_v = Field(fdinfo,0) ;
    
    /* If no sockets then just return NULL. 
     */
    n = Wosize_val(sock_arr_v) ;
    if (n == 0) 
	return NULL ;
    
    /* Set the fdset.
     */
    FD_ZERO(fdset) ;
    for (i=0;i<n;i++) {
	fd = Socket_val(Field(sock_arr_v,i)) ;
//	SKTTRACE(("select: fd=%d\n", fd));
	FD_SET(fd, fdset) ;
    }
    
    return fdset ;
}

void fdset_to_fdarray(
    value fdinfo,
    file_descr_set *fdset
    )
{
    value sock_arr_v, ret_arr_v ;
    int i, n ;
    ocaml_skt_t fd ;
    
    /* If fdset is NULL then just return.
     * The array should be of zero length.
     */
    if (!fdset) return ;
    
    /* Get the arrays (and length).
     */
    sock_arr_v = Field(fdinfo,0) ;
    ret_arr_v = Field(fdinfo,1) ;
    n = Wosize_val(ret_arr_v) ;
    
    /* Scan through the fdset.
     */
    for (i=0;i<n;i++) {
	fd = Socket_val(Field(sock_arr_v,i)) ;
	Field(ret_arr_v,i) = Val_bool(FD_ISSET(fd, fdset)) ;
    }
}

/**************************************************************/

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


