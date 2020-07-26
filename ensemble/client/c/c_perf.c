/**************************************************************/
/* C_PERF.C: Randomly multicast/send messages and fail */
/* Author: Ohad Rodeh 12/2003 */
/* Tests two scenarios: ping latency, and bandwith */
/**************************************************************/
#include "ens_utils.h"
#include "ens_threads.h"
#include "ens.h"
#include "md5.h"
#include <stdio.h>
#include <stdlib.h>
#include <limits.h>
#include <memory.h>
/**************************************************************/
#define NAME "C_PERF"
/**************************************************************/
/* Test parameters
 */
typedef enum prog_t {
    INVALID,
    THROU,
    RPC,
} prog_t;


static int nmembers = 2;
static int size = 1000 ;
static int prog = INVALID;
static int total_num_msgs = 20000;

// Connection to server
static ens_conn_t *conn = NULL;

// a static view structure to receive views into
static ens_view_t view;

// A static buffer for receving messages.
static char msg_buffer[ENS_MSG_MAX_SIZE];

// a static view structure to receive views into
static ens_view_t view;

// my Ensemble endpoint
static ens_member_t *my_memb;

static int done = 0;
static int total = 0;
static int num = 0;
static long start_time = 0;
static int port = ENS_SERVER_TCP_PORT;

static int blocked = 0 ;
static int start = 0;
static int sent_first = 0;

#define KBYTE 1024
#define MBYTE (1024 * 1024)

static char props[ENS_PROPERTIES_MAX_SIZE];

#define GROUP_NAME_SIZE 10
static char group[GROUP_NAME_SIZE];
    
// A lock to protect the [blocked] variable
static ens_lock_t *mutex;

/**************************************************************/
static void Usage(void);
static void ThrouCastThread (void* dummy);
static void ThrouMainLoop(void);
static void RpcMainLoop(void);
static void ProcessArgs(int argc, char **argv);
static void Join(void);
static int GetTimeMillis(void);
static void AllowAutoKill (void);
static void AllowAutoKillFun (void* dummy);
/**************************************************************/

// Get the current time in milli-seconds
#ifndef _WIN32
#include <sys/time.h>
static int GetTimeMillis(void)
{
    struct timeval tv;
    static int first_time = 1;
    static int init_time_sec = 0;
    static int init_time_usec = 0;
    
    if (gettimeofday(&tv,NULL) == -1)
	EnsPanic("Could not get the time of day");

    if (first_time){
	init_time_sec = tv.tv_sec;
	init_time_usec = tv.tv_usec;
	first_time = 0;
        return 0;
    } else {
        return (((tv.tv_usec - init_time_usec) / 1000) +
                 ((tv.tv_sec - init_time_sec) * 1000));
    }
}
#else
static int GetTimeMillis(void)
{
    static int first_time = 1;
    static unsigned int initial_time = 0;
    
    if (initial_time == 0) {
	initial_time = GetTickCount();
	first_time = 0;
        return 0;
    } else {
	return GetTickCount() - initial_time;
    }
}
#endif
/**************************************************************/
static void AllowAutoKillFun (void* dummy)
{
    char s[10];
    int len=0;
    len = fread(s, 4, 1, stdin);
    if (0 == len) {
        printf("Killing process\n");
        exit(0);
    } 
    printf("done\n"); fflush(stdout);
}
    
// Allow the ML-scripting engine to kill this program
static void AllowAutoKill (void)
{
    EnsThreadCreate( AllowAutoKillFun, NULL);
}
/**************************************************************/


/* RPC test case
 */
