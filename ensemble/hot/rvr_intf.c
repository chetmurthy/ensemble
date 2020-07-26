/* HOT stub to rvr threads.  
 *
 * Based on MUTS code by Robbert van Renesse.
 */

#include "hot_sys.h"
#include "hot_error.h"
#include "hot_thread.h"
#include "rvr_thread.h"

#ifdef HOT_USE_THREADS

#define RVR_THREAD_INTF_LOCK_MAGIC 386094304
#define RVR_THREAD_INTF_SEMA_MAGIC 238765083

static init;

static void do_init() {
    init = 1;
    t_first_thread(0, RVR_THR_STD_PRIO);
}

typedef void*(*thread_routine)(void*);

static void thread_fun(void *env, void *param) {
    thread_routine fun = (thread_routine) env;
    (void) (*fun)(param);
}

/* Create a new thread. 
 */
hot_err_t hot_thread_Create(void (*routine)(void*), void *arg, 
		      hot_thread_attr_t *attr) {
    if (!init)
	do_init();

    t_start(0, thread_fun, routine, arg, 0, RVR_THR_STD_PRIO, 0);
    return HOT_OK;
}

/* Yield to other runnable threads (if any).
 */
hot_err_t hot_thread_Yield(void) {
  t_yield(0);
  return HOT_OK;
}

/* Sleep for usecs.
 *
 * TODO:  Eliminate this.
 */
hot_err_t hot_thread_Usleep(int usecs) {
    usleep(usecs);
    return HOT_OK;
}

/******************************** Locks ***********************************/

struct hot_lock {
    int magic;
    mon_t mon;
};

/* Create a new lock.  Returns 0 if OK.
 */
hot_err_t hot_lck_Create(/*OUT*/hot_lock_t *lp) {
    hot_lock_t l;

    if (!init)
	do_init();
    if ((l = (hot_lock_t) malloc(sizeof(struct hot_lock)))== NULL)
	return hot_err_Create(0, "hot_lck_Create:  malloc failed");

    mon_create(0, &l->mon);
    l->magic = RVR_THREAD_INTF_LOCK_MAGIC;
    *lp = l;
    return HOT_OK;
}

/* Destroy a lock.  Returns 0 if OK.
 */
hot_err_t hot_lck_Destroy(hot_lock_t l) {
    if (l == NULL || l->magic != RVR_THREAD_INTF_LOCK_MAGIC)
	return hot_err_Create(0, "hot_lck_Destroy: bad handle");

    mon_release(&l->mon);
    l->magic = 0;
    free(l);
    return HOT_OK;
}

/* Locks/unlocks a lock.  Returns 0 if OK.
 */
hot_err_t hot_lck_Lock(hot_lock_t l) {
    if (l == NULL || l->magic != RVR_THREAD_INTF_LOCK_MAGIC)
	return hot_err_Create(0, "hot_lck_Lock: bad handle");
    mon_enter(&l->mon);
    return HOT_OK;
}

hot_err_t hot_lck_Unlock(hot_lock_t l) {
    if (l == NULL || l->magic != RVR_THREAD_INTF_LOCK_MAGIC)
	return hot_err_Create(0, "hot_lck_Unlock: bad handle");
    mon_exit(&l->mon);
    return HOT_OK;
}

/******************************* Semaphores *********************************/

struct hot_sema {
    int magic;
    mon_t mon;
    cv_t cv;
    int value;
};

/* Create a semaphore.  Returns 0 if OK.
 */
hot_err_t hot_sema_Create(int initial_value, /*OUT*/ hot_sema_t *sp) {
    hot_sema_t s;

    if (!init)
	do_init();
    if ((s = (hot_sema_t) malloc(sizeof(struct hot_sema))) == NULL)
	return hot_err_Create(0, "hot_sema_Create: malloc failed");

    s->value = initial_value;
    mon_create(0, &s->mon);
    cv_create(0, &s->mon, &s->cv);
    s->magic = RVR_THREAD_INTF_SEMA_MAGIC;
    *sp = s;
    return HOT_OK;
}

/* Destroy a semaphore.  Returns 0 if OK.
 */
