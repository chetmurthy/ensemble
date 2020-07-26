/**************************************************************/
/*
 *  Ensemble, (Version 0.70p1)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
/**************************************************************/
/* SPAWN.C */
/* Author: Robbert van Renesse, 5/96 */
/**************************************************************/
#include "skt.h"
/**************************************************************/

#ifdef HAS_SOCKETS

enum { E_WEXITED, E_WSIGNALED, E_WSTOPPED };

#ifdef _WINSOCKAPI_

#include <process.h>

/* This is a process descriptor that is passed to the threads that
 * wait for them.
 */
struct process_handle {
  PROCESS_INFORMATION pi ;
  ocaml_skt socket ;		/* (-1) means no socket */
};

/* This is an event that is written to the socket specified in the
 * process descriptor.  
 */
struct event {
  struct process_handle *pd;
};

#else /* !WINSOCK, i.e., UNIX */

#include <signal.h>

/* This is a process descriptor.
 */
struct process_handle {
  int pid ;
};

/* This is an event that is written to the socket.
 */
struct event {
  struct process_handle *pd ;
  int pid ;
  int status ;
};

#endif /* WINSOCK */

/* Read a process event of the given socket.
 * This code is shared.
 */
static void await_event(ocaml_skt skt, struct event *ev){
  int n, total = 0;
  
  while ((n = recv(skt, ((char *) ev) + total,
		   sizeof(*ev) - total, 0)) > 0) {
    total += n;
    if (total == sizeof(*ev))
      return;
  }
  serror("await_event", Nothing);
  exit(1);	
}

#ifdef _WINSOCKAPI_

/* This is the thread that actually spawns the process, waits for its
 * termination, and sends the message to the given socket.
 */
static DWORD skt_spawn_thread(LPDWORD p){
  struct process_handle *pd = (struct process_handle *) p;
  struct event ev;
  struct sockaddr skt_addr;
  int len, n;
  
  len = sizeof(skt_addr);
  (void) getsockname(pd->socket, &skt_addr, &len);
  ev.pd = pd;
  if (WaitForSingleObject(pd->pi.hProcess, INFINITE) !=
      WAIT_OBJECT_0) {
    printf("WaitForSingleObject failed!\n");
    exit(1);
  }
  n = sendto(pd->socket, (char *) &ev, sizeof(ev), 0, &skt_addr, len);
  if (n <= 0)
    printf("sendto --> %d %d\n", n, h_errno);
  ExitThread(0);
  return 0;
}

/* Make a command line out of the given arguments.
 */
static char *cmdline(value args){
  char *res, *p;
  int size, total = 0, i;
  
  size = Wosize_val(args);
  for (i = 0; i < size; i++)
    total += string_length(Field(args, i)) + 1;
  res = p = (char *) stat_alloc(total);
  for (i = 0; i < size; i++) {
    strcpy(p, String_val(Field(args, i)));
    p += string_length(Field(args, i));
    *p++ = ' ';
  }
  *--p = 0;
  return res;
}

/* Create a new process, and return a process handle.  When some
 * event happens to the process that should be notified (e.g.,
 * death), report it to the given socket.
 *
 * We create a thread that waits for termination of the process.  
 */
