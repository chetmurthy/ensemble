/**************************************************************/
/* CE_RAND.C: Randomly multicast/send messages and fail */
/* Author: Ohad Rodeh 8/2001 */
/* Based on demo/rand.ml */
/**************************************************************/
#include "ens_utils.h"
#include "ens.h"
#include "ens_threads.h"
#include "md5.h"
#include <stdio.h>
#include <stdlib.h>
#include <limits.h>
#include <memory.h>
#include <assert.h>
/**************************************************************/
#define NAME "C_RAND"
#define NAME2 "C_RAND2"
/**************************************************************/
#define RAND_PROPS        ENS_DEFAULT_PROPERTIES
#define MAX_NUM_MEMBERS   7

#define MIN(x,y)  ((x) > (y) ? (y) : (x))

typedef enum action_t {
    ACast,
    ASend,
    ASend1,
    ALeave,
    ASuspect,
    ANone
} action_t;

typedef enum {
    SEND_MSG,
    CAST_MSG,
} cast_or_send_t;

typedef struct state_t {
    int index;
    int got_block;
    int blocked;
    int got_leave;
    int leaving;
    int valid;
    ens_member_t *memb ;

    int xmit_cast;
    int xmit_send_a[MAX_NUM_MEMBERS];
    int recv_cast_a[MAX_NUM_MEMBERS];
    int recv_send_a[MAX_NUM_MEMBERS];
} state_t;

typedef struct stats_t {
    int num_cast;
    int num_send;
    int num_leave;
} stats_t;

typedef struct msg_t {
    char digest[16];
    int  tags[MAX_NUM_MEMBERS];
    char data[ENS_MSG_MAX_SIZE];
} msg_t;

/**************************************************************/

static action_t Policy (int rank, int nmembers);
static void     RandomAction(state_t *s);
static int      GenMsg(state_t *s, cast_or_send_t cs, int dest1, int dest2);
static void     CheckMsg(state_t *s,
                         int len,
                         int source,
                         cast_or_send_t cs,
                         msg_t *msg_buffer);
    
static void     RCast(state_t *s);
static void     RSend(state_t *s, int dest1, int dest2);
static void     RSend1(state_t *s, int dest);
static int      RandomMember(ens_member_t *memb);
static void     GotBlockMsg (state_t *s);
static void     Join(int i);

static void     ProcessArgs(int argc, char **argv);
static void     MainLoop(void);

/**************************************************************/
static int thresh = 5;
static int nmembers = 5;
static int quiet = 0;
static int size = 1000 ;
static int port = ENS_SERVER_TCP_PORT;

// Connection to server
static ens_conn_t *conn = NULL;

// a static view structure to receive views into
static ens_view_t view;

// A static buffer for receving messages.
static char msg_send_buffer[ENS_MSG_MAX_SIZE];

static state_t state_a[MAX_NUM_MEMBERS];

static ens_lock_t *mutex = NULL;

/**************************************************************/

// Return the next time to perform an action, and the type
// of action to perform.
static action_t Policy (int rank, int nmembers)
{
    action_t a = ANone;
    
    int p = rand () % 100;
    int q = rand () % (nmembers * 8) ;
    
    if (p < 2 && q==0 )
        a= ALeave;
	else  if (p < 4 && q==0 )
        a= ASuspect; 
    else if (p < 40)
        a = ACast; 
    else if (p < 70)
        a = ASend1;
    else
        a = ASend;
    
    return a;
}

