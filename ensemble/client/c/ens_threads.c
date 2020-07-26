/**************************************************************/
/* ENS_THREADS.C */
/* Author: Ohad Rodeh 10/2003 */
/* Based on code from HOT, written by Robbert Van Renesse, Werner Vogels,
 * Mark Hayden, and Alexery Vaysburd */
/**************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include "ens_threads.h"
#include "ens_utils.h"
/**************************************************************/
#define NAME "THREADS"
/**************************************************************/

/* Win32 version
 */
#ifdef _WIN32

#include <assert.h>
#include <windows.h>
#include "ens_utils.h" 

struct ens_lock_t {
    CRITICAL_SECTION	lck;
};

/* Create a new thread.  
 */
void EnsThreadCreate(void (*routine)(void*), void *arg)
{
    DWORD   dwThreadID, dwStackSize = 0, stacksize = 100000;
    
    EnsTrace(NAME,"starting thread(\n");
    if (CreateThread(NULL, stacksize, (LPTHREAD_START_ROUTINE)routine, arg, 0, &dwThreadID) == NULL)
	EnsPanic("CreateThread");
    EnsTrace(NAME,")\n");
}

/* Create a new lock.  
 */
ens_lock_t *EnsLockCreate(void)
{
    ens_lock_t *l;
    
    l = (ens_lock_t*) EnsMalloc(sizeof(struct ens_lock_t));
    
    InitializeCriticalSection(&l->lck);
    return l;
}

/* Destroy a lock. 
 */
void EnsLockDestroy(ens_lock_t *l)
{
    DeleteCriticalSection(&l->lck);
    free(l);
}

/* Locks/unlocks a lock.  
 */
void EnsLockTake(ens_lock_t *l)
{
    EnsTrace(NAME,"EnsLockTake %p", l);
    EnterCriticalSection(&l->lck);
}

void EnsLockRelease(ens_lock_t *l)
{
    EnsTrace(NAME,"EnsLockRelease %p",l);
    LeaveCriticalSection(&l->lck);
}

#endif

/**************************************************************/
/**************************************************************/
/* The linux, pthreads version
 */
#ifdef linux
#include <semaphore.h>
#include <pthread.h>

struct ens_lock_t {
    pthread_mutex_t lck;
};

static pthread_t td;

typedef void*(*ens_thread_routine_t)(void*);

/* Create a new thread
 */
void EnsThreadCreate(void (*routine)(void*), void *arg )
{
    pthread_attr_t attr;
    
    if (pthread_attr_init(&attr))
	EnsPanic("EnsThreadCreate: pthread_attr_init");
    
/* Linux pthreads use an "enum" for this rather than #define, so we
 * just check for Linux.  Which platforms don't support this?  
 */
#if defined(PTHREAD_CREATE_DETACHED) || defined(linux)
    /* This is done in order to release the thread resources when the
     * thread dies.  
     */
    if (pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED))
	EnsPanic("EnsThreadCreate: pthread_attr_setdetachstate");
#endif
    
    if (pthread_create(&td, &attr, (ens_thread_routine_t) routine, arg))
	EnsPanic("EnsThreadCreate: pthread_create");
    pthread_attr_destroy(&attr);
}


/* Create a Lock
 */
ens_lock_t *EnsLockCreate(void)
{
    ens_lock_t *l;
    
    l = (ens_lock_t*) EnsMalloc(sizeof(ens_lock_t)) ;

    if (pthread_mutex_init(&l->lck,NULL))
	EnsPanic("EnsLockCreate: pthread_mutex_init") ;
    return l;
}

void EnsLockDestroy(ens_lock_t *l)
{
    assert(l) ;
    
   if (pthread_mutex_destroy(&l->lck))
       EnsPanic("EnsLockDestroy: pthread_mutex_destroy");
    free(l);
}

void EnsLockTake(ens_lock_t *l)
{
    assert(l) ;
//    TRACE("ce_lck_Lock");
    if (pthread_mutex_lock(&l->lck))
	EnsPanic("EnsLockTake: pthread_mutex_lock") ;
}

void EnsLockRelease(ens_lock_t *l)
{
    assert(l) ;
//    TRACE("ce_lck_Unlock");
    if (pthread_mutex_unlock(&l->lck))
	EnsPanic("EnsLockRelease: pthread_mutex_unlock") ;
}
#endif

/**************************************************************/
/**************************************************************/
/* Solaris version
 */

#ifdef Solaris
#include <assert.h>
#include <thread.h>
#include <synch.h>

typedef void*(*ens_thread_routine_t)(void*);

/* Create a new thread
 */
void
EnsThreadCreate(void (*routine)(void*), void *arg)

{
    if (thr_create(NULL, stacksize, 
		   (ens_thread_routine_t) routine, arg, 0, NULL))     
	EnsPanic("EnsThreadCreate: thr_create");
}

struct ens_lock_t {
  mutex_t lck ;
} ;


/* Create a lock
 */
ens_lock_t *EnsLockCreate(void)
{
    ens_lock_t *l;
    
    l = (ens_lock_t*) EnsMalloc(sizeof(ens_lock_t)) ;

    if (mutex_init(&l->lck, 0, NULL))
	EnsPanic("EnsLockCreate: sema_init") ;
    return l;
}


/* Destroy a lock
 */
