/**************************************************************/
/*
 *  Ensemble, (Version 0.40c)
 *  Copyright 1997 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
/* 
 * Test of Ensemble with the HOT C interface.
 *
 * Author:  Alexey Vaysburd, Dec. 96.
 * Modified By: Tim Clark, Aug. 97
 *
 * NB: Access to the global struct is not protected with a mutex
 * (that could cause a deadlock). 
 */

#ifdef _WIN32
#include <windows.h>
#endif

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
#ifndef _WIN32
#include <sys/time.h>
extern int isdigit();
#endif



#define HOT_TEST_MAGIC 234324

struct {
  int ncasts ;
  int nsends ;
  int nviews ;
  int nexits ;
  int nblocks ;
  int nheartbeats ;
  int njoins ;
} stats ;

typedef struct {
  int magic ;
  hot_gctx_t gctx;
  hot_lock_t mutex;
  unsigned seqno;
  int running;
  int thresh;
  int leaving;
  unsigned int next_sweep;
  unsigned int sweep;
  int exited ;
  hot_view_state_t vs;
  hot_ens_JoinOps_t jops;
} state ;


/********** TC - new variables for rpc test ***********/

/* Wait for reply on this sema */
hot_sema_t rpc_sema ;  

/* global to accept heartbeat rate from cmd line */
int hb_rate = 1000;

/* global to accept number of msgs to send from cmd line */
int nummsgs = 500;

/******************************************************/

void scheck(state *s,hot_gctx_t g) {
  assert(s) ;
  assert(s->magic == HOT_TEST_MAGIC) ;
  assert(!s->exited) ;
  assert(s->gctx==g) ;
}

void trace(char *s) {
  /*
  printf("HOT_TEST:%s\n",s) ;
  */
}

void join(
        int thresh,
	char **argv
) ;

void check_stats(void) {
  static int nevents = 0 ;
  nevents++ ;
  if (nevents % 100 == 0) {
    printf ("HOT_TEST:stats:c=%d s=%d v=%d e=%d b=%d h=%d j=%d (total=%d)\n", 
	    stats.ncasts,
	    stats.nsends,
	    stats.nviews,
	    stats.nexits,
	    stats.nblocks,
	    stats.nheartbeats,
	    stats.njoins,
	    (stats.ncasts+stats.nsends+stats.nviews+stats.nexits+stats.nblocks+stats.nheartbeats+stats.njoins)
	   ) ;
  }
}

/********************** Actions *******************************************/

/* Get the current time.
 */
double get_time(void){
#ifdef _WIN32
	double time;
	static double PerformanceCounterTicksPerSecond = 0.;
	__int64 PerformanceCounter;

	if (PerformanceCounterTicksPerSecond == 0.) {
		__int64 PerformanceFrequency;
		QueryPerformanceFrequency((PLARGE_INTEGER) &PerformanceFrequency);
		PerformanceCounterTicksPerSecond = 1. / PerformanceFrequency;
	}

	QueryPerformanceCounter((PLARGE_INTEGER) &PerformanceCounter);
	time = (PerformanceCounter * PerformanceCounterTicksPerSecond);

	return time;
#else /* _WIN32 */
	struct timeval tv;

	gettimeofday(&tv, 0);
	return tv.tv_sec + tv.tv_usec * 0.000001;
#endif /* _WIN32 */
}


/* Send multicast messages->
 */
