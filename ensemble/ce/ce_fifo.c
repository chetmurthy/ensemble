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
/* CE_FIFO.C */
/* Author: Ohad Rodeh 8/2001 */
/* Based on demo/fifo.ml */
/**************************************************************/
#include "ce_trace.h"
#include "ce.h"
#include "mm_basic.h"
#include <stdio.h>
#include <stdlib.h>
#include <limits.h>
#include <memory.h>
#include <string.h>
/**************************************************************/
#define NAME "CE_FIFO"
/**************************************************************/
typedef struct iov_t {
    int len;
    char *data;
} iov_t;

//#define free(x)  printf("%s:freeing(", NAME); fflush(stdout); free(x); printf(")\n"); fflush(stdout);


/**************************************************************/

typedef struct state_t {
    int nmembers;
    int rank;
    ce_appl_intf_t *intf ;
    int blocked;
    /*let time     = ref Time.zero in
      let last_msg = ref Time.zero in */
    
} state_t;

//static int nrecd = 0;
//static int nsent = 0;
static int nmembers = 5;

#define IGNORE_SIZE 20

typedef struct msg_t{
    enum {
	TOKEN = 1,
	SPEW,
	F_IGNORE
    } type;
    union {
	struct {
	    ce_rank_t dest;
	    int seqno;
	} token;
	struct {
	    char buf[IGNORE_SIZE];
	} ignore;
    } u ;
    char opq[1000];
} msg_t;

static void fifo_recv_cast (state_t *s, ce_rank_t rank, msg_t *msg);
static void fifo_recv_send (state_t *s, ce_rank_t rank, msg_t *msg);

/**************************************************************/

static msg_t* token(ce_rank_t dest, int seqno)
{
    msg_t *msg;

    msg = (msg_t*) malloc(sizeof(msg_t));
    memset(msg, 0, sizeof(msg_t));
    msg->type = TOKEN;
    msg->u.token.dest=dest;
    msg->u.token.seqno=seqno;
    return msg;
}

static msg_t* spew(void)
{
    msg_t *msg;
    
    msg = (msg_t*) malloc(sizeof(msg_t));
    memset(msg, 0, sizeof(msg_t));
    msg->type = SPEW;
    return msg;
}

// buf should be a C-string.
//
static msg_t* ignore(char *buf)
{
    msg_t *msg;
    
    msg = (msg_t*) malloc(sizeof(msg_t));
    memset(msg, 0, sizeof(msg_t));
    msg->type = F_IGNORE;
    memcpy(msg->u.ignore.buf, buf, strlen(buf)); 
    return msg;
}

static const char* string_of_msg(msg_t *msg)
{
    char* s = NULL;
    
    switch (msg->type) {
    case TOKEN:
	s = "TOKEN";
	break;
	
    case SPEW:
	s = "SPEW";
	break;
	
    case F_IGNORE:
	s = "F_IGNORE";
	break;
    }
    return s;
}

static void send1(
    ce_appl_intf_t *c_appl,
    ce_rank_t dest,
    msg_t *msg
    )
{
    TRACE("send1");
    ce_flat_Send1(c_appl, dest, sizeof(msg_t), (char*)msg);
}

static void send2(
    ce_appl_intf_t *c_appl,
    ce_rank_t dest1,
    ce_rank_t dest2,
    msg_t *msg
    )
{
    int dests[2];

    TRACE("send2");
    dests[0] = dest1;
    dests[1] = dest2;
    ce_flat_Send(c_appl, 2, dests, sizeof(msg_t), (char*)msg);
}


static void cast(
    ce_appl_intf_t *c_appl,
    msg_t *msg
    )
{
    TRACE("cast");
    ce_flat_Cast(c_appl, sizeof(msg_t), (char*)msg);
}


static void main_recv_cast(void *env, int rank, int len, char* data)
{
    state_t *s = (state_t*) env;
    
    fifo_recv_cast (s, rank, (msg_t*)data);
}

static void main_recv_send(void *env, int rank, int len, char* data)
{
    state_t *s = (state_t*) env;
    fifo_recv_send (s, rank, (msg_t*)data);
}

/**************************************************************/
// Utitility functions

static int random_member(state_t *s)
{
    int rank ;
    
    if (nmembers == 1) {
	printf("Cannot send a message to myself\n");
	exit(1);
    }
    
    rank = (rand ()) % (s->nmembers) ;
    if (rank == s->rank) 
	return random_member(s);
    else 
	return rank;
}