/**************************************************************/
static int GenMsg(state_t *s, cast_or_send_t cs, int dest1, int dest2)
{
    msg_t *msg;
    int i, len;
    struct MD5Context ctx;

    if (size>0) 
        len = rand () % size;
    else
        len = 0;
    msg = (msg_t*) msg_send_buffer;
    memset((char*)msg, 0, 16 + MAX_NUM_MEMBERS*sizeof(int) + len);
    
    // stick the current sequence number on this message
    switch (cs){
    case CAST_MSG:
        msg->tags[0] = s->xmit_cast++;
        EnsTrace(NAME2, "source=%d  xmit_cast=%d\n", s->memb->rank, s->xmit_cast-1);
        break;
    case SEND_MSG:
        msg->tags[dest1] = s->xmit_send_a[dest1]++;
        EnsTrace(NAME2, "source=%d  xmit_send[%d]=%d\n",
                 s->memb->rank, dest1, s->xmit_send_a[dest1]-1);
        if (dest2 != -1) {
            assert(dest2 != dest1);
            msg->tags[dest2] = s->xmit_send_a[dest2]++;
            EnsTrace(NAME2, "source=%d  xmit_send[%d]=%d\n",
                     s->memb->rank, dest2, s->xmit_send_a[dest2]-1);
        }
        break;
    default:
        EnsPanic("bad case");
    }
        
    for (i=0; i< len; i++) 
	msg->data[i] = 'a' + rand () % 25 ;

    if (rand () % 100 == 0) {
	printf("message= <");
	for(i=0; i< MIN(20, len); i++)
	    printf("%c", msg->data[i]);
	printf(">\n");
        fflush(stdout);
    }
    
    MD5Init(&ctx);
    MD5Update(&ctx, (char*)msg_send_buffer+16, MAX_NUM_MEMBERS*sizeof(int) + len);
    MD5Final(msg->digest, &ctx);
    
    return 16+MAX_NUM_MEMBERS*sizeof(int)+len;
}

static void CheckMsg(state_t *s,
                     int len,
                     int source,
                     cast_or_send_t cs,
                     msg_t *msg)
{
    struct MD5Context ctx;
    char new_digest[16];
    int i, tag;
    
    EnsTrace(NAME2, "checking msg (len=%d) cast_or_send=%d  source=%d",
             len, cs, source);
    MD5Init(&ctx);
    MD5Update(&ctx, (char*)msg+16, len - 16);
    MD5Final(new_digest, &ctx);
    if (memcmp(new_digest,msg->digest,16) != 0) {
	printf ("Bad message, wrong digest\n");
	printf("message= (len=%d) <", len);
	for(i=0; i<MIN(50,len); i++)
	    printf("%c", msg->data[i]);
        printf(">\n");
	exit(1);
    }

    // Check the integer on the msg
    switch(cs){
    case CAST_MSG:
        tag = msg->tags[0];
        EnsTrace(NAME2, "recv-CAST: my_rank=%d source=%d tag=%d expect=%d",
                 s->memb->rank, source, tag, s->recv_cast_a[source]);
        if ((s->recv_cast_a[source]) != tag)
            EnsPanic("Cast: bad message tag received, got=%d expecting=%d source=%d",
                     tag, s->recv_cast_a[source], source);
        s->recv_cast_a[source]++;
        break;
    case SEND_MSG:
        tag = msg->tags[s->memb->rank];
        EnsTrace(NAME2, "recv-SEND: my_rank=%d source=%d tag=%d expect=%d",
                 s->memb->rank, source, tag, s->recv_send_a[source]);
        if ((s->recv_send_a[source]) != tag)
            EnsPanic("Send: bad message tag received, got=%d expecting=%d, source=%d dest=%d",
                     tag, s->recv_send_a[source], source, s->memb->rank);
        s->recv_send_a[source]++;
        break;
    default:
        EnsPanic("Error");
    }
}


static void RCast(state_t *s)
{
    int len;
    
    len = GenMsg(s, CAST_MSG, -1, -1);
//        printf("cast: source=%d tag=%d\n", s->memb->rank, s->xmit_cast-1);
    ens_Cast(s->memb, len, (char*)msg_send_buffer);
}

