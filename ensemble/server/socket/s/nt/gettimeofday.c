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
/* GETTIMEOFDAY.C: optimized gettimeofday stubs. */
/* Authors: Robbert van Renesse, Mark Hayden, 10/97 */
/**************************************************************/
#include "skt.h"
/**************************************************************/

#define ONEMILLION 1000000
#define TENMILLION 10000000

/* NOTE: Ensemble now use timeval = {sec10; usec} */
INLINE static
void set(value tv_v,long sec,long usec) {
    usec += ((sec % 10) * ONEMILLION);
    sec = sec / 10;
    if (usec < 0) {
        fprintf(stderr,"SOCKET:gettimeofday:usec<0, fixing\n") ;
        sec  -= 1 ;
        usec += TENMILLION ;
        assert(usec >= 0 && usec < TENMILLION) ;
    } else if (usec >= TENMILLION) {
        fprintf(stderr,"SOCKET:gettimeofday:usec>1E6, fixing\n") ;
        sec  += 1 ;
        usec -= TENMILLION ;
        assert(usec >= 0 && usec < TENMILLION) ;
    }
    Field(tv_v,0) = Val_long(sec) ;
    Field(tv_v,1) = Val_long(usec) ;
}

#ifdef PLARGE_INTEGER

value skt_gettimeofday(value a_v) {              /* ML */
    double time ;
    static inited = 0 ;
    static __int64 ticks_per_sec ;
    static __int64 ticks_per_usec ;
    __int64 ticks ;
    long sec, usec ;
    
    /* On first call, compute the performance rate.
     */
    if (!inited) {
        inited = 1 ;
        QueryPerformanceFrequency((PLARGE_INTEGER) &ticks_per_sec) ;
        ticks_per_usec = ticks_per_sec / MILLION ;
    }
    
    QueryPerformanceCounter((PLARGE_INTEGER) &ticks);
    
    /* Is this right?
     */
    sec = ticks / ticks_per_sec ;
    usec = (ticks % ticks_per_sec) / ticks_per_usec ;
    set(a_v,sec,usec) ;
    return Val_unit ;
}

#else /* PLARGE_INTEGER */

#include <sys/timeb.h>

value skt_gettimeofday(value a_v)                /* ML */
{
    struct _timeb tb;
    //  SKTTRACE(("skt_get_timeofday\n")) ;
    
    _ftime(&tb) ;
    set(a_v,tb.time,tb.millitm*1000) ;
    return Val_unit ;
}

#endif /* PLARGE_INTEGER */



