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
/* CE_RAND.C: Randomly multicast/send messages and fail */
/* Author: Ohad Rodeh 8/2001 */
/* Based on demo/rand.ml */
/**************************************************************/
#include "ce_trace.h"
#include "ce.h"
#include "ce_md5.h"
#include <stdio.h>
#include <stdlib.h>
#include <limits.h>
#include <memory.h>
#include "ce_md5.h"
/**************************************************************/
#define NAME "CE_RAND"
/**************************************************************/
#define RAND_PROPS    CE_DEFAULT_PROPERTIES ":XFER:DEBUG"
#define MAX_MSG_SIZE  16000

#define MIN(x,y)  ((x) > (y) ? (y) : (x))

#define RAND_PROTO \
    "Top:Heal:Switch:Xfer:Leave:" \
    "Inter:Intra:Elect:Merge:Slander:Sync:Suspect:" \
    "Stable:Vsync:Frag_abv:Top_appl:" \
    "Frag:Pt2ptw:Mflow:Pt2pt:Mnak:Bottom"


typedef enum action_t {
    ACast,
    ASend,
    ASend1,
    ALeave,
    APrompt,
    ASuspect,
    // APPL_XFERDONE: no need for a specific test.
    // APPL_REKEY, TODO.
    AProtocol,
    AProperties,
    ANone
} action_t;

typedef struct state_t {
    int rank ;
    int nmembers;
    int xfer_view;
    ce_endpt_t endpt;
    ce_appl_intf_t *intf ;
    int blocked;
    double next ;
    int sent_xfer;
    int leaving;
} state_t;


static int thresh = 5;
static int nmembers = 5;
static int quiet = 0;
static int size = 17000 ;

// This function is used prior to its definition. 
void join(void);

/**************************************************************/

// Return the next time to perform an action, and the type
// of action to perform.
void
policy (int rank, int nmembers, double *next /* OUT */, action_t *a /* OUT */) {
    int p = rand () % 100;
    int q = rand () % (nmembers * 8) ;
    
    *a = ANone;
    if (nmembers >= thresh) {
	if (p < 6 && q==0 )
	    *a= ALeave;
	else if (p < 9 && q==0 )
	    *a= APrompt;
	else if (p < 15 && q==0 )
	    *a= ASuspect;
	else if (p < 20 && q==0 )
	    *a= AProtocol;
	else if (p < 25 && q==0 )
	    *a= AProperties;
	else if (p < 40)
	    *a = ACast;
	else if (p < 70)
	    *a = ASend1;
	else
	*a = ASend;
    } else
	*a = ANone;
    
    *next = (rand () % 100) * nmembers + *next;
}

/**************************************************************/
typedef struct msg_t {
    char digest[16];
    char data[MAX_MSG_SIZE];
} msg_t;

void gen_msg(/*OUT*/ msg_t **msg_o, int *len_o)
{
    msg_t *msg;
    int i, len;
    struct MD5Context ctx;

    len = rand () % size ;
    msg = (msg_t*) malloc(sizeof(msg_t) + size );
    memset(msg,0,sizeof(msg_t));
    for (i=0; i< len; i++) 
	msg->data[i] = 'a' + rand () % 25 ;
    if (rand () % 100 == 0) {
	printf("message= <");
	for(i=0; i< MIN(16, len); i++)
	    printf("%c", msg->data[i]);
	printf(">\n");
    }
    
    ce_MD5Init(&ctx);
    ce_MD5Update(&ctx, msg->data, len);
    ce_MD5Final(msg->digest, &ctx);
    
    *msg_o = msg;
    *len_o = 16+len;
}

void check_msg(int len, msg_t *msg)
{
    struct MD5Context ctx;
    char new_digest[16];
    int i;
    
    //TRACE("checking msg");
    ce_MD5Init(&ctx);
    ce_MD5Update(&ctx, msg->data, len - 16);
    ce_MD5Final(new_digest, &ctx);
    if (memcmp(new_digest,msg->digest,16) != 0) {
	printf ("Bad message, wrong digest\n");
	printf("message= (len=%d) ", len);
	for(i=0; i<MIN(16,len); i++)
	    printf("%c", msg->data[i]);
	printf("\n");
	exit(1);
    }
}

void r_cast(
    ce_appl_intf_t *c_appl
    )
{
    msg_t *msg;
    int len;

    gen_msg(&msg,&len);
    ce_flat_Cast(c_appl, len, (char*)msg);
}

void r_send(
    ce_appl_intf_t *c_appl,
    int num,
    ce_rank_array_t dests
    )
{
    msg_t *msg;
    int len;

    gen_msg(&msg,&len);
    ce_flat_Send(c_appl, num, dests, len, (char*)msg);
}