// Return  a floating point number in the range [0 - 1].
static float float_rand(void)
{
    return (rand() / (float)INT_MAX);
}

/**************************************************************/

void do_action(state_t *s, int rank, msg_t *msg)
{
    int next ;
    
    if (s->blocked == 0)
	switch(msg->type){
	case TOKEN:
	    TRACE("TOKEN(");
	    if (msg->u.token.dest != s->rank) {
		printf("token arrived at an incorrect destination\n");
		exit(1);
	    } else {
		if (float_rand() < 0.1)
		    cast(s->intf, spew());
		
		next = random_member (s);
		send1(s->intf, next, token(next,(msg->u.token.seqno) + 1)) ;
		
		if (msg->u.token.seqno % 23 == 0) {
		    printf("FIFO:token=%d, %d->%d->%d\n",
			   msg->u.token.seqno, rank, s->rank, next);
		}
		TRACE(")");
	    }
	    break;
	    
	    
	case SPEW: 
	    if (float_rand() < 0.1) {
		send1(s->intf, random_member(s), ignore("junk"));
		send2(s->intf, random_member(s), random_member(s),ignore("junk"));
	    } else {
		cast(s->intf, ignore("junk"));
	    }
	    
	    break;
	    
	case F_IGNORE:
	    break;
	    
	default:
	    printf ("Error, bad message type\n");
	    exit(1);
	}
    TRACE(")");
}

/**************************************************************/

static void main_exit(void *env){}

static void main_install(void *env, ce_local_state_t *ls, ce_view_state_t *vs)
{
    state_t *s = (state_t*) env;
    int i;
    
    s->nmembers = ls->nmembers;
    s->rank = ls->rank;
    s->blocked = 0;
    TRACE_D("main_install",s->rank);
    
    printf("CE_FIFO: view=[");
    for(i=0; i<s->nmembers; i++)
	printf("%s|", vs->view[i].name);
    printf("]\n");

    if (s->rank ==0 && s->nmembers>=2){
//	printf("in first cast\n"); fflush(stdout);
//	TRACE("sending first cast");
	send1(s->intf, 1, token(1,0));
    }

//    TRACE("..:-)");
//    printf("completed install"); fflush(stdout);
}


static void main_flow_block(void *env, ce_rank_t rank, ce_bool_t onoff)
{
//    state_t *s = (state_t*) env;
    
//    TRACE_D("main_flow_block",s->rank);
}

static void main_block(void *env)
{
    state_t *s = (state_t*) env;
    
    s->blocked=1;
    TRACE_D("main_block",s->rank); 
}

static void fifo_recv_cast(state_t *s, int rank, msg_t *msg)
{
    TRACE_D("fifo_recv_cast(", s->rank);
    //  printf("recv_cast <- %d msg=%s\n", rank, msg_s);

    do_action(s, rank, msg);
}


static void fifo_recv_send(state_t *s, int rank, msg_t *msg)
{
    TRACE_D("fifo_recv_send", s->rank);
    do_action(s, rank, msg);
}

static void main_heartbeat(void *env, double time)
{}

/**************************************************************/
void join(void)
{
    ce_jops_t jops; 
    ce_appl_intf_t *main_intf;
    state_t *s;
    
    /* The rest of the fields should be zero. The
     * conversion code should be able to handle this. 
     */
    memset(&jops, 0, sizeof(ce_jops_t));
    memcpy(jops.transports, "NETSIM", strlen("NETSIM"));
    memcpy(jops.group_name, "ce_fifo", strlen("ce_fifo"));
    memcpy(jops.properties, CE_DEFAULT_PROPERTIES, strlen(CE_DEFAULT_PROPERTIES));
    jops.use_properties = 1;
    jops.hrtbt_rate = 1.0;
    
    s = (state_t*) malloc(sizeof(state_t));
    memset(s, 0, sizeof(state_t));
    
    main_intf = ce_create_flat_intf(s,
				    main_exit, main_install, main_flow_block,
				    main_block, main_recv_cast, main_recv_send,
				    main_heartbeat);
    
    s->intf= main_intf;
    ce_Join(&jops, main_intf);
}


void fifo_process_args(int argc, char **argv)
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
	    printf ("nmembers=%d\n", nmembers);
	} else 
	    ml_args++ ;
    }
    
    ret = (char**) malloc ((ml_args+3) * sizeof(char*));
    
    for(i=0, j=0; i<argc; i++) {
	if (strcmp(argv[i], "-n") == 0) {
	    i++;
	    continue;
	} else {
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
    
    ce_Main_loop ();
    return 0;
}