value skt_spawn_process(
	value cmd,
	value args,
	value skto_v
) {
  extern char *searchpath(char *) ;
  STARTUPINFO si ;
  char *exefile, *argv ;
  struct process_handle *pd ;
  DWORD tid ;
  int socket ;
  int detach ;
  value ret_v ;
  
  if (Is_block(skto_v)) {
    socket = Socket_val(Field(skto_v,0)) ;
    detach = 0 ;
  } else {
    socket = (-1) ;
    detach = DETACHED_PROCESS ;
  }
  
  exefile = searchpath(String_val(cmd));
  if (exefile == 0)
    exefile = String_val(cmd);
  argv = cmdline(args);
  GetStartupInfo(&si);
  pd = (struct process_handle *) stat_alloc(sizeof(*pd));
  if (!CreateProcess(exefile,	/* pointer to name of executable module */
		     argv,	/* pointer to command line string */
		     0,		/* pointer to process security attributes */
		     0,		/* pointer to thread security attributes */
		     TRUE,	/* handle inheritance flag */
		     detach,	/* creation flags */
		     0,		/* pointer to new environment block */
		     0,		/* pointer to current directory name */
		     &si,	/* pointer to STARTUPINFO */
		     &pd->pi	/* pointer to PROCESS_INFORMATION */
		     )) {
    _dosmaperr(GetLastError());
    serror("skt_spawn_process", exefile);
  }
  stat_free(argv);

  /* Only create the thread if we were passed a socket.
   */
  pd->socket = socket ;
  if (socket == -1) {
    return Val_int(0) ;		/* None */
  } else {
    CreateThread(0, 0, (LPTHREAD_START_ROUTINE) skt_spawn_thread,
		 (LPVOID) pd, 0, &tid);
    ret_v = alloc(1,0) ;	/* Some _ */
    Field(ret_v,0) = (value) pd;	
  }
}

/* Terminate the given process.
 */
value skt_terminate_process(value ph){
  struct process_handle *pd = (struct process_handle *) ph;
  
  TerminateProcess(pd->pi.hProcess, 0x10000009);
  return Val_unit;
}

/* Read a process termination event of the given socket and
 * return the process handle and the termination status.  After
 * this, the process handle is no longer valid.
 */
value skt_wait_process(value skt){
  struct event ev ;
  int status ;
  value result ;
  /*  value tmp_v ;*/
  CAMLparam0() ;
  CAMLlocal1(tmp_v) ;
  
  await_event(Int_val(skt), &ev);
  if (!GetExitCodeProcess(ev.pd->pi.hProcess, &status) ||
      status == STILL_ACTIVE) {
    printf("GetExitCode failed!\n");
    exit(1);
  }
  if ((status & 0xFFFF0000) == 0x10000000) {
    tmp_v = alloc(1, E_WSIGNALED);
    Field(tmp_v, 0) = Val_int(status & 0xFF);
  } else {
    tmp_v = alloc(1, E_WEXITED);
    Field(tmp_v, 0) = Val_int(status);
  }
  result = alloc_tuple(2);
  Field(result, 0) = (value) ev.pd;
  Field(result, 1) = tmp_v ;
  stat_free((char *) ev.pd);
  CAMLreturn(result) ;
}

#else /* !WINSOCK, i.e., UNIX */

/* The following bit is stolen from the Ocaml library.
 */

#include <sys/wait.h>

#if !(defined(WIFEXITED) && defined(WEXITSTATUS) && defined(WIFSTOPPED) && \
      defined(WSTOPSIG) && defined(WTERMSIG))
#define WIFEXITED(status) ((status) & 0xFF == 0)
#define WEXITSTATUS(status) (((status) >> 8) & 0xFF)
#define WIFSTOPPED(status) ((status) & 0xFF == 0xFF)
#define WSTOPSIG(status) (((status) >> 8) & 0xFF)
#define WTERMSIG(status) ((status) & 0x3F)
#endif

static value alloc_process_status(struct process_handle *pd, int status){
  CAMLparam0() ;
  CAMLlocal2(st, res) ;
  
  if (WIFEXITED(status)) {
    st = alloc(1, E_WEXITED);
    Field(st, 0) = Val_int(WEXITSTATUS(status));
    stat_free((char *) pd);
  } else if (WIFSTOPPED(status)) {
    st = alloc(1, E_WSTOPPED);
    Field(st, 0) = Val_int(WSTOPSIG(status));
  } else {
    st = alloc(1, E_WSIGNALED);
    Field(st, 0) = Val_int(WTERMSIG(status));
    stat_free((char *) pd);
  }
  res = alloc_tuple(2);
  Field(res, 0) = (value) pd;
  Field(res, 1) = st;
  CAMLreturn(res) ;
}

/* Send an event to the given socket.
 */
static void notify(ocaml_skt skt, struct event *ev){
  struct sockaddr skt_addr;
  int len;
  
  len = sizeof(skt_addr);
  (void) getsockname(skt, &skt_addr, &len);
  /*printf("sending %d bytes\n", sizeof(*ev));*/
  if (sendto(skt, (void*)ev, sizeof(*ev), 0, &skt_addr, len) != sizeof(*ev))
    perror("skt_spawn_process: notify: sendto");
}

