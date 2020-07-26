/**************************************************************/
/* CE_THREADS.H */
/* Author: Ohad Rodeh 03/2002 */
/* Based on code from HOT, written by Robbert Van Renesse, Werner Vogels,
 * Mark Hayden, and Alexery Vaysburd */
/**************************************************************/

#ifndef __CE_THREADS_H__
#define __CE_THREADS_H__

/* An opaque value, representing a semaphore.
 */
typedef struct ce_sema ce_sema_t;

/* Create a new thread.  
 */
void ce_thread_Create(void (*routine)(void*), void *arg, int stacksize);

/* Create a semaphore.  
 */
ce_sema_t *ce_sema_Create(int initial_value);

/* Destroy a semaphore.  
 */
void ce_sema_Destroy(ce_sema_t *sm);

/* Increase the value of a semaphore.  
 */
void hot_sema_Inc(ce_sema_t *sema);

/* Decrease the value of a semaphore (may block).  
 */
void ce_sema_Dec(ce_sema_t *sema);

#endif  /* __CE_THREADS_H__*/
