/**************************************************************/
/* CE_THREADS.C */
/* Author: Ohad Rodeh 03/2002 */
/* Based on code from HOT, written by Robbert Van Renesse, Werner Vogels,
 * Mark Hayden, and Alexery Vaysburd */
/**************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#define CE_MAKE_A_DLL
#include "ce_threads.h"
#include "ce_trace.h"
/**************************************************************/
#define NAME "CE_THREADS"
/**************************************************************/

/* We need to redefine this unfortunetly.
 */
static void
ce_panic(char *s)
{
    printf("CE: Fatal error: %s\n", s);
    perror("");
    exit(1);
}

static void *
ce_malloc(int size)
{
    void *ptr;
    
    ptr = malloc(size);
    if (ptr == NULL) {
	printf("Out of memory, exiting\n");
	exit(1);
    }
    return ptr;
}

/**************************************************************/
/**************************************************************/
/* Win32 version
 */
#ifdef _WIN32

#include <assert.h>
#include <windows.h>
 
#include "ce_threads.h"

struct ce_sema {
    HANDLE sema;
};

struct ce_lck {
    CRITICAL_SECTION	lck;
};

/* Create a new thread.  
 */
LINKDLL void
ce_thread_Create(void (*routine)(void*), void *arg, int stacksize)
{
    DWORD   dwThreadID, dwStackSize = 0;

    TRACE("starting thread(\n");
    if (CreateThread(NULL, stacksize, (LPTHREAD_START_ROUTINE)routine, arg, 0, &dwThreadID) == NULL)
	ce_panic("hot_thread_Create: t_create");
    TRACE(")\n");
}

/* Create a semaphore.  
 */
LINKDLL ce_sema_t *
ce_sema_Create(int initial_value) 
{
    ce_sema_t *sp;
    
    sp = (ce_sema_t*) malloc(sizeof(ce_sema_t));
    if (sp == NULL)
	ce_panic("hot_sema_Create:  malloc returned NULL");
    
    if ((sp->sema = CreateSemaphore(NULL, initial_value, 0x7fffffff, NULL)) == NULL) {
        printf("gle %d\n",GetLastError());
        ce_panic("hot_sema_Create: failed to create semaphore");
    }
    
    return sp;
}

/* Destroy a semaphore.  
 */
LINKDLL void
ce_sema_Destroy(ce_sema_t *sp)
{
    CloseHandle(sp->sema);
    free(sp);
}

/* Increase the value of a semaphore.  
 */
LINKDLL void
ce_sema_Inc(ce_sema_t *sp)
{
    assert(sp != NULL);
    ReleaseSemaphore(sp->sema, 1, NULL);
}

/* Decrease the value of a semaphore (may block).  
 */
LINKDLL void
ce_sema_Dec(ce_sema_t *sp)
{
    WaitForSingleObject(sp->sema, INFINITE);
}



/* Create a new lock.  
 */
LINKDLL ce_lck_t *
ce_lck_Create()
{
    ce_lck_t *l;
    
    if ((l = (ce_lck_t*) malloc(sizeof(struct ce_lck))) == NULL)
	ce_panic("ce_lck_Create: malloc returned NULL");
    
    InitializeCriticalSection(&l->lck);
    return l;
}

/* Destroy a lock. 
 */
LINKDLL void
ce_lck_Destroy(ce_lck_t *l) {
    DeleteCriticalSection(&l->lck);
    free(l);
}

/* Locks/unlocks a lock.  
 */
LINKDLL void
ce_lck_Lock(ce_lck_t *l) {
    EnterCriticalSection(&l->lck);
}

LINKDLL void
ce_lck_Unlock(ce_lck_t *l) {
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

struct ce_sema {
    sem_t sema ;
};

struct ce_lck {
    pthread_mutex_t lck;
};

static pthread_t td;

typedef void*(*ce_thread_routine)(void*);

/* Create a new thread
 */
void
ce_thread_Create(void (*routine)(void*), 
		 void *arg, 
		 int stacksize) {
    pthread_attr_t attr;
    
    if (pthread_attr_init(&attr))
	ce_panic("ce_thread_Create: pthread_attr_init");
    
/* Linux threads currently do not support pthread_attr_setstacksize.
 */
#if !(defined(linux))
    if (attr_arg != NULL) {
	if (pthread_attr_setstacksize(&attr, stacksize))
	    ce_panic("ce_thread_Create: pthread_attr_setstacksize");
    }
#endif
    
/* Linux pthreads use an "enum" for this rather than #define, so we
 * just check for Linux.  Which platforms don't support this?  
 */
#if defined(PTHREAD_CREATE_DETACHED) || defined(linux)
    /* This is done in order to release the thread resources when the
     * thread dies.  
     */
    if (pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED))
	ce_panic("ce_thread_Create: pthread_attr_setdetachstate");
#endif
    
    if (pthread_create(&td, &attr, (ce_thread_routine) routine, arg))
	ce_panic("hot_thread_Create: pthread_create");
    pthread_attr_destroy(&attr);
}


