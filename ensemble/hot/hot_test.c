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

#define NMEMBERS 10

static int ncr, nex;

static struct {
  int nleave_act;
  int ncast_act;
  int nsend_act;

  int ncasts;
  int nsends;
  int nviews;
  int nexits;
  int nblocks;
  int nheartbeats;
  int njoins;
} stats;

static hot_mem_t memory;

typedef struct {
  int magic ;
  hot_gctx_t gctx;
  unsigned seqno;
  enum { BOGUS, RUNNING, BLOCKED, LEAVING } status;
  int thresh;
  unsigned int next_sweep;
  unsigned int sweep;
  hot_view_state_t vs;
  hot_ens_JoinOps_t jops;
  int got_view;
} state ;

static void scheck(state *s,hot_gctx_t g) {
  assert(s) ;
  assert(s->magic == HOT_TEST_MAGIC) ;
  assert(s->status != BOGUS) ;
  assert(s->gctx==g) ;
}

static inline void trace(const char *s, ...) {
  va_list args;
  static int debugging = -1 ;

  va_start(args, s);

  if (debugging == -1) {
      debugging = (getenv("ENS_HOT_TEST") != NULL) ;
  }
  
  if (!debugging) return ;

  fprintf(stderr, "HOT_TEST:");
  vfprintf(stderr, s, args);
  fprintf(stderr, "\n");
  va_end(args);
}

#if 0 && defined(__GNUC__)
#define ntrace(format, args...) trace(format, ##args)
#else
static void ntrace(const char *s, ...) {}
#endif

static void join(
        int thresh,
	char **argv
) ;

static void check_stats(void) {
  static int nevents = 0 ;
  nevents++ ;
  if (nevents % 100 == 0) {
    printf ("HOT_TEST:stats: c=%d s=%d v=%d e=%d b=%d h=%d j=%d (total=%d)\n", 
	    stats.ncasts,
	    stats.nsends,
	    stats.nviews,
	    stats.nexits,
	    stats.nblocks,
	    stats.nheartbeats,
	    stats.njoins,
	    (stats.ncasts+stats.nsends+stats.nviews+stats.nexits+stats.nblocks+stats.nheartbeats+stats.njoins)
	   ) ;
    printf("HOT_TEST:stats: ca=%d sa=%d la=%d\n", 
	   stats.ncast_act, stats.nsend_act, stats.nleave_act);
  }
}

/********************** Actions *******************************************/

typedef enum {
  LEAVE,
  CAST,
  SEND,
  REQUEST_NEW_VIEW,
  NO_OP
} action ;

static action rand_action(int nmembers, int thresh) {
  double p = (rand() % 1000) / 1000.0;
  if (nmembers >= thresh && p < 0.03) {
    stats.nleave_act++;
    return LEAVE;
    } else 
      if (p < 0.5) {
	stats.ncast_act++;
	trace("CAST");
	return CAST;
      } else {
	stats.nsend_act++;
	trace("SEND");
	return SEND;
      }

  trace("NO_OP");
  return NO_OP;
}

/* Send a random number of multicast messages->
 */
static void action_cast(state *s) {
  int i;
  char buf[128];
  int nmsgs;
  hot_err_t err;
  hot_msg_t msg;
  
  ntrace("action:  cast");
  assert(s->status == RUNNING);

  nmsgs = rand() % 5 ;
  
  for (i = 0; i < nmsgs; i++, s->seqno++) {
    msg = hot_msg_Create();
    
    sprintf(buf, "cast<%d>", s->seqno);
    err = hot_msg_Write(msg, buf, strlen(buf));
    if (err != HOT_OK)
      hot_sys_Panic(hot_err_ErrString(err));

    err = hot_ens_Cast(s->gctx, msg, NULL);
    if (err != HOT_OK)
      hot_sys_Panic(hot_err_ErrString(err));

    err = hot_msg_Release(&msg);
    if (err != HOT_OK)
      hot_sys_Panic(hot_err_ErrString(err));
  }
}

/* Leave the group, wait for some time, and rejoin.
 */
static void action_leave_and_rejoin(state *s) {
  hot_err_t err;
  int thresh = s->thresh;
  char **argv = s->jops.argv;

  /*printf("********************** inside new thread (%d created)\n", ncr);*/

  assert(s->status == LEAVING);
  ntrace("action: leave and rejoin");
  ntrace("HOT_TEST:leaving (nmembers=%d, rank=%d)",
	 s->vs.nmembers, s->vs.rank);

  /* Leave the group.
   */
  err = hot_ens_Leave(s->gctx);
  if (err != HOT_OK)
    hot_sys_Panic(hot_err_ErrString(err));

  /* After call to hot_ens_Leave(), s should not be referenced.
   */

  join(thresh, argv);

  nex++;
  /*printf("********************** exited %d threads\n", nex);*/
}

