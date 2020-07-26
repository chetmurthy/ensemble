/* 
 * Contents: Interface to pthreads.
 *
 * Author:  Alexey Vaysburd, December 1996
 * Bug fixes: Mark Hayden, 1997
 * Added support for native locks, semaphores: Mark Hayden, 1998
 */

#include <assert.h>
#include <pthread.h>
#include <unistd.h>
#include <time.h>
#include "hot_sys.h"
#include "hot_error.h"
#include "hot_thread.h"

#if 0
/* For use with Hans-Boehm garbage collector.
 */
#include "gc.h"
#define pthread_create GC_pthread_create
#define pthread_sigmask GC_pthread_sigmask
#define pthread_join GC_pthread_join
#endif

static pthread_t td;

typedef void*(*hot_thread_routine)(void*);


/**************************************************************/

/*#define ptrace(msg) do { fprintf(stderr, "PTHREAD:%lx:%s:%s\n", pthread_self(), __FUNCTION__, msg) } while(0) */
#define ptrace(msg) do {} while(0)

/******************************** Threads ***********************************/

/* Create a new thread
 */
hot_err_t hot_thread_Create(void (*routine)(void*), 
			    void *arg, 
			    hot_thread_attr_t *attr_arg) {
  pthread_attr_t attr;	
#ifndef OSF1_THREADS
  if (pthread_attr_init(&attr))
    return hot_err_Create(0,"hot_thread_Create: pthread_attr_init");

/* Linux threads currently do not support pthread_attr_setstacksize.
 */
#if !(defined(linux))
  if (attr_arg != NULL) {
    if (pthread_attr_setstacksize(&attr, attr_arg->stacksize))
      return hot_err_Create(0,"hot_thread_Create: pthread_attr_setstacksize");
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
    return hot_err_Create(0,"hot_thread_Create: pthread_attr_setdetachstate");
#endif

  if (pthread_create(&td, &attr, (hot_thread_routine) routine, arg))
    return hot_err_Create(0,"hot_thread_Create: pthread_create");
  pthread_attr_destroy(&attr);
#else /* OSF1_THREADS */
  /* BUG: the attributes below are a memory leak.
   * They also need to have the detached option set.
   */
  if (pthread_attr_create(&attr))
    return hot_err_Create(0,"hot_thread_Create: pthread_attr_create");
  if (pthread_create(&td,attr,(hot_thread_routine) routine, arg))
    return hot_err_Create(0,"hot_thread_Create: pthread_create");
#endif /*OSF1_THREADS*/
  return HOT_OK ;
}

/* Sleep for usecs.
 */
hot_err_t hot_thread_Usleep(int usecs) {
  struct timespec ts ;
  int ret ;
  int secs ;
  if (usecs <= 0)
    return HOT_OK ;

  secs = usecs / 1000000/*1E6*/ ;
  usecs %= 1000000/*1E6*/ ;
  
  ts.tv_sec = secs ;
  ts.tv_nsec = usecs * 1000 ;

  assert(ts.tv_nsec >= 0) ;
  assert(ts.tv_nsec < 1000000000/*1E9*/) ;
  assert(ts.tv_sec  >= 0) ;

  ret = nanosleep(&ts, NULL) ;
  if (ret < 0)
    return hot_err_Create(0,"hot_thread_Usleep: nanosleep") ;
  return HOT_OK ;
}

/* Yield the processor to another thread.
 * POSIX_PRIORITY_SCHEDULING tells us that sched_yield is available.  
 * Otherwise, we just call s
 */
hot_err_t hot_thread_Yield(void) {
  hot_err_t err ;
  ptrace("entering") ;
#ifdef _POSIX_PRIORITY_SCHEDULING
  sched_yield() ;
  err = HOT_OK ;
#else
  err = hot_thread_Usleep(1) ;
#endif
  ptrace("leaving") ;
  return err ;
}

/******************************** Semaphores *******************************/

#ifdef USE_PTHREAD_SEMAPHORE

#include <semaphore.h>

struct hot_sema {
  sem_t sema ;
};

/* Create a semaphore.
 */
static
hot_err_t hot_sema_Create_help(
        int initial_value,
	hot_sema_t sema	/*OUT*/
) {
  if (sem_init(&sema->sema,0,initial_value))
    return hot_err_Create(0,"hot_sema_Create: sema_init") ;
  return HOT_OK ;
}

hot_err_t hot_sema_Create(
        int initial_value,
	hot_sema_t *semap /*OUT*/ 
) {
  hot_sema_t sema ;
  hot_err_t err ;
  assert(semap) ;
  *semap = NULL ;

  sema = (hot_sema_t) malloc(sizeof(struct hot_sema)) ;
  if (!sema) 
    return hot_err_Create(0,"hot_sema_Create: malloc returned NULL");

  err = hot_sema_Create_help(initial_value, sema) ;
  if (err != HOT_OK)
    hot_sys_Panic(hot_err_ErrString(err)) ;

  *semap = sema ;
  return HOT_OK ;
}

hot_err_t hot_sema_Destroy(hot_sema_t sema) {
  assert(sema) ;

  if (sem_destroy(&sema->sema))
    return hot_err_Create(0,"hot_sema_Destroy");

  /* Zero the memory.
   */
  memset(sema,0,sizeof(*sema)) ;
  free(sema);
  return HOT_OK;
}

hot_err_t hot_sema_Inc(hot_sema_t sema) {
  assert(sema) ;
  ptrace("entering hot_sema_Inc");
  if (sem_post(&sema->sema)) {
    return hot_err_Create(0,"hot_sema_Inc: sem_post") ;
  }
  ptrace("leaving hot_sema_Inc");
  return HOT_OK;	
}

hot_err_t hot_sema_Dec(hot_sema_t sema) {
  assert(sema) ;
  ptrace("entering hot_sema_Dec");
  if (sem_wait(&sema->sema)) {
    return hot_err_Create(0,"hot_sema_Dec: sem_wait") ;
  }
  ptrace("leaving hot_sema_Dec");
  return HOT_OK;	
}

#else

struct hot_sema {
  pthread_mutex_t mutex;
  pthread_cond_t cond;
  int value ;
  int nwake ;
};

/* Create a semaphore.
 */
static
hot_err_t hot_sema_Create_help(
        int initial_value,
	hot_sema_t sema	/*OUT*/
) {

  /* Initialize mutex.
   */
  {
#ifndef OSF1_THREADS
    if (pthread_mutex_init(&sema->mutex, NULL))
      return hot_err_Create(0,"hot_sema_Create: pthread_mutex_init") ;
#else /*OSF1_THREADS*/
    pthread_mutexattr_t attr;
    if (pthread_mutexattr_create(&attr))
      return hot_err_Create(0,"hot_sema_Create: pthread_mutexattr_init");
    if (pthread_mutex_init(&sema->mutex, attr))
      return hot_err_Create(0,"hot_sema_Create: pthread_mutex_init") ;
#endif /*OSF1_THREADS*/
  }
  
  /* Initialize condition variable.
   */
  {
#ifndef OSF1_THREADS
    if (pthread_cond_init(&sema->cond, NULL))
      return hot_err_Create(0,"hot_sema_Create: pthread_cond_init");
#else /*OSF1_THREADS*/
    pthread_condattr_t attr;
    if (pthread_condattr_create(&attr))
      return hot_err_Create(0,"hot_sema_Create: pthread_condattr_init");
    if (pthread_cond_init(&sema->cond, attr))
      return hot_err_Create(0,"hot_sema_Create: pthread_cond_init");
#endif /*OSF1_THREADS*/
  }
  
  sema->value = initial_value;
  sema->nwake = 0 ;
  return HOT_OK;
}


hot_err_t hot_sema_Create(
        int initial_value,
	hot_sema_t *semap /*OUT*/ 
) {
  hot_sema_t sema ;
  hot_err_t err ;
  assert(semap) ;
  *semap = NULL ;

  sema = (hot_sema_t) malloc(sizeof(struct hot_sema)) ;
  if (!sema) 
    return hot_err_Create(0,"hot_sema_Create: malloc returned NULL");

  err = hot_sema_Create_help(initial_value, sema) ;
  if (err != HOT_OK)
    hot_sys_Panic(hot_err_ErrString(err)) ;

  *semap = sema ;
  return HOT_OK ;
}


hot_err_t hot_sema_Destroy(hot_sema_t sema) {
  assert(sema) ;

  if (pthread_mutex_destroy(&sema->mutex) ||
      pthread_cond_destroy(&sema->cond))
    return hot_err_Create(0,"hot_sema_Destroy");

  /* Zero the memory.
   */
  memset(sema,0,sizeof(*sema)) ;
  free(sema);
  return HOT_OK;
}

hot_err_t hot_sema_Inc(hot_sema_t sema) {
  int value ;
  assert(sema) ;
  ptrace("entering hot_sema_Inc");

  if (pthread_mutex_lock(&sema->mutex))
    return hot_err_Create(0,"hot_sema_Inc: pthread_mutex_lock") ;

  /* Save the semaphore value prior to incrementing it.
   */
  value = sema->value ;

  /* If the current value is less than 0 then increment
   * the count of the # threads to awaken.
   */
  if (sema->value < 0)
    sema->nwake++ ;

  sema->value ++ ;

  if (pthread_mutex_unlock(&sema->mutex))
    return hot_err_Create(0,"hot_sema_Inc: pthread_mutex_unlock") ;

  /* If the old value was less than zero then some thread is blocked,
   * so we signal it.  RvR suggested using broadcast instaed of 
   * signal.
   */
  if (value < 0) {
    if (pthread_cond_broadcast(&sema->cond))
      return hot_err_Create(0,"hot_sema_Inc: pthread_cond_signal");
  }

  ptrace("leaving hot_sema_Inc");
  return HOT_OK;	
}

hot_err_t hot_sema_Dec(hot_sema_t sema) {
  assert(sema) ;
  ptrace("entering hot_sema_Dec");

  if (pthread_mutex_lock(&sema->mutex))
    return hot_err_Create(0,"hot_sema_Dec: pthread_mutex_lock") ;

  sema->value -- ;

  /* If the semaphore's value is now negative then
   * block on the condition variable until the
   * value for nwake is greater than zero.
   */
  if (sema->value < 0) {
    /* Note that we do not check the nwake value on the
     * first pass because even if it is >0 there were
     * some other threads here first that should be woken
     * before this one.
     */
    do {
      /* It is a bug if we have to block on the condition
       * variable when value<0 and nwake==0.
       */
      assert(sema->value < 0) ;

      if (pthread_cond_wait(&sema->cond,&sema->mutex)) {
	/* Release the mutex before returning.
	 */
	if (pthread_mutex_unlock(&sema->mutex))
	  return hot_err_Create(0,"hot_sema_Dec: pthread_mutex_unlock(error)") ;
	return hot_err_Create(0,"hot_sema_Dec: pthread_cond_wait") ;
      }
    } while(sema->nwake == 0) ;

    /* Decrement the count for nwake.
     */
    assert(sema->nwake > 0) ;
    sema->nwake -- ;
  }
  
  if (pthread_mutex_unlock(&sema->mutex))
    return hot_err_Create(0,"hot_sema_Dec: pthread_mutex_unlock") ;
  ptrace("leaving hot_sema_Dec");
  
  return HOT_OK;
}

#endif

/******************************** Locks ***********************************/

#ifndef USE_PTHREAD_LOCK

struct hot_lock {
  struct hot_sema sema ;
} ;

/* Create a lock.
 */
hot_err_t hot_lck_Create(hot_lock_t *lockp) {
  hot_lock_t lock ;
  hot_err_t err ;
  assert(lockp) ;
  *lockp = NULL ;

  lock = (hot_lock_t) malloc(sizeof(*lock)) ;
  if (!lock) 
    return hot_err_Create(0,"hot_lock_Create: malloc returned NULL");

  err = hot_sema_Create_help(1, &lock->sema) ;
  if (err != HOT_OK)
    hot_sys_Panic(hot_err_ErrString(err)) ;

  *lockp = lock ;
  return HOT_OK ;
}

/* Destroy a lock
 */
hot_err_t hot_lck_Destroy(hot_lock_t l) {
  return hot_sema_Destroy(&l->sema) ;
}

/* Lock a lock
 */
hot_err_t hot_lck_Lock(hot_lock_t l) {
  return hot_sema_Dec(&l->sema) ;
}

/* Unlock a lock
 */
hot_err_t hot_lck_Unlock(hot_lock_t l) {
  return hot_sema_Inc(&l->sema) ;
}

#else

struct hot_lock {
  pthread_mutex_t mutex;
} ;

/* Create a lock.
 */
hot_err_t hot_lck_Create(hot_lock_t *lockp) {
  hot_lock_t lock ;
  lock = (hot_lock_t) malloc(sizeof(*lock)) ;
  if (!lock) 
    return hot_err_Create(0,"hot_lck_Create: malloc returned NULL");
  if (pthread_mutex_init(&lock->mutex, NULL))
      return hot_err_Create(0,"hot_lck_Create: pthread_mutex_init") ;
  *lockp = lock ;
  return HOT_OK ;
}

/* Destroy a lock
 */
hot_err_t hot_lck_Destroy(hot_lock_t l) {
  if (pthread_mutex_destroy(&l->mutex))
    return hot_err_Create(0,"hot_lck_Destroy: pthread_mutex_destroy");
  memset(l,0,sizeof(*l)) ;
  free(l) ;
  return HOT_OK ;
}

/* Lock a lock
 */
hot_err_t hot_lck_Lock(hot_lock_t l) {
  if (pthread_mutex_lock(&l->mutex))
    return hot_err_Create(0,"hot_lck_Lock: pthread_mutex_lock") ;
  return HOT_OK ;
}

/* Unlock a lock
 */
hot_err_t hot_lck_Unlock(hot_lock_t l) {
  if (pthread_mutex_unlock(&l->mutex))
    return hot_err_Create(0,"hot_lck_Unlock: pthread_mutex_unlock") ;
  return HOT_OK ;
}

#endif

/*****************************************************************************/

#if 0

struct hot_sema {
  int magic ;
} global_sema ;

struct hot_lock {
  int magic ;
} global_lock ;


hot_err_t hot_thread_Create(void (*routine)(void*), 
			    void *arg, 
			    hot_thread_attr_t *attr) { 
  (*routine)(arg);
  return HOT_OK;
}
hot_err_t hot_thread_Yield(void) { return HOT_OK; }
hot_err_t hot_thread_Usleep(int usecs) { return HOT_OK; }
hot_err_t hot_lck_Create(hot_lock_t *l) { 
  *l = &global_lock ;
  return HOT_OK; }
hot_err_t hot_lck_Destroy(hot_lock_t l) { return HOT_OK; }
hot_err_t hot_lck_Lock(hot_lock_t l) { return HOT_OK; }
hot_err_t hot_lck_Unlock(hot_lock_t l) { return HOT_OK; }
hot_err_t hot_sema_Create(int initial_value, /*OUT*/ hot_sema_t *semap) {
  *semap = &global_sema ;
  return HOT_OK;
}
hot_err_t hot_sema_Destroy(hot_sema_t sema) { return HOT_OK; }
hot_err_t hot_sema_Inc(hot_sema_t sema) { return HOT_OK; }
hot_err_t hot_sema_Dec(hot_sema_t sema) { return HOT_OK; }

#endif