void r_send1(
    ce_appl_intf_t *c_appl,
    ce_rank_t dest
    )
{
    msg_t *msg;
    int len;

    gen_msg(&msg,&len);
    ce_flat_Send1(c_appl, dest, len, (char*)msg);
}

int random_member(state_t *s)
{
    int rank ;
    
    rank = (rand ()) % (s->nmembers) ;
    if (rank == s->rank)
	return random_member(s);
    else 
	return rank;
}

void block_msg (state_t *s)
{
    TRACE("block_msg");
    if (rand() % 2 == 0) 
	r_cast(s->intf);
    else
	r_send1(s->intf, random_member(s));
}


void action(void *env)
{
    state_t *s = (state_t*) env;
    action_t a;
    ce_rank_t dests[2];
    ce_rank_t suspects[2];

//    TRACE("action");
//    TRACE_GEN(("CE_RAND: blocked=%d\t xfer_view=%d\t leaving=%d\n",
//	       s->blocked, s->xfer_view, s->leaving));

/* This is to slow down Xfer Views. Otherwise, the
 * application starts to thrash.
 */
    if (s->xfer_view != 0
//	&& rand () % nmembers == 0
	&& s->sent_xfer == 0
	&& s->leaving ==0) {
	TRACE2(s->endpt.name,"XferDone");
	s->sent_xfer = 1;
	ce_XferDone(s->intf);
    }
    
    //      printf ("time=%3.3f next=%3.3f\n", time, s->next);
    
    if (/*time > s->next && */
	s->nmembers >= thresh
	&& s->blocked == 0
	&& s->xfer_view == 0
	&& s->leaving ==0) {
	policy(s->rank, s->nmembers, &(s->next), &a);
	
	switch (a) {
	case ACast:
	    TRACE("ACast");
	    r_cast (s->intf);
	    r_cast (s->intf);
	    break;
	    
	case ASend:
	    TRACE("ASend");
	    dests[0] = random_member(s);
	    dests[1] = random_member(s);
	    r_send(s->intf, 2, dests);
	    break;
	    
	case ASend1:
	    TRACE("ASend1");
	    r_send1(s->intf, random_member(s));
	    r_send1(s->intf, random_member(s));
	    r_send1(s->intf, random_member(s));
	    break;
	    
	case ALeave:
	    TRACE("ALeave");
	    r_cast(s->intf);
	    r_cast(s->intf);
	    r_cast(s->intf);
	    s->leaving = 1;
	    ce_Leave(s->intf);
	    
	    if (!quiet)
		printf("CE_RAND:%s:Leaving(nmembers=%d)\n", s->endpt.name,  s->nmembers);
	    break;
	    
	case APrompt:
	    TRACE("Prompting for a new view");
	    ce_Prompt(s->intf);
	    break;
	    
	case ASuspect:
	    TRACE("ASuspect");
	    suspects[0] = random_member(s);
	    suspects[1] = random_member(s);
	    if (!quiet)
		printf ("%d, Suspecting %d and %d\n",
			s->rank, suspects[0], suspects[1]);
	    ce_Suspect(s->intf, 2, suspects);
	    break;
	    
	case AProtocol:
	    TRACE("AProtocol");
	    ce_ChangeProtocol(s->intf, RAND_PROTO);
	    break;
	    
	case AProperties:
	    TRACE("AProperties");
	    ce_ChangeProperties(s->intf, RAND_PROPS);
	    break;
	    
	case ANone:
	    break;
	    
	default:
	    printf ("Error in action type\n");
	    exit(1);
	}
    }
}

/**************************************************************/
void main_heartbeat(void *env, double time)
{
//    TRACE("<hearbeat>");
    action(env);
}

/* A recursive function. When a member leaves, it immediately
 * re-joins.
 */
void main_exit(void *env)
{
    state_t *s = (state_t*) env;
    
    TRACE("CE_RAND:Rejoining");
    free(s);
    join();
}


void main_install(void *env, ce_local_state_t *ls, ce_view_state_t *vs)
{
    state_t *s = (state_t*) env;
    int i;
    
    TRACE("main_install(");
    
    s->rank = ls->rank;
    s->nmembers = ls->nmembers;
    s->xfer_view = vs->xfer_view;
    TRACE(".");
    memcpy(s->endpt.name, ls->endpt.name, CE_ENDPT_MAX_SIZE);
    TRACE(".");
    
    s->blocked = 0;
    s->next = 0;
    s->sent_xfer = 0;
    s->leaving = 0;
    
    TRACE(".");
    if (!quiet)
	if (ls->rank == 0) {
	    TRACE(".");
	    printf("CE_RAND:%s: View=(xfer=%d,nmembers=%d)  ",
		   ls->endpt.name, vs->xfer_view, ls->nmembers); fflush(stdout);
	    
	    printf("[");
	    for(i=0; i<ls->nmembers; i++)
		printf("%s|", vs->view[i].name);
	    printf("]\n");
	}
    
    TRACE2("main_install",s->endpt.name);
    
    
    if (rand () % nmembers == 0) 
	r_cast(s->intf);
    
    TRACE(")");
}


