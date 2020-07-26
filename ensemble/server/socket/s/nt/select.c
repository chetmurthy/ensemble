/**************************************************************/
/* SELECT.C: optimized select and polling operations. */
/* Author: Mark Hayden, 8/97 */
/**************************************************************/
/* Based on otherlibs/unix/select.c in Objective Caml */
/**************************************************************/
#include "skt.h"
/**************************************************************/

value skt_select(
    value fdinfo,
    value timeout_v
    )
{
    value readfds ; 
    value writefds ; 
    value exceptfds ; 
    
    file_descr_set read, write, except, *rp, *wp, *ep;
    struct timeval tv;
    struct timeval *tvp;
    int retcode;
    
    readfds = Field(fdinfo,0) ;
    writefds = Field(fdinfo,1) ;
    exceptfds = Field(fdinfo,2) ;

    /* When selecting again, be sure to recompute
     * the fd info.
     */
 again:
    /* Get fd info.
     */
    rp = fdarray_to_fdset(readfds, &read) ;
    wp = fdarray_to_fdset(writefds, &write) ;
    ep = fdarray_to_fdset(exceptfds, &except) ;
    
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
    
    /* On Windows, don't mess around with setting
     * the fdsize minimally.
     */
//    SKTTRACE(("select() timeval sec,usec=(%d,%d)",tv.tv_sec,tv.tv_usec));
    retcode = select(FD_SETSIZE, rp, wp, ep, tvp) ;
//    SKTTRACE((")"));
    
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
    )
{
    value readfds ; 
    value writefds ; 
    value exceptfds ; 
    file_descr_set read, write, except, *rp, *wp, *ep ;
    struct timeval tv ;
    int retcode ;
    
    readfds = Field(fdinfo,0) ;
    writefds = Field(fdinfo,1) ;
    exceptfds = Field(fdinfo,2) ;
    
 again:
    rp = fdarray_to_fdset(readfds, &read) ;
    wp = fdarray_to_fdset(writefds, &write) ;
    ep = fdarray_to_fdset(exceptfds, &except) ;
    tv.tv_sec = 0 ;
    tv.tv_usec = 0 ;
    retcode = select(FD_SETSIZE, rp, wp, ep, &tv) ;
    
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