static void RSend(state_t *s, int dest1, int dest2)
{
    int len;
    int dests[2];
    dests[0] = dest1;
    dests[1] = dest2;
    
    len = GenMsg(s, SEND_MSG, dest1, dest2);
    ens_Send(s->memb, 2, dests, len, (char*)msg_send_buffer);
}

static void RSend1(state_t *s, int dest)
{
    int len;
    
    len = GenMsg(s, SEND_MSG, dest, -1);
    ens_Send1(s->memb, dest, len, (char*)msg_send_buffer);
}

static int RandomMember(ens_member_t *memb)
{
    int rank ;
    
    rank = (rand ()) % (memb->nmembers) ;
    if (rank == memb->rank)
	return RandomMember(memb);
    else 
	return rank;
}

static void GotBlockMsg (state_t *s)
{
//    EnsTrace("block_msg");
    if ( s->memb->current_status == Normal &&
         s->memb->nmembers >= thresh ) {
        if (rand() % 2 == 0) 
            RCast(s);
        else
            RSend1(s, RandomMember(s->memb));
    }
}

static void RandomAction(state_t *s)
{
    action_t a;
    int suspects[2];
    int dest1;
    int dest2;

    if ( s->memb->current_status == Normal &&
         s->memb->nmembers >= thresh
        ) {
	a = Policy(s->memb->rank, s->memb->nmembers);
	
	switch (a) {
	case ACast:
	    EnsTrace(NAME,"ACast");
	    RCast (s);
	    break;
	    
	case ASend:
	    EnsTrace(NAME,"ASend");
            dest1 = RandomMember(s->memb);
            dest2 = RandomMember(s->memb);
            if (dest1 != dest2) 
                RSend(s, dest1, dest2);
            else
                RSend1(s, dest1);
	    break;
	    
	case ASend1:
	    EnsTrace(NAME,"ASend1");
	    RSend1(s, RandomMember(s->memb));
	    break;
	    
	case ALeave:
	    EnsTrace(NAME,"ALeave");
	    RCast(s);
	    RCast(s);

            EnsLockTake(mutex);
            s->got_leave = 1;
            EnsLockRelease(mutex);
	    
	    if (!quiet)
		printf("C_RAND:%d:Leaving(nmembers=%d)\n",
                       s->memb->rank, s->memb->nmembers);
	    break;
	    
	case ASuspect:
	    EnsTrace(NAME,"ASuspect");
	    suspects[0] = RandomMember(s->memb);
	    suspects[1] = RandomMember(s->memb);
	    if (!quiet)
		printf ("%d, Suspecting %d and %d\n",
			s->memb->rank, suspects[0], suspects[1]);
	    ens_Suspect(s->memb, 2, suspects);
	    break;
	    
	case ANone:
	    break;
	    
	default:
	    EnsPanic("Error in action type");
	}
    }
}

static void GenActionThread (void* _memb)
{
    state_t *s;
    int got_block;
    int blocked;
    int got_leave;
    int leaving;
    int valid;
    int i;
    
    // Wait for things to start up
    EnsSleepMilli(1000);

    // Loop over all endpoints and perform random actions
    while (1) {
	// Slow things down a little bit
        if (rand () % 2 == 0)
            EnsSleepMilli(20);
	
	for (i=0; i<nmembers; i++) {
	    s = &state_a[i];

	    if (s->memb == NULL) continue;

	    EnsLockTake(mutex);
	    got_block= s->got_block;
	    blocked = s->blocked;
            got_leave = s->got_leave;
            leaving = s->leaving;
            valid = s->valid;
	    EnsLockRelease(mutex);
	    
            if (valid) {
                // If we aren't blocked then generate an action
                if (!got_block && !blocked && !leaving) {
                    RandomAction(s);
                }
                else {
		    // We need to send BlockOk
		    if (got_block &&
			!blocked &&
			!leaving ) {
			GotBlockMsg(s);
			
			EnsLockTake(mutex);
			s->blocked= 1;
			EnsLockRelease(mutex);
			
			ens_BlockOk(s->memb);
		    }
		    // We need to send a Leave
		    if (got_leave && !leaving && !got_block) {
			EnsLockTake(mutex);
			s->leaving = 1;
			s->valid = 0;
			EnsLockRelease(mutex);
			
			ens_Leave(s->memb);
		    }
		}
	    }
	}
    }
}

