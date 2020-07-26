/**************************************************************/
/*
 *  Ensemble, 1.10
 *  Copyright 2001 Cornell University, Hebrew University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
/* 
 * Contents:  Maestro RPC performance test.
 *
 * Author:  Alexey Vaysburd, August 1997
 *
 * Start two instances of this program.  After the test completes, 
 * performance results will be printed out. 
 *
 * The test:  Each process creates a group member (over Maestro_CSX)
 * which joins the test group.  Once the two members merge, the coordinator
 * sends a series of multicasts, waiting after each multicast for the other 
 * member's reply (via another multicast) before sending the next message.
 */

#include <iostream.h>
#include "Maestro.h"

#ifndef _WIN32
#include <sys/types.h>
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>
#endif

#define NMSGS 200

extern "C" {
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
}

class  Mbr: public Maestro_CSX {
public:
  Mbr(Maestro_CSX_Options &ops) : Maestro_CSX(ops) { join(); }
  void leave() { Maestro_CSX::leave(); }
  
protected:  
  void csx_ReceiveCast_Callback(Maestro_EndpID &origin, Maestro_Message &msg) {
    if (nmembers == 2) {
      switch (myRank) {
      case 0:
	// If got a reply, signal the sending routine.
	if (origin == members[1]) {
	  rpcSema.inc();
	}
	break;
      case 1:
	// If got a message from the coordinator, send a reply.
	if (origin == members[0]) {
	  Maestro_Message msg;
	  cast(msg);
	}
	break;
      default:
	error->panic("receive cast: %d members???", nmembers);
	break;
      }
    }
  }
  
  void csx_AcceptedView_Callback(Maestro_CSX_ViewData &viewData,
				 Maestro_Message &msg) {
    me = viewData.myEndpID;

    if (nmembers > viewData.nmembers) {
      cout << "View is shrinking; exiting." << endl;
      exit(0);
    }

    myRank = viewData.myRank;
    nmembers = viewData.nmembers;
    members = viewData.members;

    cout << "VIEW (" << nmembers << ") members" << endl;

    if (nmembers == 2 && viewData.myRank == 0) {
      cout << "I am the coordinator, beginning sends." << endl;
      Maestro_Thread::create(rpcTest, this);
    }
  }	

  static void rpcTest(void *arg) {
    Mbr *mbr = (Mbr *) arg;
    int i, secs, ms;
    int nmsgs = NMSGS;
    struct timeval s_time, e_time;
    Maestro_Message msg;

    double st, et, el;

    st = get_time();
//    gettimeofday(&s_time, (struct timezone*) 0);
    
    for (i = 0; i < nmsgs; i++) {
      msg.reset();
      mbr->cast(msg);
      mbr->rpcSema.dec();
      cout << ".";
      cout.flush();
    }

//    gettimeofday(&e_time, (struct timezone*)0);
    et = get_time();

    secs = e_time.tv_sec - s_time.tv_sec;
    ms =  e_time.tv_usec - s_time.tv_usec;
    
    /*    if (ms < 0) {
      ms += 1000000;
      secs -= 1;
    }
    ms = ms/1000;
    */

    el = et - st;

    printf("Elapsed time for %d rpcs = %.06f secs\n", nmsgs, el);
    exit(0);
  }

private:

  Maestro_EndpID me;
  int myRank;
  int nmembers;  
  Maestro_EndpList members;
  Maestro_Semaphore rpcSema;
};

void main(int argc, char *argv[]) {
  Mbr *m;
  
  Maestro_CSX_Options ops;
  ops.heartbeatRate = 10;
  
  ops.groupName = "maestro_rpc_perf_test";
  ops.transports = "UDP";
  ops.argv = argv;
  
  ops.properties = "Gmp:Sync:Heal:Switch:Frag:Suspect:Flow";
  ops.params = "suspect_max_idle=3:int;suspect_sweep=1.000:time";
  ops.groupdFlag = 0;
  ops.debug = 0;
  
  ops.mbrshipType = MAESTRO_CLIENT;

  m = new Mbr(ops);
  
  Maestro_Semaphore sema;
  sema.dec();
}
