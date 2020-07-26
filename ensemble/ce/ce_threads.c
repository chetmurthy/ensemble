/**************************************************************/
/* CE_THREADS.C */
/* Author: Ohad Rodeh 03/2002 */
/* Based on code from HOT, written by Robbert Van Renesse, Werner Vogels,
 * Mark Hayden, and Alexery Vaysburd */
/**************************************************************/
#include <stdio.h>
#include "ce_threads.h"
#include "ce_internal.h"
/**************************************************************/
#define NAME "CE_THREADS"
/**************************************************************/

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

/* Create a new thread.  
 */
void
ce_thread_Create(void (*routine)(void*), void *arg, int stacksize)
{
    DWORD   dwThreadID, dwStackSize = 0;
    
    if (CreateThread(NULL, stacksize, (LPTHREAD_START_ROUTINE)routine, arg, 0, &dwThreadID) == NULL)
	ce_panic("hot_thread_Create: t_create");
}

/* Create a semaphore.  
 */
ce_sema_t *
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
void
ce_sema_Destroy(ce_sema_t *sp)
{
    CloseHandle(sp->sema);
    free(sp);
}

/* Increase the value of a semaphore.  
 */
void
ce_sema_Inc(ce_sema_t *sp)
{
    assert(sp != NULL);
    ReleaseSemaphore(sp->sema, 1, NULL);
}

/* Decrease the value of a semaphore (may block).  
 */
void
ce_sema_Dec(ce_sema_t *sp)
{
    WaitForSingleObject(sp->sema, INFINITE);
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
    if (sem_post(&sp->sema))
	ce_panic("hot_sema_Inc: sem_post") ;
}

void
ce_sema_Dec(ce_sema_t *sp) {
    assert(sp) ;
    if (sem_wait(&sp->sema))
	ce_panic("ce_sema_Dec: sem_wait") ;
}

#endif

/**************************************************************/
/**************************************************************/