void main_flow_block(void *env, ce_rank_t rank, ce_bool_t onoff)
{
///  state_t *s = (state_t*) env;
    
    //  TRACE2("main_flow_block",s->ls->endpt.name);
}

void main_block(void *env){
    state_t *s = (state_t*) env;
    int i;
    
//  printf("main_block\n"); fflush (stdout);
    s->blocked=1;
    
    if (s->nmembers >= thresh
	&& s->xfer_view == 0)
	for(i=1; i<=5; i++)
	    block_msg (s);
    ce_BlockOk(s->intf);
}

void main_recv_cast(void *env, int rank, int len, char *data)
{
  state_t *s = (state_t*) env;
    msg_t *msg;
    
//  printf("main_recv_cast\n"); fflush (stdout);
    msg = (msg_t*) data;
    check_msg(len, msg);
    if (rand () % s->nmembers == 0)
	action(env);
}

void main_recv_send(void *env, int rank, int len, char *data)
{
  state_t *s = (state_t*) env;
    msg_t *msg;
    
//  printf("main_recv_send\n"); fflush (stdout);
    msg = (msg_t*) data;
    check_msg(len, msg);
    if (rand () % s->nmembers == 0)
	action(env);
}


/**************************************************************/
void join()
{
    ce_appl_intf_t *main_intf;
    state_t *s;
    ce_jops_t jops;
    
    /* The rest of the fields should be zero. The
     * conversion code should be able to handle this. 
     */
    memset(&jops, 0, sizeof(ce_jops_t));
    memcpy(jops.transports, "NETSIM", strlen("NETSIM"));; /*"DEERING"*/
    memcpy(jops.group_name, "ce_rand", strlen("ce_rand"));
    memcpy(jops.properties, RAND_PROPS, strlen(RAND_PROPS));
    jops.use_properties = 1;
    jops.hrtbt_rate = 3.0;
    jops.async_block_ok = 1;
    jops.debug = 1;
    
    s = (state_t*) malloc (sizeof(state_t));
    memset(s, 0, sizeof(state_t));
    
    main_intf = ce_create_flat_intf(s,
				    main_exit, main_install, main_flow_block,
				    main_block, main_recv_cast, main_recv_send,
				    main_heartbeat);
    
    s->intf= main_intf;
    TRACE("Join(");
    ce_Join(&jops,main_intf);
    TRACE(")");
}


void
fifo_process_args(int argc, char **argv)
{
    int i,j ;
    int ml_args=0;
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
	else if (strcmp(argv[i], "-s") == 0) {
	    if (++i >= argc){
		continue ;
	    }
	    size = atoi(argv[i]);
	    printf (" size =%d ", size);
	    if (size > MAX_MSG_SIZE) {
		printf("message size too large, requested=%d, maximum=%d",
		       size, MAX_MSG_SIZE);
		exit(1);
	    }
	}
	else
	    ml_args++ ;
    }
    printf("\n");
    
    ret = (char**) malloc ((ml_args+3) * sizeof(char*));
    
    for(i=0, j=0; i<argc; i++) {
	if (strcmp(argv[i], "-n") == 0
	    || strcmp(argv[i], "-t") == 0
	    || strcmp(argv[i], "-s") == 0
	    || strcmp(argv[i], "-quiet") == 0)
	{
	    i++;
	    continue;
	}
	else {
	    ret[j]=argv[i];
	    j++;
	}
    }
//    ret[ml_args] = NULL;
    ret[ml_args] = "-alarm";
    ret[ml_args+1] = "Netsim";
    ret[ml_args+2] = NULL;
    
/* Call Arge.parse, and appl_process_args */	  
    ce_Init(ml_args+2, ret); 
//    ce_Init(ml_args, ret); 
}

int main(int argc, char **argv)
{
    int i;

    ce_set_alloc_fun((mm_alloc_t)malloc);
    ce_set_free_fun((mm_free_t)free);

    fifo_process_args(argc, argv);
    
    for (i=0; i<nmembers; i++){
	join();
    }
    
    TRACE("starting the ce_Main_loop\n");
    ce_Main_loop ();
    return 0;
}


