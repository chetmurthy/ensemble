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
/*
 *  Ensemble, (Version 0.41)
 *  Copyright 1997 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
/* 
 * Contents:  Maestro/Ensemble test program.
 *
 * Author:  Alexey Vaysburd, January 1997
 *
 * This test does the following:  Several group members are created and
 * join the group.  The members randomly send point-to-point and multicast
 * messages and leave/rejoin.  
 *
 * There are two execution modes, single-threaded and multi-threaded.  
 * In the multi-threaded mode, Ensemble is started in a separate thread.  
 * In the single-threaded mode, Ensemble is started in the main thread 
 * (a call to Maestro_CSX::start() is made, which never returns).
 *
 * Makefile note:  In the multi-threaded mode, make sure -threads=yes
 * purify option is set (if purify is used), and -lthread is included
 * in LDFLAGS.
 */

#include <iostream.h>
#include "Maestro.h"

#ifndef _WIN32
#include <sys/types.h>
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>
#endif
/*#include "purify.h"*/

// Define for synchronous state transfer.
//#define SYNC_XFER

#define NMEMBERS 10

extern "C" {
#ifndef _WIN32
    void srand(unsigned int);
#endif
    int rand();
}

class  Mbr: public Maestro_CSX {
public:
    
    Mbr(int id, Maestro_CSX_Options &ops) : Maestro_CSX(ops) {
	ID = id;
	state = BOGUS;
	cnt = 0;
	cout << ID << ": joining" << endl;
	join();
	cout << ID << ": join completed" << endl;
    }
    
    void leave() {
	state = LEAVING;
	cout << ID << ": leaving" << endl;
	Maestro_CSX::leave();
	cout << ID << ": leave returned" << endl;
    }
    
    int id() { return ID; }
    int stateIsNormal() { return (state == NORMAL); }
    
protected:
    
    void csx_ReceiveCast_Callback(Maestro_EndpID &origin,
				  Maestro_Message &msg) {
	int src;
	msg >> src;
	
	// cout << ID << " (" << me << "): CAST from " << src << " (" << origin
	// << ")" << endl;
	
	// cout << ID << ": CAST from " << src << endl;
    }
    
    void csx_ReceiveSend_Callback(Maestro_EndpID &origin,
				  Maestro_Message &msg) {
	int src;
	msg >> src;
	// cout << ID << ": SEND from " << src << endl;
    }
    
    void csx_AcceptedView_Callback(Maestro_CSX_ViewData &viewData,
				   Maestro_Message &msg) {
	me = viewData.myEndpID;
	nmembers = viewData.nmembers;
	
	if (state != LEAVING)
	    state = NORMAL;
	
	Maestro_String vm;
	msg >> vm;
	
	if (viewData.myRank == 0) {
	  cout << ID << ": ACCEPTED VIEW: " << viewData.viewID << 
	      "(" << viewData.nmembers << " memb, "
	       << viewData.servers.size() << " serv, " 
	       << viewData.xferServers.size() << " xf-serv, " 
	       << viewData.clients.size() << " clts)" << endl;
	}
	
	if (0 /*viewData.myRank == 0*/) {
	    //cout << ID << ": nmembers = " << viewData.nmembers << endl;
	    //cout << ID << ": view message: \"" << vm << "\"" << endl;
	    
	    if (viewData.servers.size()) {
		cout << ID << ": servers: " << endl << viewData.servers << endl;
	    }
	    
	    if (viewData.clients.size()) {
		cout << ID << ": clients: " << endl << viewData.clients << endl;
	    }
	    
	    if (viewData.xferServers.size()) {
		cout << ID << ": xferServers: " << endl << viewData.xferServers << endl;
	    }
	}
    }	
    
    void csx_ViewMsg_Callback(Maestro_CSX_ViewData &viewData,
			      /*OUT*/ Maestro_Message &viewMsg) {
	cout << ID << ": VIEW MSG: " << viewData.viewID << endl;
	Maestro_String s("hello world");
	viewMsg << s;
    }
    