/**************************************************************/
void Join(int i)
{
    ens_member_t *memb;
    ens_jops_t jops;
    state_t *s;
    
    /* The rest of the fields should be zero. The
     * conversion code should be able to handle this. 
     */
    memset(&jops, 0, sizeof(ens_jops_t));
    strcpy(jops.group_name, "c_rand");
    strcpy(jops.properties, RAND_PROPS);
    
    memb = (ens_member_t*) EnsMalloc(sizeof(ens_member_t));
    memset(memb, 0, sizeof(ens_member_t));
    s = &state_a[i];
    
    ens_Join(conn, memb, &jops, s);
    s->memb = memb;
    s->got_block = 0;
    s->blocked = 1;
    s->got_leave=0;
    s->leaving=0;
    s->index=i;
    s->xmit_cast= 0;
    memset((char*)s->xmit_send_a, 0, sizeof(int) * MAX_NUM_MEMBERS);
    memset((char*)s->recv_cast_a, 0, sizeof(int) * MAX_NUM_MEMBERS);
    memset((char*)s->recv_send_a, 0, sizeof(int) * MAX_NUM_MEMBERS);
    
    EnsLockTake(mutex);
    s->valid = 1;
    EnsLockRelease(mutex);
}


static void RecvMainLoop(void) 
{
    int data_available;
    ens_rc_t rc;
    ens_msg_t msg;
    int msg_size;
    int origin;
    int i, n;
    ens_member_t *memb;
    state_t *s;
    int count=0;
    int day, hour, min, sec;
	
    // A buffer for receving messages.
    msg_t msg_buffer;

    while(1) 
    {
        // Read all waiting messages from Ensmeble
        rc = ens_Poll(conn, 1000, &data_available);

	EnsGetUptime(&day, &hour, &min, &sec);
	//printf("C_RAND:uptime=<%dd:%dh:%dm:%ds>", day, hour, min, sec );
	    
        if (ENS_ERROR == rc)
            EnsPanic("Error polling for data.");

        if (data_available) {
            rc = ens_RecvMetaData(conn, &msg);

            if (ENS_ERROR == rc)
                EnsPanic("Error while receving meta-data");

            memb = msg.memb;
            s = memb->user_ctx;
                
            switch(msg.mtype) {
                // Got a new view
            case VIEW:
                // Re-Initialize the view structure
                n = msg.u.view.nmembers;
                if (view.address != NULL) free(view.address);
                if (view.endpts != NULL) free(view.endpts);
                view.address = EnsMalloc(ENS_ADDR_MAX_SIZE * n);
                view.endpts = EnsMalloc(ENS_ENDPT_MAX_SIZE * n);

                rc = ens_RecvView(conn, memb, &view);
                if (ENS_ERROR == rc)
                    EnsPanic("Could not receive the view");

//                printf("<---\n"); fflush(stdout);
//                EnsTrace(NAME, "Erasing old counters source=%d id=%d",
//                         memb->rank, s->index);
                s->xmit_cast= 0;
                memset((char*)s->xmit_send_a, 0, sizeof(int) * MAX_NUM_MEMBERS);
                memset((char*)s->recv_cast_a, 0, sizeof(int) * MAX_NUM_MEMBERS);
                memset((char*)s->recv_send_a, 0, sizeof(int) * MAX_NUM_MEMBERS);

                // Print the new view
                printf("new view:\n");
                printf("\t nmembers=%d rank=%d\n", view.nmembers, view.rank);
                printf("\t view=[");
                for (i=0; i<view.nmembers; i++) {
                    printf("%s:", view.endpts[i].name);
                }
                printf ("]\n");
//                printf("--->\n"); fflush(stdout);
                fflush(stdout);

		EnsLockTake(mutex);
		s->blocked = 0;
		s->got_block = 0;
		EnsLockRelease(mutex);
                break;

                // Got a new multicast message
            case CAST:
                msg_size = msg.u.cast.msg_size;
                rc = ens_RecvMsg(conn, &origin, (char*)&msg_buffer);
                if (ENS_ERROR == rc)
                    EnsPanic("Error in receving a multicast message");
                CheckMsg(s, msg_size, origin, CAST_MSG, &msg_buffer);
                break;

                // Got a new point-to-point message
            case SEND:
                msg_size = msg.u.send.msg_size;
                rc = ens_RecvMsg(conn, &origin, (char*)&msg_buffer);
                if (ENS_ERROR == rc)
                    EnsPanic("Error in receving a point-to-point message");
                CheckMsg(s, msg_size, origin, SEND_MSG, &msg_buffer);
                break;

                // Blocked in preparation for a view change
            case BLOCK:
                EnsTrace(NAME, "BLOCK");
		EnsLockTake(mutex);
		s->got_block=1;
		EnsLockRelease(mutex);
                break;

            case EXIT:
                EnsTrace(NAME,"Got EXIT");
                free(msg.memb);
                Join(s->index);
                break;
            }
        }
    }
}

