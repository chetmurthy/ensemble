/**************************************************************/
/*
 *  Ensemble, 2_00
 *  Copyright 2004 Cornell University, Hebrew University
 *           IBM Israel Science and Technology
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
/**************************************************************/
/* C_MTALK.C */
/* Author: Ohad Rodeh 10/2003 */
/* A simple program implementing a multi-person talk. */
/**************************************************************/
#include "ens.h"
#include "ens_threads.h"
#include "ens_utils.h"
#include "ens_comm.h"

#include <stdio.h>
#include <malloc.h>
/**************************************************************/
#define NAME "C_MTALK"
/**************************************************************/

// Connection to server
static ens_conn_t *conn = NULL;

// The Ensemble group member 
static ens_member_t memb;

// The current view 
static ens_view_t view;

// A static buffer for receving messages.
static char msg_buffer[ENS_MSG_MAX_SIZE];

// Are we blocked? 
static int blocked = 0;

// Are we joining? 
static int joining = 0;

static ens_lock_t *mutex;

/**************************************************************/
static void ProcessArgs(int argc, char **argv);
static void AcceptInput(void);
static void MainLoop(void);
/**************************************************************/

/* A thread that reads input from the user
 */
static void AcceptInputThread(void *dummy)
{
    char buf[101];
    int len ;

    while (1) {
	EnsTrace(NAME,"c_mtalk:stdin_handler");
	fgets(buf, 100, stdin);
	len = strlen(buf);
	if (len>=100)
            EnsPanic("Can't send strings larger than 100 bytes");
	
	buf[len-1] = 0;
	EnsTrace(NAME,"Read: <%s>", buf);
	
	EnsLockTake(mutex);
        {
	    if (joining || blocked) {
		printf("Cannot send while group is joining/blocked, try again later\n");
                fflush(stdout);
	    } else {
                // multicast the message to the group
		ens_Cast(&memb, len, buf);
	    }
	}
        EnsLockRelease(mutex);
    }
}

/**************************************************************/

static void MainLoop(void) 
{
    int data_available;
    ens_rc_t rc;
    ens_msg_t msg;
    int nmembers;
    int msg_size;
    int origin;
    int i;
    
    while(1) 
    {
        // Read all waiting messages from Ensmeble
        rc = ens_Poll(conn, 1000, &data_available);

        if (ENS_ERROR == rc)
            EnsPanic("Error polling for data.");


        if (data_available) {
            rc = ens_RecvMetaData(conn, &msg);

            if (ENS_ERROR == rc)
                EnsPanic("Error while receving meta-data");

            switch(msg.mtype) {
                // Got a new view
            case VIEW:
                // Re-Initialize the view structure
                nmembers = msg.u.view.nmembers;
                if (view.address != NULL) free(view.address);
                if (view.endpts != NULL) free(view.endpts);
                view.address = EnsMalloc(ENS_ADDR_MAX_SIZE * nmembers);
                view.endpts = EnsMalloc(ENS_ENDPT_MAX_SIZE * nmembers);

                rc = ens_RecvView(conn, &memb, &view);
                if (ENS_ERROR == rc)
                    EnsPanic("Could not receive the view");

                // Print the new view
                printf("new view:\n");
                printf("\t nmembers=%d\n", view.nmembers);
                printf ("\t view=[");
                for (i=0; i<view.nmembers; i++)
                    printf("%s:", view.endpts[i].name);
                printf ("]\n");
                fflush(stdout);

                // We can now send messages.
                EnsLockTake(mutex);
                joining = 0;
                blocked = 0;
                EnsLockRelease(mutex);
                break;

                // Got a new multicast message
            case CAST:
                msg_size = msg.u.cast.msg_size;
                rc = ens_RecvMsg(conn, &origin, msg_buffer);
                if (ENS_ERROR == rc)
                    EnsPanic("Error in receving a multicast message");
                printf ("Recv multicast message  origin=%d  data=%s\n",
                        origin, msg_buffer);
                fflush(stdout);
                break;

                // Got a new point-to-point message
            case SEND:
                msg_size = msg.u.send.msg_size;
                rc = ens_RecvMsg(conn, &origin, msg_buffer);
                if (ENS_ERROR == rc)
                    EnsPanic("Error in receving a point-to-point message");
                printf ("Recv point-to-point message  origin=%d  data=%s",
                        origin, msg_buffer);
                fflush(stdout);
                break;

                // Blocked in preparation for a view change
            case BLOCK:
                EnsLockTake(mutex);
                blocked = 1;
                EnsLockRelease(mutex);
                
                ens_BlockOk(&memb);
                break;
            case EXIT:
                EnsPanic("Got EXIT");
                break;
            }
            
        }
    }
}

static void ProcessArgs(int argc, char **argv)
{
    int i;
    char **ret = NULL;
    
    for (i=0;i<argc;i++) {
        if (strcmp(argv[i], "-trace") == 0) {
	    if (++i >= argc) {
		continue ;
	    }
	    EnsAddTrace(argv[i]) ;
	}
    }
}

int main(int argc, char *argv[])
{
    ens_jops_t jops;
    ens_rc_t rc;

    ProcessArgs(argc, argv);
    
    // Initialize global variables
    memset((char*)&memb, 0, sizeof(ens_member_t));
    memset((char*)&view, 0, sizeof(ens_view_t));
    memset(msg_buffer, 0, ENS_MSG_MAX_SIZE);
    mutex = EnsLockCreate();
    
    // connect to server
    conn = ens_Init (ENS_SERVER_TCP_PORT);
    if (NULL == conn)
        EnsPanic("Error, could not open connection to server, exiting.");

    // Fixme, we should have a connect call.
    //conn.Connect();

    memset((char*)&jops, 0, sizeof(ens_jops_t));

    strcpy(jops.group_name, "Mtalk") ;
    strcpy(jops.properties, "Gmp:Sync:Heal:Switch:Frag:Suspect:Flow:Slander:Local");
    
    // Create the endpoint
    rc = ens_Join(conn, &memb, &jops, NULL);
    if (ENS_ERROR == rc) 
        EnsPanic("Error while joining group, exiting.");
    joining = 1;

    // Create a thread that will listen to input from standard input
    EnsThreadCreate( AcceptInputThread, NULL);

    // start listening to input from Ensemble
    MainLoop();
    return 0;
}

