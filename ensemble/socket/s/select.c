/**************************************************************/
/* SELECT.C: optimized select and polling operations. */
/* Author: Mark Hayden, 8/97 */
/**************************************************************/
/* Based on otherlibs/unix/select.c in Objective Caml */
/**************************************************************/
#include "skt.h"

#if defined(HAS_SELECT) || defined(_WINSOCKAPI_)

#ifndef _WINSOCKAPI_
#include <sys/time.h>
#endif

#ifdef HAS_SYS_SELECT_H
#include <sys/select.h>
#endif

typedef fd_set file_descr_set;

/* This stuff shouldn't be necessary.
 */
#if 0
#ifdef FD_ISSET
typedef fd_set file_descr_set;
#else
typedef int file_descr_set;
#define FD_SETSIZE (sizeof(int) * 8)
#define FD_SET(fd,fds) (*(fds) |= 1 << (fd))
#define FD_CLR(fd,fds) (*(fds) &= ~(1 << (fd)))
#define FD_ISSET(fd,fds) (*(fds) & (1 << (fd)))
#define FD_ZERO(fds) (*(fds) = 0)
#endif
#endif

/***********************************************************************/
#ifdef INLINE_PRAGMA
#pragma inline fdarray_to_fdset
#endif
static /*INLINE*/
file_descr_set *fdarray_to_fdset(
	int max_fd,			 
        value fdinfo,
	file_descr_set *fdset
) {
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
    SKTTRACE(("select: fd=%d\n", fd));
    FD_SET(fd, fdset) ;
  }
  
  return fdset ;
}

#ifdef INLINE_PRAGMA
#pragma inline fdset_to_fdarray
#endif
INLINE static
void fdset_to_fdarray(
        value fdinfo,
	file_descr_set *fdset
) {
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

value skt_select(
        value fdinfo,
	value timeout_v
) {
  value readfds ; 
  value writefds ; 
  value exceptfds ; 
  
  file_descr_set read, write, except, *rp, *wp, *ep;
  struct timeval tv;
  struct timeval *tvp;
  int retcode;
  ocaml_skt_t max_fd;

  readfds = Field(fdinfo,0) ;
  writefds = Field(fdinfo,1) ;
  exceptfds = Field(fdinfo,2) ;
#ifdef _WIN32
  /* On Windows, don't mess around with setting
   * the fdsize minimally.
   */
  max_fd = FD_SETSIZE ;
#else
  max_fd = Field(fdinfo,3) ;
#endif

  /* When selecting again, be sure to recompute
   * the fd info.
   */
again:
  /* Get fd info.
   */
  rp = fdarray_to_fdset(max_fd, readfds, &read) ;
  wp = fdarray_to_fdset(max_fd, writefds, &write) ;
  ep = fdarray_to_fdset(max_fd, exceptfds, &except) ;
  
  /* Get timeout info. In Ensemble now timeval = {sec10;usec}
   */
  tv.tv_sec  = (Long_val(Field(timeout_v,0)) * 10) + (Long_val(Field(timeout_v,1)) / 1000000) ;
  tv.tv_usec = (Long_val(Field(timeout_v,1)) % 1000000) ;
  
  /* If negative, then use NULL.
   */
  if (tv.tv_sec < 0 || tv.tv_usec < 0)
    tvp = (struct timeval *) NULL ;
  else
    tvp = &tv ;

  SKTTRACE(("select() timeval sec,usec=(%d,%d)",tv.tv_sec,tv.tv_usec));
  retcode = select(max_fd, rp, wp, ep, tvp) ;
  SKTTRACE((")"));

  /* We repeatly select as long as we get EINTR errnos.
   */
  if (retcode == -1 && (rp || wp || ep)) {
    if (h_errno == EINTR)
      goto again ;
    serror("select");
  }

  /* Extract fd info.
   */
  fdset_to_fdarray(readfds, rp);
  fdset_to_fdarray(writefds, wp);
  fdset_to_fdarray(exceptfds, ep);

  return Val_int(retcode) ;
}

value skt_poll(
        value fdinfo
) {
  value readfds ; 
  value writefds ; 
  value exceptfds ; 
  file_descr_set read, write, except, *rp, *wp, *ep ;
  struct timeval tv ;
  int retcode ;
  ocaml_skt_t max_fd ;

  readfds = Field(fdinfo,0) ;
  writefds = Field(fdinfo,1) ;
  exceptfds = Field(fdinfo,2) ;
#ifdef _WIN32
  /* On Windows, don't mess around with setting
   * the fdsize minimally.
   */
  max_fd = FD_SETSIZE ;
#else
  max_fd = Field(fdinfo,3) ;
#endif

again:
  rp = fdarray_to_fdset(max_fd, readfds, &read) ;
  wp = fdarray_to_fdset(max_fd, writefds, &write) ;
  ep = fdarray_to_fdset(max_fd, exceptfds, &except) ;
  tv.tv_sec = 0 ;
  tv.tv_usec = 0 ;
  retcode = select(max_fd, rp, wp, ep, &tv) ;
  
  if (retcode == -1 && (rp || wp || ep)) {
    if (h_errno == EINTR)
      goto again ;
    serror("poll:select");
  }

  fdset_to_fdarray(readfds, rp);
  fdset_to_fdarray(writefds, wp);
  fdset_to_fdarray(exceptfds, ep);
  return Val_int(retcode) ;
}

#else
#error Cannot compile the optimized select calls, your system does not support it. 
#endif
