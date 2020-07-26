/**************************************************************/
/* CE_THREADS.H */
/* Author: Ohad Rodeh 03/2002 */
/* Based on code from HOT, written by Robbert Van Renesse, Werner Vogels,
 * Mark Hayden, and Alexery Vaysburd */
/**************************************************************/

#ifndef __CE_THREADS_H__
#define __CE_THREADS_H__
#include "ce_so.h"

/* An opaque value, representing a semaphore.
 */
typedef struct ce_sema ce_sema_t;

/* An opaque value, representing a lock.
 */
typedef struct ce_lck ce_lck_t;

/* Create a new thread.  
 */
LINKDLL void ce_thread_Create(void (*routine)(void*), void *arg, int stacksize);

/* Create a semaphore.  
 */
LINKDLL ce_sema_t *ce_sema_Create(int initial_value);

/* Destroy a semaphore.  
 */
LINKDLL void ce_sema_Destroy(ce_sema_t *sm);

/* Increase the value of a semaphore.  
 */
LINKDLL void ce_sema_Inc(ce_sema_t *sema);

/* Decrease the value of a semaphore (may block).  
 */
LINKDLL void ce_sema_Dec(ce_sema_t *sema);


/* Create a lock
 */
LINKDLL ce_lck_t *ce_lck_Create(void);

/* Destroy a lock
 */
LINKDLL void ce_lck_Destroy(ce_lck_t *lck);

/* Lock a lock
 */
LINKDLL void ce_lck_Lock(ce_lck_t *lck);

/* Unlock a lock
 */
LINKDLL void ce_lck_Unlock(ce_lck_t *lck);


#endif  /* __CE_THREADS_H__*/