void action_cast(state *s) {
  int i ; /*, secs, ms;*/
  char buf[128];
  hot_err_t err;
  hot_msg_t msg;
  hot_uint32 u;
  double stime, etime, eltime;

  trace("action:  cast");

  /* Create semaphore to wait for reply on */
  hot_sema_Create(0,&rpc_sema) ;

  /* Get start time for test */
  stime = get_time();

  /* Now begin send loop for nummsgs */
  for (i = 0; i < nummsgs; i++, s->seqno++) 
  {
    /* create a msg */
    msg = hot_msg_Create();

    /* Put a seqno into msg */    
    memset(buf, 0x0, sizeof(buf));
    sprintf(buf, "mcast<%d>", s->seqno);
    err = hot_msg_Write(msg, buf, strlen(buf));
    if (err != HOT_OK)
      hot_sys_Panic(hot_err_ErrString(err));
    
    /* Actually send the msg */
    err = hot_ens_Cast(s->gctx, msg, NULL);
    if (err != HOT_OK)
      hot_sys_Panic(hot_err_ErrString(err));
    
    /* free msg resources */
    err = hot_msg_Release(&msg);
    if (err != HOT_OK)
      hot_sys_Panic(hot_err_ErrString(err));

    /* Wait on reply rpc, signalled by the receive thread */
    /*printf("Sent msg %d waiting on rpc_sema\n", s->seqno);*/
    hot_sema_Dec(rpc_sema) ;

    /* We were signalled, so loop */
  }

  /* Get end of test time */
  etime = get_time();
  eltime = etime - stime;

  /* Convert to msg throughput also */
  /* Print out results */
  printf("\n\nElapsed time for %d rpcs = %.06f secs\n", nummsgs, eltime);
  printf("Throughput = %f msgs/sec.\n\n", nummsgs/eltime);
  /*exit(0) ;*/
  /* BUG: Modified here to reproduce a bug */
  hot_ens_Leave(s->gctx);
}

/********************** Callbacks *****************************************/

void receive_cast(
        hot_gctx_t gctx,
	void *env,
	hot_endpt_t *origin, 
	hot_msg_t msg
) {
  state *s = (state*) env ;
  hot_err_t err;
  char contents[128];
  unsigned pos;

  scheck(s,gctx) ;

  /* Process msg and do the right thing */
  /* Note that this is a 2-process only test */
  if (s->vs.nmembers == 2)
  {
    if (s->vs.rank == 0 && (memcmp(origin,&s->vs.members[s->vs.rank],sizeof(*origin))))
    {
      /* I'm oldest member, got a reply, signal sending routine */

      /* disable this code (to the printf) for performance measurements! */
      err = hot_msg_GetPos(msg, &pos);
      if (err != HOT_OK)
	hot_sys_Panic(hot_err_ErrString(err));

      err = hot_msg_Read(msg, contents, pos);
      if (err != HOT_OK)
	hot_sys_Panic(hot_err_ErrString(err));
      contents[pos] = 0;
      printf("Reply: '%s' from %s\n", contents, origin->name);

      /* Unblock semaphore (send next message) */
      hot_sema_Inc(rpc_sema) ;
    }
    else
    {
      /* Not oldest, if msg is not from myself, send a reply */
      if (memcmp(origin,&s->vs.members[s->vs.rank],sizeof(*origin)))
      {
        err = hot_ens_Cast(s->gctx, msg, NULL);
        if (err != HOT_OK)
          hot_sys_Panic(hot_err_ErrString(err));
      }
    }
  }
  stats.ncasts++ ;
  check_stats() ;
}

void receive_send(
        hot_gctx_t gctx,
	void *env,
	hot_endpt_t *origin,
	hot_msg_t msg
) {}


/* We have accepted a new view.  The new view state is specified.
 */
void accepted_view(
        hot_gctx_t gctx,
	void *env,
	hot_view_state_t *view_state
) {
  state *s = (state*) env ;
  int size, i ;
  static int started ;
  scheck(s,gctx) ;

  /* Release the old view.
   */
  if (s->vs.members != NULL) {
    free(s->vs.members) ;
  }

  /* Set up new view info */
  s->vs = *view_state; 
  size = sizeof(s->vs.members[0])*s->vs.nmembers ;
  s->vs.members = (hot_endpt_t*) malloc(size) ;
  memcpy(s->vs.members,view_state->members,size) ;

  /* print out interesting stuff */
  if (s->vs.rank == 0)
    printf("HOT_TEST:view (nmembers=%d, rank=%d)\n",s->vs.nmembers,s->vs.rank);

  printf("\tview_id = (%d,%s)\n", view_state->view_id.ltime,
	 view_state->view_id.coord.name);
  printf("\tversion = \"%s\"\n", view_state->version);
  printf("\tgroup_name = \"%s\"\n", view_state->group_name);
  printf("\tprotocol = \"%s\"\n", view_state->protocol);
  printf("\tmy_rank = %d\n", 	view_state->rank);
  printf("\tgroup daemon is %s\n", view_state->groupd ? "in use" : "not in use");
  printf("\tparameters = \"%s\"\n", view_state->params);
  printf("\txfer_view = %d\n", view_state->xfer_view);
  printf("\tprimary = %d\n", view_state->primary);
  
  for (i = 0; i < view_state->nmembers; i++)
    printf("%s\n", view_state->members[i].name);

  s->running = 1;

  stats.nviews++ ;
  check_stats() ;

  /* use membership info to decide when to start the send thread */
  if (s->vs.nmembers == 2)
  {
    if (s->vs.rank == 0) {
      printf("I am oldest member, beginning sends\n");
      hot_thread_Create((void*)action_cast, s, 0);
    }
    started = 1 ;
  }
  if (started && s->vs.nmembers < 2)
  {
    printf("View shrinking, exiting\n");
    hot_ens_Leave(gctx);    
  }
}

