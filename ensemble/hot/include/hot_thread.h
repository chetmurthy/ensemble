/**************************************************************/
/*
 *  Ensemble, (Version 0.70p1)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
/* Interface to system/machine-dependent threads implementation.
 */

#ifndef __HOT_THREAD_H__
#define __HOT_THREAD_H__

/* Define if we are going to need threads.
 */
#define HOT_USE_THREADS

/******************************** Threads ***********************************/

typedef struct {
  int stacksize;
} hot_thread_attr_t;

/* Create a new thread.  Returns 0 if OK.
 */
hot_err_t hot_thread_Create(void (*routine)(void*), 
			    void *arg,
			    hot_thread_attr_t *attr);

/* Yield to other runnable threads (if any).
 */
hot_err_t hot_thread_Yield(void);

/* Sleep for usecs.
 */
hot_err_t hot_thread_Usleep(int usecs);

/******************************** Locks ***********************************/

/* Obscured type
 */
typedef struct hot_lock* hot_lock_t;

/* Create a new lock.  Returns 0 if OK.
 */
hot_err_t hot_lck_Create(/*OUT*/hot_lock_t*);

/* Destroy a lock.  Returns 0 if OK.
 */
hot_err_t hot_lck_Destroy(hot_lock_t);

/* Locks/unlocks a lock.  Returns 0 if OK.
 */
hot_err_t hot_lck_Lock(hot_lock_t);
hot_err_t hot_lck_Unlock(hot_lock_t);

/******************************* Semaphores *********************************/

/* Obscured type
 */
typedef struct hot_sema* hot_sema_t;

/* Create a semaphore.  Returns 0 if OK.
 */
hot_err_t hot_sema_Create(int initial_value, /*OUT*/ hot_sema_t *semap);

/* Destroy a semaphore.  Returns 0 if OK.
 */
hot_err_t hot_sema_Destroy(hot_sema_t sema);

/* Increase the value of a semaphore.  Returns 0 if OK.
 */
hot_err_t hot_sema_Inc(hot_sema_t sema);

/* Decrease the value of a semapghore (may block).  Returns 0 if OK.
 */
hot_err_t hot_sema_Dec(hot_sema_t sema);


/******************* Typedefs for a thread-wrapper configuration ************/

typedef hot_err_t (*hot_thread_Create_f)(void (*routine)(void*), 
					 void *arg, hot_thread_attr_t *attr);
typedef hot_err_t (*hot_thread_Yield_f)(void);
typedef hot_err_t (*hot_thread_Usleep_f)(int usecs);
typedef hot_err_t (*hot_lck_Create_f)(/*OUT*/hot_lock_t*);
typedef hot_err_t (*hot_lck_Destroy_f)(hot_lock_t);
typedef hot_err_t (*hot_lck_Lock_f)(hot_lock_t);
typedef hot_err_t (*hot_lck_Unlock_f)(hot_lock_t);
typedef hot_err_t (*hot_sema_Create_f)(int initial_value, 
				     /*OUT*/ hot_sema_t *semap);
typedef hot_err_t (*hot_sema_Destroy_f)(hot_sema_t sema);
typedef hot_err_t (*hot_sema_Inc_f)(hot_sema_t sema);
typedef hot_err_t (*hot_sema_Dec_f)(hot_sema_t sema);
  
typedef struct {
  hot_thread_Create_f thread_create;
  hot_thread_Yield_f thread_yield ;
  hot_thread_Usleep_f thread_usleep ;
  hot_lck_Create_f lck_create;
  hot_lck_Destroy_f lck_destroy;
  hot_lck_Lock_f lck_lock;
  hot_lck_Unlock_f lck_unlock;
  hot_sema_Create_f sema_create;
  hot_sema_Destroy_f sema_destroy;
  hot_sema_Inc_f sema_inc;
  hot_sema_Dec_f sema_dec;
} hot_thread_conf_t;
  

#endif /* __HOT_THREAD_H__ */