static void RpcMainLoop(void)
{
    int data_available;
    ens_rc_t rc;
    ens_msg_t msg;
    ens_member_t *memb;
    int i;
    int msg_size;
    int origin;
    
    while (1) {
        data_available = 0;
        rc = ens_Poll(conn, 1000, &data_available);
        if (ENS_ERROR == rc)
            EnsPanic("Error polling for data.");
        
        if (data_available) {
            rc = ens_RecvMetaData(conn, &msg);

	    if (ENS_ERROR == rc)
		EnsPanic("Error receiving meta-data");
	    
            memb = msg.memb;
            switch(msg.mtype) {
            case VIEW:
                // Re-Initialize the view structure
                if (view.address != NULL) free(view.address);
                if (view.endpts != NULL) free(view.endpts);
                memset(&view, 0, sizeof(ens_view_t));
                view.address = EnsMalloc(ENS_ADDR_MAX_SIZE * msg.u.view.nmembers);
                view.endpts = EnsMalloc(ENS_ENDPT_MAX_SIZE * msg.u.view.nmembers);
                rc = ens_RecvView(conn, memb, &view);

                if (ENS_ERROR == rc)
                    EnsPanic("Error while receving view");
                    
                // Print the new view
                printf("new view:\n");
                printf("\t nmembers=%d  rank=%d\n", view.nmembers, view.rank);
                printf("\t view=[");
                for (i=0; i<view.nmembers; i++)
                    printf("%s:", view.endpts[i].name);
                printf("]\n");
                fflush(stdout);
                
                blocked = 0 ;
                if (2 == view.nmembers) {
                    start = 1 ;
                    start_time = GetTimeMillis();
                    printf("Got initial membership start_time\n"); fflush(stdout);
                }

                if (nmembers > view.nmembers &&
                    start) {
                    printf("Members have started to leave, exiting.\n");
                    exit(0);
                }
		break;

                // Got a new multicast message
            case CAST:
                EnsPanic("Got CAST");
                break;
                
                // Got a new point-to-point message
            case SEND:
                msg_size = msg.u.send.msg_size;
                rc = ens_RecvMsg(conn, &origin, msg_buffer);
                EnsTrace(NAME, "got pt2pt msg");
                if (ENS_ERROR == rc)
                    EnsPanic("Error in receving a point-to-point message");

                num++;
                if (num % 1000 == 0) {
                    printf("#recv_send: %d\n", num);
                    fflush(stdout);
                }
                
                if (start &&
                    !blocked &&
                    view.nmembers == 2) {
                    if (view.rank == 0)
                        ens_Send1(my_memb, 1, size, msg_buffer);
                    if (view.rank == 1)
                        ens_Send1(my_memb, 0, size, msg_buffer);
                }
                
                if (start &&
                    num >= total_num_msgs) 
                {
                    long now = GetTimeMillis();
                    long diff = now - start_time;
                    float rtl = 1/((float) num/(float)diff);

                    start = 0 ;
                    printf("finished RPC test\n");
                    printf("#msgs=%d\n", num);
                    printf("time=%ld (milliseconds)\n", diff);
                    printf("round-trip latency=%3.5f(milliseconds)\n", rtl);
		    fflush(stdout);
		    ens_Leave(memb);
                    exit(0);
                }
                break;
                
                // Blocked in preparation for a view change
            case BLOCK:
                blocked=1;
                if (memb->current_status != Leaving)
                    ens_BlockOk(msg.memb);
                break;
                
            case EXIT:
                EnsPanic("Got EXIT");
                break;
            }
        }

        if (start &&
            0 == view.rank &&
            2 == view.nmembers &&
            !sent_first) {
            sent_first = 1;
            printf("Sending first message\n"); fflush(stdout);
            ens_Send1(my_memb, 1, size, msg_buffer);
        }
     }
}

/**************************************************************/
/* Throuput test case
 */

static void ThrouCastThread (void* _null)
{
    int i;
    int am_blocked;
    
    printf ("Mulitcasting messages\n"); fflush(stdout);
    for (i=0; i<total_num_msgs; i++) {
	if (i % 100 == 0) {
	    printf("mcast i=%d\n", i);
	    fflush(stdout);
	}
        EnsLockTake(mutex);
        am_blocked = blocked;
        EnsLockRelease(mutex);
        
        if (!am_blocked) 
            ens_Cast(my_memb, size, msg_buffer);
    }
    done = 1;
}