/* A periodic heartbeat event has occurred.  The 'time' argument 
 * is an approximation of the current time.
 */
void heartbeat(
        hot_gctx_t gctx,
	void *env,
	unsigned time
) {}

void exit_cb(
        hot_gctx_t gctx,
        void *env
) {
 /* BUG: Modified here to reproduce a bug */

  printf("Got exit callback\n");
  exit(0);
}

void block(
        hot_gctx_t gctx,
	void *env
) {}

void join(
        int thresh,
	char **argv
) {
  hot_err_t err ;
  state *s ;
  char *outboard ;
  s = (state *) malloc(sizeof(*s)) ;
  memset(s,0,sizeof(*s)) ;
  
  s->thresh = thresh ;
  s->magic = HOT_TEST_MAGIC ;
  s->jops.heartbeat_rate = hb_rate;
  s->sweep = hb_rate ;
  s->jops.argv = argv;
  s->next_sweep = 0 ;
  /* Can also set "DEERING" as transport here */
  strcpy(s->jops.transports, "UDP:TCP");
  strcpy(s->jops.group_name, "HOT_test2");
  
  strcpy(s->jops.properties, "Gmp:Sync:Heal:Switch:Frag:Suspect:Flow:Primary");
  s->jops.use_properties = 1;
  strcpy(s->jops.params, "primary_quorum=4:int;suspect_max_idle=3:int;suspect_sweep=1.000:time");
  s->jops.groupd = 0;
  
  s->jops.conf.receive_cast = receive_cast;
  s->jops.conf.receive_send = receive_send;
  s->jops.conf.accepted_view = accepted_view;
  s->jops.conf.heartbeat = heartbeat;
  s->jops.conf.exit = exit_cb;
  s->jops.conf.block = block;
  s->jops.debug = 0 ;

  outboard = getenv("ENS_OUTBOARD_TYPE") ;
  if (!outboard) {
#ifdef WIN32
    outboard = "SPAWN" ;
#else
    outboard = "FORK" ;
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

int main(int argc, char *argv[]) {
  hot_sema_t sema ;
  char c;
  int thresh = 5 ;
  char **argvtmp ;
  
  argvtmp = argv ;
  while(--argc)
  {
    char *arg = *++argvtmp;
    c = *arg;
    if(c == '-')
        c = *++arg;
    switch(c)
    {
      case 'h':
      case 'H':
	if (isdigit(*(++arg)))
        {
          hb_rate = atoi(arg);
	  printf("heartbeat rate %d ms.\n", hb_rate);
        }
        else                
	  printf("Invalid argument\n");
        break;
      case 'm':
      case 'M':
	if (isdigit(*(++arg)))
        {
          nummsgs = atoi(arg);
	  printf("Msgs to send = %d\n", nummsgs);
        }
        else                
	  printf("Invalid argument\n");
        break;

      default:
        break;
    }
  }

  trace("HOT_TEST2: starting");
  
  /* Initialize state data.
   */
  srand(time(NULL));

  join(thresh,argv) ;

  hot_sema_Create(0,&sema) ;
  hot_sema_Dec(sema) ;

  return 0 ;
}