void EnsLockDestroy(ens_lock_t *l)
{
    assert(l) ;
    
    if (mutex_destroy(&l->lck))
	EnsPanic("EnsLockDestroy : mutex_destroy");
    free(l);
}

/* Lock a lock
 */
void EnsLockTake(ens_lock_t *l)
{
    assert(l) ;
    
    if (mutex_lock(&l->lck))
	EnsPanic("EnsLockTake: mutex_lock") ;
}

/* Unlock a lock
 */
void EnsLockRelease(ens_lock_t *l)
{
    assert(l) ;
    
    if (mutex_unlock(&l->lck))
	EnsPanic("EnsLockRelease: mutex_unlock") ;
}

#endif /* Solaris version */

/**************************************************************/
/**************************************************************/
/* The HP-UX, pthreads version
 */
#ifdef hpux
#include <semaphore.h>
#include <pthread.h>

struct ens_lock_t {
    pthread_mutex_t lck;
};

static pthread_t td;

typedef void*(*ens_thread_routine_t)(void*);

/* Create a new thread
 */
void EnsThreadCreate(void (*routine)(void*), void *arg )
{
  int               attr_stat;
  /*pthread_attr_t is mainly a pointer on HP-UX!!! */
  pthread_attr_t    attr;
    
  attr_stat = pthread_attr_create(&attr);
  if (attr_stat == -1 )
    EnsPanic("EnsThreadCreate: pthread_attr_create");
    

#if defined(PTHREAD_CREATE_DETACHED)
    /* This is done in order to release the thread resources when the
     * thread dies.  
     */
    if (pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED))
	EnsPanic("EnsThreadCreate: pthread_attr_setdetachstate");
#endif

    
    if (pthread_create(&td, attr, (ens_thread_routine_t) routine, arg))
	EnsPanic("EnsThreadCreate: pthread_create");
    pthread_attr_delete(&attr);
}


/* Create a Lock
 */
ens_lock_t *EnsLockCreate(void)
{
    ens_lock_t *l;
    
    l = (ens_lock_t*) EnsMalloc(sizeof(ens_lock_t)) ;

    if (pthread_mutex_init(&l->lck, pthread_mutexattr_default))
	EnsPanic("EnsLockCreate: pthread_mutex_init") ;
    return l;
}


void EnsLockDestroy(ens_lock_t *l)
{
    assert(l) ;
    
   if (pthread_mutex_destroy(&l->lck))
	EnsPanic("EnsLockDestroy: pthread_mutex_destroy");
    free(l);
}

void EnsLockTake(ens_lock_t *l)
{
    assert(l) ;
//    TRACE("ce_lck_Lock");
    if (pthread_mutex_lock(&l->lck))
	EnsPanic("EnsLockTake: pthread_mutex_lock") ;
}


void EnsLockRelease(ens_lock_t *l)
{
    assert(l) ;
//    TRACE("ce_lck_Unlock");
    if (pthread_mutex_unlock(&l->lck))
	EnsPanic("EnsLockRelease: pthread_mutex_unlock") ;
}
#endif

/**************************************************************/
/* The Darwin (OS X) version
 */
#ifdef __APPLE__
#include <pthread.h>
#include <semaphore.h>

struct ens_lock_t {
    pthread_mutex_t lck;
};

static pthread_t td;

typedef void*(*ens_thread_routine_t)(void*);

/* Create a new thread
 */
void EnsThreadCreate(void (*routine)(void*), void *arg )
{
    pthread_attr_t attr;
    
    if (pthread_attr_init(&attr))
	EnsPanic("EnsThreadCreate: pthread_attr_init");
    
/* Linux pthreads use an "enum" for this rather than #define, so we
 * just check for Linux.  Which platforms don't support this?  
 */
#if defined(PTHREAD_CREATE_DETACHED)
    /* This is done in order to release the thread resources when the
     * thread dies.  
     */
    if (pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED))
	EnsPanic("EnsThreadCreate: pthread_attr_setdetachstate");
#endif
    
    if (pthread_create(&td, &attr, (ens_thread_routine_t) routine, arg))
	EnsPanic("EnsThreadCreate: pthread_create");
    pthread_attr_destroy(&attr);
}


/* Create a Lock
 */
ens_lock_t *EnsLockCreate(void)
{
    ens_lock_t *l;
    
    l = (ens_lock_t*) EnsMalloc(sizeof(ens_lock_t)) ;

    if (pthread_mutex_init(&l->lck,NULL))
	EnsPanic("EnsLockCreate: pthread_mutex_init") ;
    return l;
}

void EnsLockDestroy(ens_lock_t *l)
{
    assert(l) ;
    
   if (pthread_mutex_destroy(&l->lck))
       EnsPanic("EnsLockDestroy: pthread_mutex_destroy");
    free(l);
}

void EnsLockTake(ens_lock_t *l)
{
    assert(l) ;
//    TRACE("ce_lck_Lock");
    if (pthread_mutex_lock(&l->lck))
	EnsPanic("EnsLockTake: pthread_mutex_lock") ;
}

void EnsLockRelease(ens_lock_t *l)
{
    assert(l) ;
//    TRACE("ce_lck_Unlock");
    if (pthread_mutex_unlock(&l->lck))
	EnsPanic("EnsLockRelease: pthread_mutex_unlock") ;
}
#endif

/**************************************************************/
/**************************************************************/