static void ThrouMainLoop(void)
{
    int data_available;
    ens_rc_t rc;
    ens_msg_t msg;
    ens_member_t *memb;
    int i;
    int msg_size;
    int origin;
    
    while (1) {
        data_available = 0;
        rc = ens_Poll(conn, 1000, &data_available);
        if (ENS_ERROR == rc)
            EnsPanic("Error polling for data.");
        
        if (data_available) {
            rc = ens_RecvMetaData(conn, &msg);
	    
            if (ENS_ERROR == rc)
                EnsPanic("Error while receving meta-data");
            
            memb = msg.memb;
            switch(msg.mtype) {
            case VIEW:
                // Re-Initialize the view structure
                if (view.address != NULL) free(view.address);
                if (view.endpts != NULL) free(view.endpts);
                memset(&view, 0, sizeof(ens_view_t));
                view.address = EnsMalloc(ENS_ADDR_MAX_SIZE * msg.u.view.nmembers);
                view.endpts = EnsMalloc(ENS_ENDPT_MAX_SIZE * msg.u.view.nmembers);
                rc = ens_RecvView(conn, memb, &view);
		
                if (ENS_ERROR == rc)
                    EnsPanic("Error while receving view");
		
                // Print the new view
                printf("new view:\n");
                printf("\t nmembers=%d\n", view.nmembers);
                printf("\t view=[");
                for (i=0; i<view.nmembers; i++)
                    printf("%s:", view.endpts[i].name);
                printf("]\n");
                fflush(stdout);
                
                blocked = 0 ;
                if (nmembers == view.nmembers) {
                    start = 1 ;
                    start_time = GetTimeMillis();
                    printf("Got initial membership\n"); fflush(stdout);
		    
		    if (0 == view.rank)
			EnsThreadCreate( ThrouCastThread, memb);
                }
		
                if (nmembers > view.nmembers &&
                    start) {
                    printf("Members have started to leave, exiting.\n");
		    fflush(stdout);
                    exit(0);
                }
                break;
                
                // Got a new multicast message
            case CAST:
                msg_size = msg.u.cast.msg_size;
                rc = ens_RecvMsg(conn, &origin, msg_buffer);
                if (ENS_ERROR == rc)
                    EnsPanic("Error in receving a multicast message");
		
                num++;
                total += msg_size;
                if (num % 100 == 0) {
                    printf("#recv msgs: %d  #size=%d\n", num, total);
                    fflush(stdout);
                }
                
                if (start &&
                    num == total_num_msgs &&
                    0 != view.rank )
                {
                    long now = GetTimeMillis();
                    long diff = now - start_time;
                    float throu = ((float)total)/MBYTE * (1000/(float)diff);
		    
                    start = 0 ;
                    printf("finished throughput test\n");
                    printf("total=        %3.0f (Mbyte)\n", ((float)total)/MBYTE);
                    printf("time=            %ld (milliseconds)\n", diff);
                    printf("throughput=   %3.3f (Mbyte/sec)\n", throu);
		    fflush(stdout);
		    ens_Leave(memb);
                    exit(0);
                }
                break;
                
                // Got a new point-to-point message
            case SEND:
                EnsPanic("Got SEND");
                break;
                
                // Blocked in preparation for a view change
            case BLOCK:
                EnsLockTake(mutex);
                blocked=1;
                EnsLockRelease(mutex);

                if (memb->current_status != Leaving)
                    ens_BlockOk(my_memb);
                break;
                
            case EXIT:
                EnsPanic("Got EXIT");
                break;
            }
        }
    }
}

/**************************************************************/
static void Join()
{
    ens_jops_t jops;
    ens_member_t *memb;
    
    /* The rest of the fields should be zero. The
     * conversion code should be able to handle this. 
     */
    memset(&jops, 0, sizeof(ens_jops_t));
    strcpy(jops.group_name, group);
    strcpy(jops.properties, props);
//    strcpy(jops.params, "suspect_max_idle=5:int");
    
    memb = (ens_member_t*) EnsMalloc(sizeof(ens_member_t));
    memset(memb, 0, sizeof(ens_member_t));
    my_memb = memb;
        
    ens_Join(conn, memb, &jops, NULL);
}

/**************************************************************/
static void Usage(void)
{
    printf("options: \n");
    printf ("  -n <number of members>\n");
    printf ("  -s <size of message>\n");
    printf ("  -r <number of rounds>\n");
    printf ("  -prog <rpc|1-n>\n");
    printf ("  -port <port-number of ensembled daemon>\n");
    printf ("  -trace <module name>\n");
    printf ("  -group <group name>\n");
    printf ("  -add_prop <property>\n");
    fflush(stdout);
}