/**************************************************************/
static void ProcessArgs(int argc, char **argv)
{
    int i;
    char **ret = NULL;
    
    for (i=0;i<argc;i++) {
	if (strcmp(argv[i], "-n") == 0) {
	    if (++i >= argc){
		continue ;
	    }
	    nmembers = atoi(argv[i]);
	    printf (" nmembers=%d ", nmembers);
	}
	else if (strcmp(argv[i], "-t") == 0) {
	    if (++i >= argc){
		continue ;
	    }
	    thresh = atoi(argv[i]);
	    printf (" thresh=%d ", thresh);
	}
	else if (strcmp(argv[i], "-quiet") == 0) {
	    quiet = 1;
	    printf ("quiet ");
	}
	else if (strcmp(argv[i], "-port") == 0) {
	    if (++i >= argc){
		continue ;
	    }
	    port = atoi(argv[i]);
	    printf (" port=%d ", port);
	}
	else if (strcmp(argv[i], "-s") == 0) {
	    if (++i >= argc){
		continue ;
	    }
	    size = atoi(argv[i]);
	    printf (" size=%d ", size);
	}
        else if (strcmp(argv[i], "-trace") == 0) {
	    if (++i >= argc) {
		continue ;
	    }
	    EnsAddTrace(argv[i]) ;
	} 
    }

    if (size > (ENS_MSG_MAX_SIZE-1000)) {
        printf("message size too large, requested=%d, maximum=%d",
               size, (ENS_MSG_MAX_SIZE-1000));
        exit(1);
    }
    if (nmembers > MAX_NUM_MEMBERS) {
        printf("too many members, requested=%d, maximum=%d",
               size, MAX_NUM_MEMBERS);
        exit(1);
    }
    printf("\n");
}

int main(int argc, char **argv)
{
    int i;

    ProcessArgs(argc, argv);
    
    memset(state_a, 0, MAX_NUM_MEMBERS * sizeof(state_t));
    mutex = EnsLockCreate();
    
    // connect to server
    conn = ens_Init (port);
    if (NULL == conn)
        EnsPanic("Error, could not open connection to server, exiting.");

    // Fixme, we should have a connect call.
    //conn.Connect();

    // Create an initial set of members
    for (i=0; i<nmembers; i++)
	Join(i);

    EnsThreadCreate( GenActionThread, NULL);
    
    // start listening to input from Ensemble
    RecvMainLoop();
    return 0;
}

/**************************************************************/


