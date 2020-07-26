/**************************************************************/
/*
 *  Ensemble, 1_42
 *  Copyright 2003 Cornell University, Hebrew University
 *           IBM Israel Science and Technology
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
/**************************************************************/
/* 
 * Test of Ensemble with the HOT C interface.
 *
 * Author:  Alexey Vaysburd, Dec. 96.
 *
 * NB: Access to the global struct is not protected with a mutex
 * (that could cause a deadlock). 
 *
 * State transitions (triggered by callbacks and downcalls; starting state
 * is BOGUS):
 *
 * View callback:  BOGUS --> RUNNING, BLOCKED --> RUNNING 
 * Block callback: RUNNING --> BLOCKED
 * Leave downcall: RUNNING --> LEAVING, BLOCKED --> LEAVING
 * Exit callback: LEAVING --> BOGUS
 *
 * No other state transitions are allowed.
 */

#ifdef _WIN32
#include <windows.h>
#endif

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <time.h>
#include "hot_sys.h"
#include "hot_error.h"
#include "hot_msg.h"
#include "hot_ens.h"
#include "hot_thread.h"
#include "hot_mem.h"
/*#include "purify.h"*/

#define HOT_TEST_MAGIC 234324

int nmembers = 5;

static hot_mem_t memory;

typedef struct {
  int magic ;
  hot_gctx_t gctx;
  unsigned seqno;
  enum { BOGUS, RUNNING, BLOCKED, LEAVING } status;
  unsigned int first_beat;
  hot_view_state_t vs;
  hot_ens_JoinOps_t jops;
  int got_view;
} state ;

/********************** Actions *******************************************/
/* Lifted from hot_inboard_c.c
 */
#ifdef INLINE_PRAGMA
#pragma inline begin_critical
#endif 
MSG_INLINE
static void trace(const char *s, ...) {
#if 0
  va_list args;
  static int debugging = -1 ;

  va_start(args, s);

  if (debugging == -1) {
      debugging = (getenv("ENS_HOT_TRACE") != NULL) ;
  }
  
  if (!debugging) return ;

  fprintf(stderr, "HOT_SEC_TEST:");
  vfprintf(stderr, s, args);
  fprintf(stderr, "\n");
  va_end(args);
#endif
}

/********************** Actions *******************************************/
/* Request a view change.
 */
static void action_rekey(state *s) {
  hot_err_t err;

  assert(s->status == RUNNING);
  
  /* View-change request will be ignored if our rank is not 0.
   */
  if (s->vs.rank == 0) {
    printf("action: rekey\n"); fflush(stdout);
    err = hot_ens_Rekey(s->gctx);
    if (err != HOT_OK)
      hot_sys_Panic(hot_err_ErrString(err));
  }
}

/********************** Callbacks *****************************************/

static void receive_cast(
        hot_gctx_t gctx,
	void *env,
	hot_endpt_t *origin, 
	hot_msg_t msg
) {
  state *s = (state*) env ;

  printf ("cast: from %s\n", origin->name);
}

static void receive_send(
        hot_gctx_t gctx,
	void *env,
	hot_endpt_t *origin,
	hot_msg_t msg
) {
  state *s = (state*) env ;
  printf ("send: from %s", origin->name);
}

/* We have accepted a new view.  The new view state is specified.
 */
static void install_view(
        hot_gctx_t gctx,
	void *env,
	hot_view_state_t *view_state
) {
  state *s = (state*) env ;
  int size ;

  if (s->status == BLOCKED || (s->status == BOGUS && !s->got_view)) {
      s->status = RUNNING;
      s->got_view = 1;
  }

  /* Release the old view.
   */
  if (s->vs.members != NULL) {
    hot_mem_Free(s->vs.members) ;
  }
  s->vs = *view_state; 
  size = sizeof(s->vs.members[0])*s->vs.nmembers ;
  s->vs.members = (hot_endpt_t*) hot_mem_Alloc(memory, size) ;
  memcpy(s->vs.members,view_state->members,size) ;

  if (s->vs.rank == 0)
      printf("HOT_TEST:view: nmembers=%d, rank=%d\n", 
	    s->vs.nmembers, s->vs.rank);

  s->first_beat=2;

#if 0
  {
      int i ;
      printf("\tview_id = (%d,%s)", view_state->view_id.ltime,
	     view_state->view_id.coord.name);
      printf("\tversion = \"%s\"\n", view_state->version);
      printf("\tgroup_name = \"%s\"\n", view_state->group_name);
      printf("\tprotocol = \"%s\"\n", view_state->protocol);
      printf("\tmy_rank = %d\n", 	view_state->my_rank);
      printf("\tgroup daemon is %s\n", view_state->groupd ? "in use" : "not in use");
      printf("\tparameters = \"%s\"\n", view_state->params);
      printf("\txfer_view = %d\n", view_state->xfer_view);
      printf("\tprimary = %d\n", view_state->primary);
      for (i = 0; i < view_state->nmembers; i++)
	  printf("%s\n", view_state->members[i].name);
  }
#endif
  {
    int i;

    printf ("\t key=");
    for(i=0; i< HOT_ENS_MAX_KEY_LEGNTH/2; i++) {
      printf ("%X",(unsigned char) view_state->key[i]);
    }
    printf("\n");
  }
}