static void ProcessArgs(int argc, char **argv)
{
    int i;
    char **ret = NULL;
    int props_len =0;

    // Set the initial value of the property set
    memset(props, 0, ENS_PROPERTIES_MAX_SIZE);
    memset(group, 0, GROUP_NAME_SIZE);
    strncpy(group, "c_perf", GROUP_NAME_SIZE-1);
    strcpy(props, "Vsync");
    props_len = strlen(props);
    
    for (i=1;i<argc;i++) {
	if (strcmp(argv[i], "-n") == 0) {
	    if (++i >= argc){
		continue ;
	    }
	    nmembers = atoi(argv[i]);
	}
	else if (strcmp(argv[i], "-s") == 0) {
	    if (++i >= argc){
		continue ;
	    }
	    size = atoi(argv[i]);
	}
	else if (strcmp(argv[i], "-r") == 0) {
	    if (++i >= argc){
		continue ;
	    }
	    total_num_msgs = atoi(argv[i]);
	}
	else if (strcmp(argv[i], "-port") == 0) {
	    if (++i >= argc){
		continue ;
	    }
	    port = atoi(argv[i]);
	}
        else if (strcmp(argv[i], "-prog") == 0) {
	    if (++i >= argc){
		continue ;
	    }
            if (strcmp(argv[i], "1-n") == 0)
                prog = THROU;
            else if (strcmp(argv[i], "rpc") == 0)
                prog = RPC;
            else
                EnsPanic("No such performance test <%s>", argv[i]);
        }
        else if (strcmp(argv[i], "-trace") == 0) {
	    if (++i >= argc) {
		continue ;
	    }
	    EnsAddTrace(argv[i]) ;
	}
        else if (strcmp(argv[i], "-group") == 0) {
	    if (++i >= argc) {
		continue ;
	    }
	    if (strlen(argv[i]) >= GROUP_NAME_SIZE)
		EnsPanic("Group name too large, maximum is %d", (GROUP_NAME_SIZE-1));
	    strncpy(group, argv[i], GROUP_NAME_SIZE-1);
	}
	else if (strcmp(argv[i], "-add_prop") == 0) {
	    if (++i >= argc) {
		continue ;
	    }
	    props[props_len] = ':';
	    props_len++;
	    if (strlen(argv[i]) + props_len > ENS_PROPERTIES_MAX_SIZE)
		EnsPanic("Properties requested too large");
	    memcpy((char*)&props[props_len], argv[i], strlen(argv[i]));
	    props_len+=strlen(argv[i]);
	}
	else if ((strcmp(argv[i], "-help") == 0) ||
		 (strcmp(argv[i], "--help") == 0)) {
	    Usage();
	    exit(0);
	}
	else
	    EnsPanic("Unsupported command line options=<%s>", argv[i]);
    }

    if (size > ENS_MSG_MAX_SIZE)
        EnsPanic("message size too large, requested=%d, maximum=%d",
                 size, ENS_MSG_MAX_SIZE);

    printf("\n");
    printf (" nmembers=%d\n ", nmembers);
    printf (" rounds=%d\n", total_num_msgs);
    printf (" size=%d\n ", size);
    printf (" prog=%d\n ", prog);
    printf (" properties=%s\n ", props);
    printf (" group=%s\n", group);
}

int main(int argc, char **argv)
{
    ProcessArgs(argc, argv);
    
    // Allow the ML scripting engine to kill this program. 
    AllowAutoKill ();

    // initialize global variables
    mutex = EnsLockCreate();

    // connect to server
    conn = ens_Init (port);
    if (NULL == conn)
        EnsPanic("Error, could not open connection to server, exiting.");

    // Fixme, we should have a connect call.
    //conn.Connect();

    // Create an endpoint
    Join();

    // start listening to input from Ensemble
    switch (prog) {
    case THROU:
        ThrouMainLoop();
        break;
    case RPC:
        RpcMainLoop();
        break;
    default:
        EnsPanic("You must choose a one of the programs: [rcp|1-n]");
    }
    return 0;
}

/**************************************************************/