    void csx_Block_Callback() {
	// cout << ID << ": BLOCK" << endl;
    }
    
    void csx_Exit_Callback() { 
	state = BOGUS;

    }
    
    void csx_Heartbeat_Callback(unsigned time) { 
	// cout << ID << ": HEARTBEAT" << endl;
    }
    
    void stateTransfer_Callback(Maestro_XferID &xferID) { 
	Maestro_Message requestMsg, stateMsg;
	Maestro_XferStatus xferStatus;
	requestMsg << ID;
	
#ifdef SYNC_XFER
	
	cout << endl << ID << ": SYNC State Transfer" << endl;
	getState(xferID, requestMsg, stateMsg, xferStatus);
	
	if (xferStatus == MAESTRO_XFER_TERMINATED) {
	    cout << endl << ID << ": SYNC Xfer Terminated" << endl;
	}
	else {
	    int src;
	    stateMsg >> src;
	    cout << endl << ID << ": SYNC Xfer Successful, from " << src << endl;
	    xferDone(xferID); 
	}   
	
#else
	
	cout << ID << ": ASYNC State Transfer" << endl;
	getState(xferID, requestMsg, xferStatus);
	
#endif
	
    }
    
    void xferCanceled_Callback(Maestro_XferID &xferID) {
	cout << ID << ": ASYNC Xfer CANCELED" << endl;
    }
    
    void gotState_Callback(Maestro_XferID &xferID,
			   Maestro_Message &stateMsg) {
	int src;
	stateMsg >> src;
	cout << ID << ": ASYNC Xfer Successful, from " << src << endl;
	xferDone(xferID); 
    }
    
    void askState_Callback(Maestro_EndpID &origin, 
			   Maestro_XferID &xferID,
			   Maestro_Message &requestMsg) {
	int src;
	requestMsg >> src;
	cout << ID << ": Ask State request, from " << src << endl;
	
	Maestro_Message stateMsg;
	stateMsg << ID;
	sendState(origin, xferID, stateMsg);
    }
    
private:
    
    enum { BOGUS, NORMAL, LEAVING } state;
    int ID;
    int cnt;
    Maestro_EndpID me;
    int nmembers;
};

void main(int argc, char *argv[]) {
    Mbr *m[NMEMBERS];
    int i;
    
#ifndef _WIN32
    srand(time(NULL));
#endif
    
    Maestro_CSX_Options ops;
    ops.heartbeatRate = 10;
    
    ops.groupName = "maestro_thread";
    // ops.protocol = "Top:Heal:Switch:Leave:Inter:Intra:Elect:Merge:Sync:Suspect:Top_appl:Pt2pt:Frag:Stable:Mnak:Bottom";
    ops.transports = "UDP";
    ops.argv = argv;
    
    ops.properties = "Gmp:Sync:Heal:Switch:Frag:Suspect:Flow";
    ops.params = "suspect_max_idle=3:int;suspect_sweep=1.000:time";
    ops.groupdFlag = 0 ;
    ops.debug = 0 ;

    ops.mbrshipType = MAESTRO_SERVER;
    ops.xferType = MAESTRO_ATOMIC_XFER;
    
    for (i = 0; i < NMEMBERS; i++)
	m[i] = new Mbr(i, ops);
    
    cout << "STARTING MAESTRO IN MULTI-THREADED MODE" << endl;
    
#define rejoin
#ifdef rejoin
    while (1) {
      Maestro_Thread::usleep(1000);
	for (i = 0; i < NMEMBERS; i++) {
	    if (rand() % 100 == 0) {
		if (m[i]->stateIsNormal()) {
		    cout << "\n*** " << m[i]->id() << " LEAVING ***" << endl;
		    m[i]->leave();
		    cout << "\n*** " << m[i]->id() << " REJOINING ***" << endl;
		    m[i]->join();
		}
	    }
	}
    }
#endif    

    Maestro_Semaphore sema;
    sema.dec();
}