/* Create a semaphore.
 */
ce_sema_t *
ce_sema_Create(int initial_value)
{
    ce_sema_t *sp;
    
    sp = (ce_sema_t*) ce_malloc(sizeof(ce_sema_t)) ;

    if (sem_init(&sp->sema,0,initial_value))
	ce_panic("hot_sema_Create: sema_init") ;
    return sp;

}

void
ce_sema_Destroy(ce_sema_t *sp) {
    assert(sp) ;
    
    if (sem_destroy(&sp->sema))
	ce_panic("hot_sema_Destroy");

    free(sp);
}

void
ce_sema_Inc(ce_sema_t *sp) {
    assert(sp) ;
    TRACE("ce_sema_Inc");
    if (sem_post(&sp->sema))
	ce_panic("hot_sema_Inc: sem_post") ;
}

void
ce_sema_Dec(ce_sema_t *sp) {
    assert(sp) ;
    TRACE("ce_sema_Dec");
    if (sem_wait(&sp->sema))
	ce_panic("ce_sema_Dec: sem_wait") ;
}

/* Create a Lock
 */
ce_lck_t *
ce_lck_Create(void)
{
    ce_lck_t *l;
    
    l = (ce_lck_t*) ce_malloc(sizeof(ce_lck_t)) ;

    if (pthread_mutex_init(&l->lck,NULL))
	ce_panic("hot_sema_Create: sema_init") ;
    return l;
}

void
ce_lck_Destroy(ce_lck_t *l) {
    assert(l) ;
    
   if (pthread_mutex_destroy(&l->lck))
	ce_panic("ce_lck_Destroy: pthread_mutex_destroy");
    free(l);
}

void
ce_lck_Lock(ce_lck_t *l) {
    assert(l) ;
//    TRACE("ce_lck_Lock");
    if (pthread_mutex_lock(&l->lck))
	ce_panic("ce_lck_Lock: pthread_mutex_lock") ;
}

void
ce_lck_Unlock(ce_lck_t *l) {
    assert(l) ;
//    TRACE("ce_lck_Unlock");
    if (pthread_mutex_unlock(&l->lck))
	ce_panic("ce_lck_Unlock: pthread_mutex_unlock") ;
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
#include "hot_sys.h"
#include "hot_error.h"
#include "hot_thread.h"

typedef void*(*hot_thread_routine)(void*);

/* Create a new thread
 */
void
ce_thread_Create(void (*routine)(void*), 
		 void *arg, 
		 int stacksize) 
{
    if (thr_create(NULL, stacksize, 
		   (hot_thread_routine) routine, arg, 0, NULL))     
	ce_panic("ce_thread_Create: thr_create");
}

struct ce_lck {
  mutex_t lck ;
} ;


/* Create a lock
 */
ce_lck_t *
ce_lck_Create(void)
{
    ce_lck_t *l;
    
    l = (ce_lck_t*) ce_malloc(sizeof(ce_lck_t)) ;

    if (mutex_init(&l->lck, 0, NULL))
	ce_panic("hot_sema_Create: sema_init") ;
    return l;
}


/* Destroy a lock
 */
void
ce_lck_Destroy(ce_lck_t *l)
{
    assert(l) ;
    
    if (mutex_destroy(&l->lck))
	ce_panic("ce_lck_Destroy: mutex_destroy");
    free(l);
}

/* Lock a lock
 */
void
ce_lck_Lock(ce_lck_t *l) {
  assert(l) ;

  if (mutex_lock(&l->lck))
      ce_panic("ce_lck_Lock: mutex_lock") ;
}

/* Unlock a lock
 */
void ce_lck_Unlock(ce_lck_t *l)
{
    assert(l) ;
    
    if (mutex_unlock(&l->lck))
	ce_panic("ce_lck_Unlock: mutex_unlock") ;
}


struct ce_sema {
    sema_t sema ;
} ;

/* Create a semaphore.
 */
ce_sema_t *
ce_sema_Create(int initial_value)
{
    ce_sema_t *sp;
    
    sp = (ce_sema_t*) ce_malloc(sizeof(ce_sema_t)) ;

    if (sema_init(&sp->sema, initial_value, 0, NULL))
      ce_panic("hot_sema_Create: sema_init") ;
    return sp;
}

void
ce_sema_Destroy(ce_sema_t *sp)
{
  assert(sp) ;
  
  if (sema_destroy(&sp->sema))
      ce_panic("ce_sema_Destroy: sema_destroy");

  free(sema);
}

void
ce_sema_Inc(ce_sema_t *sp)
{
  assert(sp) ;
  
  if (sema_post(&sp->sema))
      ce_panic("ce_sema_Inc: sema_post");
}

void
ce_sema_Dec(ce_sema_t *sp)
{
    assert(sp) ;
  
    if (sema_wait(&sp->sema))
	ce_panic("ce_sema_Inc: sema_wait");
}

#endif /* Solaris version */

/**************************************************************/
/**************************************************************/
