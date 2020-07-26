/*
 * Author:	Robbert van Renesse, Cornell University
 *
 * Include file to the thread package.
 */

#ifndef __RVR_THR_TYPES_H__
#define __RVR_THR_TYPES_H__

#define RVR_THR_STD_PRIO 128

#ifdef MUTS_DEBUG
#define THREAD_DEBUG
#endif

#ifdef HPRT
#undef  cv_t
#define cv_t      hprt_cv_t
#include <machine/syscall.h>
#else
#include <sys/syscall.h>
#endif
#include <sys/time.h>
#include <setjmp.h>
#include <limits.h>

#ifdef HPRT
#undef cv_signal
#undef cv_broadcast
#undef cv_create
#undef cv_wait
#undef cv_t
#endif /* HPRT */

/* Options to various calls and process state flags.
 */
#define T_BLOCK		0x1	/* block for input */
#define T_HIGHER	0x2	/* yield to higher priority threads only */
#define T_CANCELED	0x4	/* thread is canceled */
#define T_SLICED	0x8	/* interval timer expired */
#define T_TIMED_OUT	0x10	/* timed out on cond var */

/* Extra option to open().  This option allows read()s to be intercepted.
 */
#define O_INTERCEPT	0x100000

/* These types are defined later, but are referenced before there definition.
 */
typedef struct stackpool *stackpool_id;
typedef struct rvr_thread *thread_id;
typedef struct monitor *mon_id;
typedef struct condvar *cv_id;
typedef struct sync_pair *sp_id;

/* A monitor variable.
 */
struct monitor {
#ifdef THREAD_DEBUG
	mon_id next, *back;		/* doubly linked list pointers */
	cv_id cv_list;			/* list of condition variables */
#endif
	char *name;			/* name of this monitor */
	thread_id occupant;		/* thread in here */
	thread_id waiting;		/* wait list */
	int level;			/* # times entered */
};
typedef struct monitor mon_t;

/* A condition variable.
 */
struct condvar {
#ifdef THREAD_DEBUG
	cv_id next, *back;		/* doubly linked list pointers */
#endif
	char *name;			/* name of this condition variable */
	mon_id mon;			/* corresponding monitor */
	thread_id waiting;		/* wait list */
	int value;			/* for event count operations */
};
typedef struct condvar cv_t;

/* This is a convenient data type that contains both a monitor and an
 * associated condition variable.
 */
struct sync_pair {
	mon_t mon;
	cv_t cv;
};
typedef struct sync_pair sp_t;

/* Stacks are organized in pools.  Each pool contains a linked list of
 * free threads with the required stack size.
 *
 * TODO.  A periodic thread should deallocate old threads.
 */
struct stackpool {
	int stack_size;			/* size of stack */
	thread_id free_list;		/* free list */
};

/* Threads are nodes in linked lists.  The lists are sorted to priority
 * (highest priority first).  Each entry in the list contains a pointer
 * to the next entry.  The first entry of a sublist of entries of the
 * same priority also has a pointer to the last entry of that priority.
 */
struct rvr_thread {
	thread_id next, last;		/* linked list pointers */
	thread_id tt_next, tt_last;	/* time table tree pointers/RFHH */
	stackpool_id stackpool;		/* where my stack came from */
	void (*pc)(void *, void *);	/* initial program counter */
	void *env, *param;		/* arguments to thread */
	void *ident;			/* identifier for any purposes */
	char *stack;			/* points to stack buffer */
	int priority;			/* priority of thread */
	jmp_buf jb;			/* to save and restore CPU state */
	int level;			/* saved when waiting in monitor */
	cv_t cv;			/* for blocking on UNIX files */
	cv_id timer_cv;			/* queue when timed out in wait/RFHH */
	struct itimerval itimer;	/* specifies when to run this thread */
	unsigned int flags;		/* state flags */
	void *context;			/* per thread global context */
	int gdb_lst_entry;		/* pointer to "gdb" list entry/RFHH */
};

/* This is for getting and setting the global pointer.
 */
extern thread_id t_current;
#define ctx_getptr()	(t_current->context)
#define ctx_setptr(p)	do t_current->context = (p); while (0)

/* Check whether a monitor is free.
 */
#define mon_free(m)	((m)->level == 0)

/* Try to enter a monitor.  If the level is set to zero, this is no problem.
 * If anybody is in the monitor, call mon_suspend to see what needs to happen.
 */
#define mon_enter(m)	do \
				if (mon_free((m))) { \
					(m)->level++; \
					(m)->occupant = t_current; \
				} \
				else \
					mon_suspend((m)); \
			while (0)

/* Leave the monitor.  If the level becomes zero, we have to check the
 * waiting list to see if we need to make another thread runnable, and
 * perhaps reschedule.
 */
#define mon_exit(m)	do \
				if (--(m)->level == 0 && (m)->waiting != 0) \
					mon_resume((m)); \
			while (0)

/* Release the given monitor.
 */
#ifndef THREAD_DEBUG
#define mon_release(m)	/* Currently there is nothing to be done */
#endif

/* Wake up at most one waiting thread.
 */
#define cv_signal(cv)	do \
				if ((cv)->waiting != 0) \
					cv_do_signal((cv)); \
			while (0)