/* Send a random number of pt2pt messages to a random view member.
 */
static void action_send(state *s) {
  int i;
  char buf[128];
  hot_endpt_t dest;
  unsigned rank;
  int nmsgs;
  hot_err_t err;
  hot_msg_t msg;
  
  assert(s->status == RUNNING);
  ntrace("action: send");
  
  rank = rand() % s->vs.nmembers;
  nmsgs = (rank == s->vs.rank) ? 0 : (rand() % 5);
  
  dest = s->vs.members[rank];
  
  /* If destination is me (b/c of the race condition when updating the
   * s struct during the view change), don't send anything.
   */
  if (strcmp(dest.name, 
	     s->vs.members[s->vs.rank].name) == 0)
    return;
  
  /*
    if (nmsgs) {
    printf("sender: %s\n", 
    s->vs.members[s->vs.my_rank].name);
    printf("dest: %s\n", dest.name);
    }
  */
    
  for (i = 0; i < nmsgs; i++) {
    msg = hot_msg_Create();
	
    sprintf(buf, "send<%d>", s->seqno++);
    err = hot_msg_Write(msg, buf, strlen(buf));
    if (err != HOT_OK)
      hot_sys_Panic(hot_err_ErrString(err));
    
    err = hot_ens_Send(s->gctx, &dest, msg, NULL);
    if (err != HOT_OK)
      hot_sys_Panic(hot_err_ErrString(err));

    err = hot_msg_Release(&msg);
    if (err != HOT_OK)
      hot_sys_Panic(hot_err_ErrString(err));
  }
}

/* Request a view change.
 */
