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
/* ENS_THREADS.H */
/* Author: Ohad Rodeh 03/2003 */
/* Based on code from HOT, written by Robbert Van Renesse, Werner Vogels,
 * Mark Hayden, and Alexery Vaysburd */
/**************************************************************/

#ifndef __ENS_THREADS_H__
#define __ENS_THREADS_H__

#ifdef __cplusplus
extern "C" {
#endif

/* An opaque type representing a lock.
 */
typedef struct ens_lock_t ens_lock_t;

/* Create a new thread.  
 */
void EnsThreadCreate(void (*routine)(void*), void *arg);

/* Create a lock
 */
ens_lock_t *EnsLockCreate(void);

/* Destroy a lock, and release its memory.
 */
void EnsLockDestroy(ens_lock_t *lock);

/* Take a lock
 */
void EnsLockTake(ens_lock_t *lock);

/* Release a lock
 */
void EnsLockRelease(ens_lock_t *lock);

#ifdef __cplusplus
}
#endif

#endif  /* __ENS_THREADS_H__*/