hot_err_t hot_sema_Destroy(hot_sema_t sema) {
    if (sema == NULL || sema->magic != RVR_THREAD_INTF_SEMA_MAGIC)
	return hot_err_Create(0, "hot_sema_Destroy: bad handle");

    cv_release(&sema->cv);
    mon_release(&sema->mon);
    sema->magic = 0;

    free(sema);
    return HOT_OK;
}

/* Increase the value of a semaphore.  Returns 0 if OK.
 */
hot_err_t hot_sema_Inc(hot_sema_t sema) {
    if (sema == NULL || sema->magic != RVR_THREAD_INTF_SEMA_MAGIC)
	return hot_err_Create(0, "hot_sema_Inc: bad handle");

    mon_enter(&sema->mon);
    if (sema->value++ < 0)
	cv_signal(&sema->cv);
    mon_exit(&sema->mon);

    return HOT_OK;
}

/* Decrease the value of a semaphore (may block).  Returns 0 if OK.
 */
hot_err_t hot_sema_Dec(hot_sema_t sema) {
    if (sema == NULL || sema->magic != RVR_THREAD_INTF_SEMA_MAGIC)
	return hot_err_Create(0, "hot_sema_Dec: bad handle");

    mon_enter(&sema->mon);
    if (--sema->value < 0)
	cv_wait(&sema->cv);
    mon_exit(&sema->mon);
    
    return HOT_OK;
}

/**************************** sleep/usleep ***********************************/

/* Don't define these when compiling with Horus.
 */
#if 0

/* Wake up the sleeping thread.
 */
static void sleep_wakeup(void *env, void *param){
    hot_sema_Inc(env);
}

/* Sleep for the specified # seconds.
 */
int sleep(unsigned int secs){
	hot_sema_t sema;
	struct itimerval delta;

	if (!init)
	    do_init();

	hot_sema_Create(0, &sema);
	bzero((void*) &delta, sizeof(delta));
	gettimeofday(&delta.it_value, 0);
	delta.it_value.tv_sec += secs;
	t_start(0, sleep_wakeup, sema, 0, "sleep_wakeup", 
		RVR_THR_STD_PRIO, &delta);
	hot_sema_Dec(sema);
	hot_sema_Destroy(sema);

	return 0;
}

/* Sleep for the specified # microseconds.
 */
int usleep(unsigned int usecs){
	hot_sema_t sema;
	struct itimerval delta;

	if (!init)
	    do_init();

	hot_sema_Create(0, &sema);
	bzero((void*) &delta, sizeof(delta));
	gettimeofday(&delta.it_value, 0);
	delta.it_value.tv_usec += usecs;
	delta.it_value.tv_sec += delta.it_value.tv_usec / 1000000;
	delta.it_value.tv_usec %= 1000000;
	t_start(0, sleep_wakeup, sema, 0, "sleep_wakeup", 
		RVR_THR_STD_PRIO, &delta);
	hot_sema_Dec(sema);
	hot_sema_Destroy(sema);

	return 0;
}
#endif

#else /* HOT_USE_THREADS */

hot_err_t hot_thread_Create(void (*routine)(void*), 
			    void *arg, 
			    hot_thread_attr_t *attr) { 
  (*routine)(arg);
  return HOT_OK;
}
hot_err_t hot_thread_Yield(void) { return HOT_OK; }
hot_err_t hot_thread_Usleep(int usecs) { usleep(usecs); return HOT_OK; }
hot_err_t hot_lck_Create(hot_lock_t *l) { return HOT_OK; }
hot_err_t hot_lck_Destroy(hot_lock_t l) { return HOT_OK; }
hot_err_t hot_lck_Lock(hot_lock_t l) { return HOT_OK; }
hot_err_t hot_lck_Unlock(hot_lock_t l) { return HOT_OK; }
hot_err_t hot_sema_Create(int initial_value, /*OUT*/ hot_sema_t *semap) {
    return HOT_OK;
}
hot_err_t hot_sema_Destroy(hot_sema_t sema) { return HOT_OK; }
hot_err_t hot_sema_Inc(hot_sema_t sema) { return HOT_OK; }
hot_err_t hot_sema_Dec(hot_sema_t sema) { return HOT_OK; }

#endif /* HOT_USE_THREADS */
