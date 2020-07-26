/**************************************************************/
/* SOCKFD.H */
/* Author: Ohad Rodeh 11/2001 */
/**************************************************************/
/* Interfacing sockets between C and ML.
 */

#ifndef _WIN32
typedef int ocaml_skt_t ;

/* Get the file descriptor inside the wrapper.
 */
#define Socket_val(sock_v) (Int_val(sock_v))
#define Val_socket(sock)   (Val_int(sock))

#else
typedef SOCKET ocaml_skt_t ;

value skt_win_alloc_handle(HANDLE h);

/* Get the file descriptor inside the wrapper.  We define Socket_val
 * in terms of Handle_val() to make it clear what is going on here.
 */
#define Handle_val(v) (*((HANDLE *)(v))) /* from unixsupport.h */

#define Val_socket(sock) (skt_win_alloc_handle((HANDLE)sock))
#define Socket_val(sock_v) ((SOCKET) (Handle_val(sock_v)))

#endif