extern char ** cstringvect();	/* From O'Caml Unix library */

/* Create a new process, and return a process handle.
 * When some event happens to the process that should be notified (e.g.,
 * death), report it to the given socket.
 *
 * We fork twice (nested).  The first process forked waits for the second,
 * and does the notification.
 */
value skt_spawn_process(
	value cmd,
	value args,
	value skto_v
) {
  extern char *searchpath(char *);
  char *exefile, **argv;
  struct process_handle *pd;
  int i ; 
  int pid ;			/* should be pid2 */
  int detach ;			/* am I detaching */
  int socket ;
  struct event ev ;
  int pid2 ;			/* should be pid1 */
  value ret_v ;

  if (Is_block(skto_v)) {
    detach = 0 ;
    socket = Int_val(Field(skto_v,0)) ;
  } else {
    detach = 1 ;
    socket = (-1) ;
  }

  exefile = String_val(cmd) ;
  pd = (struct process_handle *) stat_alloc(sizeof(*pd)) ;
  pd -> pid = 0 ;

  pid2 = fork() ;
  switch (pid2) {
  case -1:
    serror("skt_spawn_process", cmd);
    break ;
  case 0:
    pid = fork();
    switch (pid) {
    case -1:
      perror("skt_spawn_process: fork");
      if (!detach) {
	notify(socket, &ev);
      }
      exit(1);
    case 0:
      for (i = 3; i < 64; i++)	/* HACK */
	close(i);
      argv = cstringvect(args);
      execv(exefile, argv);
      perror(exefile);
      exit(1);
    default:
      if (detach) {
	/* If detaching, then exit now.
	 */
	exit(0) ;
      } else {
	/* Otherwise, send the info to my parent.
	 */
	ev.pd = pd;
	ev.pid = pid;
	notify(socket, &ev);

	/* Block waiting for my child to exit.
	 */
	if (wait(&ev.status) != pid)
	  perror("skt_spawn_process: wait") ;

	/* Now tell my parent the exit status of the child.
	 */
	notify(socket, &ev);
	exit(0);
      }
    }
    break ;
  default:
    if (detach) {
      /* Clean up the child.
       */
      if (wait(&ev.status) != pid2)
	perror("skt_spawn_process: wait[2]") ;

      /* Don't return any other info.
       */
      return Val_int(0) ;	/* None */
    } else {
      /* Get the pid of the grand-child from the child.
       */
      await_event(socket, &ev);

      /* Stash it.
       */
      pd->pid = ev.pid ;

      /* Alloc the option and return it.
       */
      ret_v = alloc(1,0) ;	/* Some _ */
      Field(ret_v,0) = (value) pd ;
      return ret_v ;
    }
    break ;
  }
  assert(0) ;
}

/* Terminate the given process.
 */
value skt_terminate_process(value ph){
  struct process_handle *pd = (struct process_handle *) ph;
  
  kill(pd->pid, SIGKILL);
  return Val_unit;
}

/* Read a process termination event of the given socket and
 * return the process handle and the termination status.  After
 * this, the process handle is no longer valid.
 */
value skt_wait_process(value skt){
  struct event ev;
  int dummy;
  
  await_event(Int_val(skt), &ev);
  /* The typecasts to void* are for
   * AIX.
   */
  while (wait3((void*)&dummy, WNOHANG, (void*)/*(struct rusage *)*/ NULL) > 0)
    /* clean up zombies */;
  return alloc_process_status(ev.pd, ev.status);
}

#endif /* WINSOCK */

#else /* !HAS_SOCKETS */

value skt_spawn_process(value cmd, value cmdline, value skt){
  failwith("skt_spawn_process: not available");
}

value skt_terminate_process(value ph){
  failwith("skt_terminate_process: not available");
}

value skt_wait_process(value skt){
  failwith("skt_terminate_process: not available");
}

#endif /* HAS_SOCKETS */

