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
typedef struct iov_t {
    int len;
    char *data;
} iov_t;

/**************************************************************/

#define RAND_PROPS    CE_DEFAULT_PROPERTIES ":XFER"

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
    ce_local_state_t *ls;
    ce_view_state_t *vs;
    ce_appl_intf_t *intf ;
    int blocked;
    double next ;
    int sent_xfer;
    int leaving;
} state_t;


static int thresh = 5;
static int nmembers = 5;
static int quiet = 0;

// This function is used prior to its definition. 
void join(void);

/**************************************************************/

// Return the next time to perform an action, and the type
// of action to perform.
void
policy (int rank, int nmembers, double *next /* OUT */, action_t *a /* OUT */) {
    int p = rand () % 100;
    
    *a = ANone;
    if (nmembers >= thresh) {
	if (p < 6)
	    *a= ALeave;
	else if (p < 9)
	    *a= APrompt;
	else if (p < 15)
	    *a= ASuspect;
	else if (p < 20)
	    *a= AProtocol;
	else if (p < 25)
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
#define MSG_SIZE 21

typedef struct msg_t {
    char digest[16];
    char *data;  
} msg_t;

void msg_free(msg_t *msg){
    free(msg->data);
    free(msg);
}

msg_t *
gen_msg(void)
{
    msg_t *msg;
    int i, x;
    char z[10];
    struct MD5Context ctx;
    
    msg = record_create(msg_t*, msg);
    msg->data = (char*) malloc(MSG_SIZE);
    memset(msg->data,0,MSG_SIZE);
    for (i=0; i<MSG_SIZE/sizeof(int); i++){
	x = rand ();
	sprintf(z,"%d",x);
	memcpy((char*)(msg->data + (i*sizeof(int))), z, sizeof(int));
    }
    if (rand () % 100 == 0) {
	printf("message= <");
	for(i=0; i<MSG_SIZE; i++)
	    printf("%c", msg->data[i]);
	printf(">\n");
    }
    
    ce_MD5Init(&ctx);
    ce_MD5Update(&ctx, msg->data, MSG_SIZE);
    ce_MD5Final(msg->digest, &ctx);
    
    return msg;
}

iov_t* marsh(msg_t *msg){
    iov_t *iov;
    
    iov=record_create(iov_t*, iov);
    
    iov->len=16 + MSG_SIZE;
    iov->data = (char*) malloc(iov->len);
    memcpy(iov->data, (char*)msg->data, MSG_SIZE);
    memcpy((char*) (iov->data + MSG_SIZE) , (char*)msg->digest, 16);
    
    return iov;
}

msg_t *unmarsh(iov_t *iov){
    msg_t *msg;
    
    msg = record_create(msg_t*, msg);
    memcpy(msg->digest, (char*)(iov->data + MSG_SIZE),  16);
    msg->data=malloc(MSG_SIZE);
    memcpy(msg->data, iov->data, MSG_SIZE);
    
    return msg;
}

void check_msg(msg_t *msg){
    struct MD5Context ctx;
    char new_digest[16];
    int i;
    
    //TRACE("checking msg");
    ce_MD5Init(&ctx);
    ce_MD5Update(&ctx, msg->data, MSG_SIZE);
    ce_MD5Final(new_digest, &ctx);
    if (memcmp(new_digest,msg->digest,16) != 0) {
	printf ("Bad message, wrong digest\n");
	printf("message=  ");
	for(i=0; i<MSG_SIZE; i++)
	    printf("%c", msg->data[i]);
	printf("\n");
	exit(1);
    }
}

void r_cast(
    ce_appl_intf_t *c_appl,
    msg_t *msg
    ) {
    iov_t *iov = marsh(msg);
    ce_flat_Cast(c_appl, iov->len, iov->data);
    msg_free(msg);
    free(iov);  // Don't free the iovec->data, it is consumed.
}

void r_send(
    ce_appl_intf_t *c_appl,
    int num,
    ce_rank_array_t dests,
    msg_t *msg
    ){
    iov_t *iov = marsh(msg);
    ce_flat_Send(c_appl, num, dests, iov->len, iov->data);
    msg_free(msg);
    free(iov); // Don't free the iovec->data, it is consumed.
}

void r_send1(
    ce_appl_intf_t *c_appl,
    ce_rank_t dest,
    msg_t *msg
    ){
    iov_t *iov = marsh(msg);
    ce_flat_Send1(c_appl, dest, iov->len, iov->data);
    msg_free(msg);
    free(iov); // Don't free the iovec->data, it is consumed.
}

int random_member(state_t *s){
    int rank ;
    
    rank = (rand ()) % (s->ls->nmembers) ;
    if (rank == s->ls->rank) 
	return random_member(s);
    else 
	return rank;
}

void block_msg (state_t *s) {
    TRACE("block_msg");
    if (rand() % 2 == 0) 
	r_cast(s->intf, gen_msg ());
    else
	r_send1(s->intf, random_member(s), gen_msg());
}


void action(void *env){
    state_t *s = (state_t*) env;
    action_t a;
    ce_rank_array_t dests;
    ce_rank_array_t suspects;
    char *proto;
    char *props;

    TRACE("action");
    //printf("blocked=%d\t xfer_view=%d\t leaving=%d\n",
    //s->blocked, s->vs->xfer_view, s->leaving);

/* This is to slow down Xfer Views. Otherwise, the
     * application starts to thrash.
     */
    if (s->vs->xfer_view != 0
//	&& rand () % nmembers == 0
	&& s->sent_xfer == 0
	&& s->leaving ==0) {
	TRACE2(s->ls->endpt,"XferDone");
	s->sent_xfer = 1;
	ce_XferDone(s->intf);
    }
    
    //      printf ("time=%3.3f next=%3.3f\n", time, s->next);
    
    if (/*time > s->next && */
	s->ls->nmembers >= thresh
	&& s->blocked == 0
	&& s->vs->xfer_view == 0
	&& s->leaving ==0) {
	policy(s->ls->rank, s->ls->nmembers, &(s->next), &a);
	
	switch (a) {
	case ACast:
	    TRACE("ACast");
	    r_cast (s->intf, gen_msg());
	    r_cast (s->intf, gen_msg());
	    break;
	    
	case ASend:
	    TRACE("ASend");
	    dests = (int*) malloc(2 * sizeof(int));
	    dests[0] = random_member(s);
	    dests[1] = random_member(s);
	    r_send(s->intf, 2, dests, gen_msg());
	    break;
	    
	case ASend1:
	    TRACE("ASend1");
	    r_send1(s->intf, random_member(s), gen_msg());
	    r_send1(s->intf, random_member(s), gen_msg());
	    r_send1(s->intf, random_member(s), gen_msg());
	    break;
	    
	case ALeave:
	    TRACE("ALeave");
	    r_cast(s->intf, gen_msg());
	    r_cast(s->intf, gen_msg());
	    r_cast(s->intf, gen_msg());
	    s->leaving = 1;
	    ce_Leave(s->intf);
	    
	    if (!quiet)
		printf("CE_RAND:%s:Leaving(nmembers=%d)\n", s->ls->endpt,  s->ls->nmembers);
	    break;
	    
	case APrompt:
	    TRACE("Prompting for a new view");
	    ce_Prompt(s->intf);
	    break;
	    
	case ASuspect:
	    TRACE("ASuspect");
	    suspects = (int*) malloc(2 * sizeof(int));
	    suspects[0] = random_member(s);
	    suspects[1] = random_member(s);
	    if (!quiet)
		printf ("%d, Suspecting %d and %d\n",
			s->ls->rank, suspects[0], suspects[1]);
	    ce_Suspect(s->intf, 2, suspects);
	    break;
	    
	case AProtocol:
	    TRACE("AProtocol");
	    proto = malloc(strlen(RAND_PROTO));
	    strcpy(proto, RAND_PROTO);
	    ce_ChangeProtocol(s->intf, proto);
	    break;
	    
	case AProperties:
	    TRACE("AProperties");
	    props = malloc(strlen(RAND_PROPS));
	    strcpy(props, RAND_PROPS);
	    ce_ChangeProperties(s->intf, props);
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
void main_heartbeat(void *env, double time){
    action(env);
}

/* A recursive function. When a member leaves, it immediately
 * re-joins.
 */
void main_exit(void *env){
    state_t *s = (state_t*) env;
    
    TRACE("CE_RAND:Rejoining");
    ce_view_full_free(s->ls,s->vs);
    free(s);
    join();
}


void main_install(void *env, ce_local_state_t *ls, ce_view_state_t *vs){
    state_t *s = (state_t*) env;
    int i;
    
    TRACE("main_install(");
    
    ce_view_full_free(s->ls,s->vs);
    s->ls = ls;
    s->vs = vs;
    s->blocked = 0;
    s->next = 0;
    s->sent_xfer = 0;
    s->leaving = 0;
    
    if (!quiet)
	if (s->ls->rank == 0) {
	    printf("CE_RAND:%s: View=(xfer=%d,nmembers=%d)  ",
		   s->ls->endpt, s->vs->xfer_view, ls->nmembers);
	    
	    printf("[");
	    for(i=0; i<s->ls->nmembers; i++)
		printf("%s|", s->vs->view[i]);
	    printf("]\n");
	}
    
//  TRACE2("main_install",s->ls->endpt);
    
    
    if (rand () % nmembers == 0) 
	r_cast(s->intf, gen_msg());
    
    TRACE(")");
}


void main_flow_block(void *env, ce_rank_t rank, ce_bool_t onoff){
///  state_t *s = (state_t*) env;
    
    //  TRACE2("main_flow_block",s->ls->endpt);
}

void main_block(void *env){
    state_t *s = (state_t*) env;
    int i;
    
//  printf("main_block\n"); fflush (stdout);
    s->blocked=1;
    
    if (s->ls->nmembers >= thresh
	&& s->vs->xfer_view == 0)
	for(i=1; i<=5; i++)
	    block_msg (s);
}

void main_recv_cast(void *env, int rank, int len, char *data) {
//  state_t *s = (state_t*) env;
    iov_t iov;
    msg_t *msg;
    
//  printf("main_recv_cast\n"); fflush (stdout);
    iov.len=len;
    iov.data=data;
    msg = unmarsh(&iov);
    check_msg(msg);
    msg_free(msg);
    action(env);
}

void main_recv_send(void *env, int rank, int len, char *data) {
//  state_t *s = (state_t*) env;
    iov_t iov;
    msg_t *msg;
    
//  printf("main_recv_send\n"); fflush (stdout);
    iov.len=len;
    iov.data=data;
    msg = unmarsh(&iov);
    check_msg(msg);
    msg_free(msg);
    action(env);
}


/**************************************************************/
void join(){
    ce_jops_t *jops; 
    ce_appl_intf_t *main_intf;
    state_t *s;
    
    /* The rest of the fields should be zero. The
     * conversion code should be able to handle this. 
     */
    jops = record_create(ce_jops_t*, jops);
    record_clear(jops);
    jops->transports = ce_copy_string("NETSIM");
//    jops->transports = ce_copy_string("DEERING");
    jops->group_name = ce_copy_string("ce_rand");
    jops->properties = ce_copy_string(RAND_PROPS) ;
    jops->use_properties = 1;
    jops->hrtbt_rate = 3.0;
    
    s = (state_t*) record_create(state_t*, s);
    record_clear(s);
    
    main_intf = ce_create_flat_intf(s,
				    main_exit, main_install, main_flow_block,
				    main_block, main_recv_cast, main_recv_send,
				    main_heartbeat);
    
    s->intf= main_intf;
    TRACE("Join(");
    ce_Join(jops,main_intf);
    TRACE(")");
}


void
fifo_process_args(int argc, char **argv){
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
	    if (strcmp(argv[i], "-t") == 0) {
		if (++i >= argc){
		    continue ;
		}
		
		thresh = atoi(argv[i]);
		printf ("thresh=%d\n", thresh);
	    } else 
		if (strcmp(argv[i], "-quiet") == 0) {
		    quiet = 1;
		    printf ("quiet\n");
		} else
		    ml_args++ ;
    }
    
    ret = (char**) malloc ((ml_args+3) * sizeof(char*));
    
    for(i=0, j=0; i<argc; i++) {
	if (strcmp(argv[i], "-n") == 0) {
	    i++;
	    continue;
	} else
	    if (strcmp(argv[i], "-t") == 0) {
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

int
main(int argc, char **argv)
{
    int i;
    
    fifo_process_args(argc, argv);
    
    for (i=0; i<nmembers; i++){
	join();
    }
    
    TRACE("starting the ce_Main_loop\n");
    ce_Main_loop ();
    return 0;
}