/* A periodic heartbeat event has occurred.  The 'time' argument 
 * is an approximation of the current time.
 */
static void heartbeat(
        hot_gctx_t gctx,
	void *env,
	unsigned time
) {
    state *s = (state*) env ;

    if (s->status != RUNNING)
        return;
    
    if (s->first_beat> 0
	&& s->vs.nmembers == nmembers
	) {
      s->first_beat--;
      if (s->first_beat == 0) action_rekey(s);
    }
}

static void exit_cb(
        hot_gctx_t gctx,
        void *env
) {
  printf ("exit");
}

static void block(
        hot_gctx_t gctx,
	void *env
) {
  state *s = (state*) env ;
  printf ("block\n");
  if (s->status == RUNNING)
    s->status = BLOCKED;
}

static void join(
		 int i,
		 char **argv
) {
  hot_err_t err ;
  state *s ;
  const char *outboard ;
  s = (state *) hot_mem_Alloc(memory, sizeof(*s)) ;
  memset(s,0,sizeof(*s)) ;
  
  hot_ens_InitJoinOps(&s->jops);
  
  s->status = BOGUS;
  s->magic = HOT_TEST_MAGIC;
  s->jops.heartbeat_rate = 3000.0;
  s->first_beat = 2;
  s->jops.argv = argv;

  strcpy(s->jops.transports, "UDP");
  strcpy(s->jops.group_name, "HOT_test");

  sprintf(s->jops.params, "suspect_sweep=1.000:time");
  s->jops.groupd = 0;
  sprintf(s->jops.princ, "Pgp(o%d)",i);
  s->jops.secure = 1;
  
  s->jops.conf.receive_cast = receive_cast;
  s->jops.conf.receive_send = receive_send;
  s->jops.conf.accepted_view = install_view;
  s->jops.conf.heartbeat = heartbeat;
  s->jops.conf.exit = exit_cb;
  s->jops.conf.block = block;
  s->jops.debug = 0 ;

  strcpy(s->jops.outboard, "FORK");
  s->jops.env = s;
  
  /* Join the group.
   */
  err = hot_ens_Join(&s->jops, &s->gctx);
  if (err != HOT_OK) {
    hot_sys_Panic(hot_err_ErrString(err));
  }

}

void print_handler(char *msg) {
    fprintf(stderr, "HOT_TEST:%s", msg) ;
    fflush(stderr) ;
}

void exc_handler(char *msg) {
    fprintf(stderr, "HOT_TEST:uncaught exception:%s", msg) ;
    fflush(stderr) ;
    exit(1) ;
}


/* This list contains the list of programs to trace.
*/
char **
parse_c_args(int argc,char **argv) {
  int i,j;
  char **rep;
  char *err;

  trace("argc=%d\n", argc);
  i=1;
  while (i+1<argc) {
    trace("%d [", i);
    if (!strcmp(argv[i],"-n")) {
      i++;
      nmembers = strtol(argv[i], &err, 10);
      if (*err != '\0') {
	printf ("Bad value for -n, must be a number.\n");
	exit (1);
      }
      if  (0 > nmembers || nmembers > 20) {
	printf ("Bad value for -n, should be a number between 0 and 20.\n");
	exit (1);
      }
      argv[i-1] = NULL;
      argv[i] = NULL;
    } 
    trace("]");
    i++;
  }
  
  rep = (char**) malloc ((sizeof (char*)) * (argc + 1));
  for(i=0, j=0; i<argc; i++) 
    if (argv[i]!= NULL) {
      rep[j]=argv[i];
      j++;
    }
  rep[j+1] = NULL;

  return rep;
}


int main(int argc, char *argv[]) {
  hot_sema_t sema;
  int i;
  char **args;

  printf("HOT_SEC_TEST: starting\n");
  args = parse_c_args (argc,argv);
  
  /* Initialize state data.
   */
  srand(time(NULL));
  memory = hot_mem_AddChannel("hot_test");

  hot_ens_MLPrintOverride(print_handler) ;
  hot_ens_MLUncaughtException(exc_handler) ;

  for (i = 1; i <= nmembers; i++) {
    join(i,args);
  }

  hot_sema_Create(0, &sema);
  hot_sema_Dec(sema);

  return 0 ;
}