/* Wake up all waiting threads.
 */
#define cv_broadcast(cv) do \
				while ((cv)->waiting != 0) \
					cv_do_signal((cv)); \
			 while (0)

/* Wait until event count reaches a certain value.
 */
#define cv_sync(cv,v)	do \
				while ((cv)->value != (v)) \
					cv_wait((cv)); \
			while (0)

/* Increment the event count.
 */
#define cv_inc(cv)	do { \
				(cv)->value++; \
				cv_broadcast((cv)); \
			} while (0)

/* Sync_pair equivalents.
 */
#define sp_mon(sp)		(&(sp)->mon)
#define sp_cv(sp)		(&(sp)->cv)
#define sp_enter(sp)		mon_enter(&(sp)->mon)
#define sp_exit(sp)		mon_exit(&(sp)->mon)
#define sp_wait(sp)		cv_wait(&(sp)->cv)
#define sp_signal(sp)		cv_signal(&(sp)->cv)
#define sp_broadcast(sp)	cv_broadcast(&(sp)->cv)
#define sp_sync(sp,v)		cv_sync(&(sp)->cv, (v))
#define sp_inc(sp)		cv_inc(&(sp)->cv)

/* Specify when this thread may be ``sliced''.
 */
#define t_slice()	do \
				if (t_current->flags & T_SLICED) \
					t_yield(T_SLICED); \
			while (0)

stackpool_id t_stackpool(int stack_size);
void t_clear_stackpool(stackpool_id pool);
void t_yield(unsigned int options);
void mon_suspend(mon_id mon);
int mon_try_enter(mon_id m);
void mon_resume(mon_id mon);
void mon_create(char *name, mon_id mon);
void cv_create(char *name, mon_id mon, cv_id cv);
void cv_wait(cv_id cv);
int cv_timed_wait(cv_id cv, struct timeval *timeout);
void cv_do_signal(cv_id cv);
void cv_release(cv_id cv);
thread_id t_start(
	stackpool_id stackpool,
	void (*pc)(void *, void *),
	void *env, void *param,
	void *ident,
	int priority,
	struct itimerval *it
);
void t_cancel(thread_id t);
int t_canceled(void);
void t_set_priority(int priority);
int t_get_priority(void);
#define t_min_prio()	0	/* int t_min_prio(void)	*/
#define t_max_prio()	INT_MAX	/* int t_max_prio(void)	*/
#define t_ident()		(t_current->ident)
void pre_enter(void);
void pre_exit(void);
void t_first_thread(void *ident, int priority);
void t_clear_up();
void t_sleep(struct timeval *timeout);
void t_reschedule(void);

/* These definitions deal with different definitions of syscall arguments.
 */

#ifdef SYS_ACCEPT
#ifndef SYS_accept
#define SYS_accept SYS_ACCEPT
#endif
#endif

#ifdef SYS_BIND
#ifndef SYS_bind
#define SYS_bind SYS_BIND
#endif
#endif

#ifdef SYS_CLOSE
#ifndef SYS_close
#define SYS_close SYS_CLOSE
#endif
#endif

#ifdef SYS_CONNECT
#ifndef SYS_connect
#define SYS_connect SYS_CONNECT
#endif
#endif

#ifdef SYS_GETPEERNAME
#ifndef SYS_getpeername
#define SYS_getpeername SYS_GETPEERNAME
#endif
#endif

#ifdef SYS_GETSOCKNAME
#ifndef SYS_getsockname
#define SYS_getsockname SYS_GETSOCKNAME
#endif
#endif

#ifdef SYS_IOCTL
#ifndef SYS_ioctl
#define SYS_ioctl SYS_IOCTL
#endif
#endif

#ifdef SYS_OPEN
#ifndef SYS_open
#define SYS_open SYS_OPEN
#endif
#endif

#ifdef SYS_READ
#ifndef SYS_read
#define SYS_read SYS_READ
#endif
#endif

#ifdef SYS_RECV
#ifndef SYS_recv
#define SYS_recv SYS_RECV
#endif
#endif

#ifdef SYS_RECVFROM
#ifndef SYS_recvfrom
#define SYS_recvfrom SYS_RECVFROM
#endif
#endif

#ifdef SYS_SELECT
#ifndef SYS_select
#define SYS_select SYS_SELECT
#endif
#endif

#ifdef SYS_SEND
#ifndef SYS_send
#define SYS_send SYS_SEND
#endif
#endif

#ifdef SYS_SENDTO
#ifndef SYS_sendto
#define SYS_sendto SYS_SENDTO
#endif
#endif

#ifdef SYS_SOCKET
#ifndef SYS_socket
#define SYS_socket SYS_SOCKET
#endif
#endif

#ifdef SYS_WAIT3
#ifndef SYS_wait3
#define SYS_wait3 SYS_WAIT3
#endif
#endif

#ifdef SYS_WAIT4
#ifndef SYS_wait4
#define SYS_wait4 SYS_WAIT4
#endif
#endif

#ifdef SYS_WRITE
#ifndef SYS_write
#define SYS_write SYS_WRITE
#endif
#endif

#endif /* __RVR_THR_TYPES_H__ */