static void action_request_new_view(state *s) {
  hot_err_t err;
  
  assert(s->status == RUNNING);
  ntrace("action: request new view");
  
  /* View-change request will be ignored if our rank is not 0.
   */
  if (s->vs.rank == 0) {
    err = hot_ens_RequestNewView(s->gctx);
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
  char contents[128];
  hot_err_t err;
  unsigned pos;

  scheck(s, gctx) ;
  
  err = hot_msg_GetPos(msg, &pos);
  if (err != HOT_OK)
    hot_sys_Panic(hot_err_ErrString(err));
  
  err = hot_msg_Read(msg, contents, pos);
  if (err != HOT_OK)
    hot_sys_Panic(hot_err_ErrString(err));
  
  contents[pos] = 0;
  
  stats.ncasts++ ;
  check_stats() ;
  ntrace("cast: '%s' from %s", contents, origin->name);
}

static void receive_send(
        hot_gctx_t gctx,
	void *env,
	hot_endpt_t *origin,
	hot_msg_t msg
) {
  state *s = (state*) env ;
  char contents[128];
  hot_err_t err;
  unsigned pos;
 
  scheck(s, gctx) ;

  err = hot_msg_GetPos(msg, &pos);
  if (err != HOT_OK)
    hot_sys_Panic(hot_err_ErrString(err));
  
  err = hot_msg_Read(msg, contents, pos);
  if (err != HOT_OK)
    hot_sys_Panic(hot_err_ErrString(err));
  
  contents[pos] = 0;
  stats.nsends++ ;
  check_stats() ;
  ntrace("send: '%s' from %s", contents, origin->name);
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
  scheck(s, gctx) ;

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
      printf("HOT_TEST:view: nmembers=%d, rank=%d, %s\n", 
	    s->vs.nmembers, s->vs.rank, 
	    s->vs.primary ? "PRIMARY" : "NOT PRIMARY");

  /* Send some messages right away.
   */
  if (s->status == RUNNING)
    action_cast(s);

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

  stats.nviews++ ;
  check_stats() ;
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
    scheck(s, gctx) ;

    /*purify_new_leaks();*/
    
    if (s->status != RUNNING)
        return;
    
    if (time >= s->next_sweep) {
	stats.nheartbeats++ ;
	check_stats() ;
	
	s->next_sweep = time + s->sweep ;
	ntrace("heartbeat") ;
	
	switch (rand_action(s->vs.nmembers,s->thresh)){
	case LEAVE:
	  action_cast(s);
	  s->status = LEAVING;
	  
	  /*
	    if ((err = hot_ens_Leave(s->gctx)) != HOT_OK)
	    hot_sys_Panic(hot_err_ErrString(err));
	  */
	  
	    ncr++;
	    /*printf("************** created %d threads\n", ncr);*/
	    hot_thread_Create((void*)action_leave_and_rejoin,s,NULL) ;

	    /* action_leave_and_rejoin(s); */
	    break;
	case CAST:
	    action_cast(s);
	    break;
	case SEND:
	    action_send(s);
	    break;
	case REQUEST_NEW_VIEW:
	    action_request_new_view(s);
	    break;
	case NO_OP:
	    break;
	default:
	    assert(0) ;
	    break;
	}
	
    }
}

static void exit_cb(
        hot_gctx_t gctx,
        void *env
) {
  state *s = (state*) env;
  scheck(s, gctx);
  ntrace("exit");

  stats.nexits++;
  check_stats();

  if (s->status != LEAVING)
    hot_sys_Panic("hot_test: exit_cb: state=%d, expected %d", 
		  s->status, LEAVING);
  s->status = BOGUS;

  if (s->vs.members != NULL) {
      hot_mem_Free(s->vs.members);
  }
  memset(s, 0, sizeof(*s));
  hot_mem_Free(s);
}

static void block(
        hot_gctx_t gctx,
	void *env
) {
  state *s = (state*) env ;
  scheck(s, gctx) ;
  ntrace("block");
  if (s->status == RUNNING)
    s->status = BLOCKED;
  stats.nblocks++ ;
  check_stats() ;
}

static void join(
        int thresh,
	char **argv
) {
  hot_err_t err ;
  state *s ;
  const char *outboard ;
  s = (state *) hot_mem_Alloc(memory, sizeof(*s)) ;
  memset(s,0,sizeof(*s)) ;

  hot_ens_InitJoinOps(&s->jops);
  
  s->status = BOGUS;
  s->thresh = thresh;
  s->magic = HOT_TEST_MAGIC;
  s->jops.heartbeat_rate = (unsigned int) 3000.0;
  s->sweep = 3;
  s->jops.argv = argv;
  s->next_sweep = 0 ;

  strcpy(s->jops.transports, "UDP");
  strcpy(s->jops.group_name, "HOT_test");
  //strcpy(s->jops.properties, "Gmp:Sync:Heal:Frag:Suspect:Flow:Slander:Rekey:Auth");
  strcpy(s->jops.properties, "Gmp:Sync:Heal:Frag:Suspect:Primary:Debug");
  s->jops.use_properties = 1;

  sprintf(s->jops.params, "primary_quorum=%d:int;suspect_max_idle=10:int;suspect_sweep=1.000:time", (1 + (NMEMBERS / 2)));

  s->jops.groupd = 0;
  
  s->jops.conf.receive_cast = receive_cast;
  s->jops.conf.receive_send = receive_send;
  s->jops.conf.accepted_view = install_view;
  s->jops.conf.heartbeat = heartbeat;
  s->jops.conf.exit = exit_cb;
  s->jops.conf.block = block;
  s->jops.debug = 0 ;

  /* If ENS_OUTBOARD_TYPE is set then use that method for
   * connecting to outboard server.  Otherwise use default
   * method for our platform.
   */
  outboard = getenv("ENS_OUTBOARD_TYPE") ;
  if (!outboard) {
#ifdef WIN32
    outboard = "SPAWN" ;
#else
    outboard = "FORK" ;
    //    outboard = "TCP" ;
#endif
  }
  strcpy(s->jops.outboard, outboard);
  s->jops.env = s;
  
  /* Join the group.
   */
  err = hot_ens_Join(&s->jops, &s->gctx);
  if (err != HOT_OK) {
    hot_sys_Panic(hot_err_ErrString(err));
  }

  stats.njoins++ ;
  check_stats() ;
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

int main(int argc, char *argv[]) {
  hot_sema_t sema;
  int thresh = (NMEMBERS * 2) / 3;
  int nmembers = NMEMBERS;
  int i;

  printf("HOT_TEST: starting thresh=%d n=%d\n", thresh, nmembers);
  
  /* Initialize state data.
   */
  srand(time(NULL));
  memory = hot_mem_AddChannel("hot_test");

  hot_ens_MLPrintOverride(print_handler) ;
  hot_ens_MLUncaughtException(exc_handler) ;

  for (i = 0; i < nmembers; i++) {
    join(thresh, argv);
  }

  hot_sema_Create(0, &sema);
  hot_sema_Dec(sema);

  return 0 ;
}
