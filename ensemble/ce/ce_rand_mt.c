/**************************************************************/
/* CE_RAND_MT.C: Randomly create actions */
/* Author: Ohad Rodeh 8/2001 */
/* This is the multi-threaded version */
/**************************************************************/
#include "ce_trace.h"
#include "ce.h"
#include "ce_md5.h"
#include "ce_threads.h"
#include <stdio.h>
#include <stdlib.h>
#include <limits.h>
#include <memory.h>
#include "ce_md5.h"

/* For computing the uptime
 */
#ifndef _WIN32
#include <sys/types.h>
#include <sys/time.h>
#endif

/**************************************************************/
#define NAME "CE_RAND_MT"
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


typedef enum {
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

typedef enum {
    Joining,
    Blocked,
    Normal,
    Leaving,
    LeaveDone
} status_t ;

typedef struct state_t {
    ce_local_state_t *ls;
    ce_view_state_t *vs;
    ce_appl_intf_t *intf ;
    double next ;
    int sent_xfer;
    status_t status;
    ce_lck_t *mutex;
    int id ;           /* This thread id */
} state_t;


static int id_cnt = 0;
static int thresh = 5;
static int nmembers = 5;
static int quiet = 0;

// This function is used prior to its definition. 
void join(void);
//void rejoin(state_t *s);
/**************************************************************/
/* Update the total running time
 */
#ifndef _WIN32
void
get_uptime(int *day, int *hour, int *min, int *sec)
{
    struct timeval tv;
    static int first_time = 1;
    static int initial_time = 0;
    
    if (gettimeofday(&tv,NULL) == -1)
	perror("Could not get the time of day");

    if (first_time){
	initial_time = tv.tv_sec;
	first_time = 0;
	*day = 0;
	*hour = 0;
	*min = 0;
	*sec = 0;
    } else {
	int diff= tv.tv_sec - initial_time;
	*sec = diff % 60;
	*min = (diff % (60 * 60)) / 60;
	*hour = (diff % (60*60*24)) / (60*60);
	*day = (diff % (60*60*24*365)) / (60*60*24);
    }
}
#else
void
get_uptime(int *day, int *hour, int *min, int *sec)
{
    static int first_time = 1;
    static unsigned int initial_time;
    
    if (initial_time == 0) {
	initial_time = GetTickCount() / 1000;
	first_time = 0;
	*day = 0;
	*hour = 0;
	*min = 0;
	*sec = 0;
    } else {
	int diff= (GetTickCount() / 1000) - initial_time;
	*sec = diff % 60;
	*min = (diff % (60 * 60)) / 60;
	*hour = (diff % (60*60*24)) / (60*60);
	*day = (diff % (60*60*24*365)) / (60*60*24);	
    }
}

#endif

/**************************************************************/

// Return the next time to perform an action, and the type
// of action to perform.
void
policy (int rank, int nmembers, double *next /* OUT */, action_t *a /* OUT */) {
    int p = rand () % 100;
    int q = rand () % nmembers ;
    
    *a = ANone;
    if (nmembers >= thresh) {
	if (p < 6 && q == 0 )
	    *a= ALeave; 
	else if (p < 9 && q == 0)
	    *a= APrompt;
	else if (p < 15 && q == 0)
	    *a= ASuspect;
	else if (p < 20 && q == 0)
	    *a= AProtocol;
	else if (p < 25 && q == 0)
	    *a= AProperties;
	else if (p < 40)
	    *a = ACast;
	else if (p < 70)
	    *a = ASend;
	else 
	    *a = ASend1;
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
//    TRACE("r_cast(");
    ce_trace(NAME, "CAST (id=%x)", (int)c_appl);
    ce_flat_Cast(c_appl, iov->len, iov->data);
//    TRACE(")");
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
//    TRACE("r_send(");
    ce_trace(NAME, "SEND (id=%x)", (int)c_appl);
    ce_flat_Send(c_appl, num, dests, iov->len, iov->data);
    msg_free(msg);
    free(iov); // Don't free the iovec->data, it is consumed.
//    TRACE(")");
}

void r_send1(
    ce_appl_intf_t *c_appl,
    ce_rank_t dest,
    msg_t *msg
    ){
    iov_t *iov = marsh(msg);
    ce_trace(NAME, "SEND1 (id=%x)", (int)c_appl);
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
    TRACE_D("block_msg", s->id);
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
    
    //printf("blocked=%d\t xfer_view=%d\t leaving=%d\n",
    //s->blocked, s->vs->xfer_view, s->leaving);
    
    /* This is to slow down Xfer Views. Otherwise, the
     * application starts to thrash.
     */
    if (s->vs->xfer_view != 0
//	&& rand () % nmembers == 0
	&& s->sent_xfer == 0
	&& s->status == Normal) {
	ce_trace(NAME, "%d:XferDone(%s)", s->ls->rank, s->ls->endpt);
	s->sent_xfer = 1;
	ce_XferDone(s->intf);
    }
    
    //      printf ("time=%3.3f next=%3.3f\n", time, s->next);
    
    if (/*time > s->next && */
	s->ls->nmembers >= thresh
	&& s->status == Normal
	&& s->vs->xfer_view == 0){
	policy(s->ls->rank, s->ls->nmembers, &(s->next), &a);
//	TRACE("action");
	
	switch (a) {
	case ACast:
	    TRACE_D("ACast", s->id);
	    r_cast (s->intf, gen_msg());
	    r_cast (s->intf, gen_msg());
	    break;
	    
	case ASend:
	    TRACE_D("ASend", s->id);
	    dests = (int*) malloc(2 * sizeof(int));
	    dests[0] = random_member(s);
	    dests[1] = random_member(s);
	    r_send(s->intf, 2, dests, gen_msg());
	    break;
	    
	case ASend1:
	    TRACE_D("ASend1", s->id);
	    r_send1(s->intf, random_member(s), gen_msg());
	    r_send1(s->intf, random_member(s), gen_msg());
	    r_send1(s->intf, random_member(s), gen_msg());
	    break;
	    
	case ALeave:
	    TRACE_D("ALeave", s->id);
	    r_cast(s->intf, gen_msg());
	    r_cast(s->intf, gen_msg());
	    r_cast(s->intf, gen_msg());
	    ce_trace(NAME, "leaving (ptr=%x)", (int)s->intf);
	    TRACE_D("leaving ", s->id);
	    s->status = Leaving;
	    if (!quiet)
		printf("CE_RAND_MT:%s:Leaving(nmembers=%d)\n", s->ls->endpt,  s->ls->nmembers);
	    ce_Leave(s->intf);
	    
	    break;
	    
	case APrompt:
	    TRACE_D("Prompting for a new view", s->id);
	    ce_Prompt(s->intf);
	    break;
	    
	case ASuspect:
	    TRACE_D("ASuspect", s->id);
	    suspects = (int*) malloc(2 * sizeof(int));
	    suspects[0] = random_member(s);
	    suspects[1] = random_member(s);
	    if (!quiet)
		printf ("%d, Suspecting %d and %d\n",
			s->ls->rank, suspects[0], suspects[1]);
	    ce_Suspect(s->intf, 2, suspects);
	    break;
	    
	case AProtocol:
	    TRACE_D("AProtocol", s->id);
	    proto = malloc(strlen(RAND_PROTO));
	    strcpy(proto, RAND_PROTO);
	    ce_ChangeProtocol(s->intf, proto);
	    break;
	    
	case AProperties:
	    TRACE_D("AProperties", s->id);
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
void main_heartbeat(void *env, double time){}
    

/* A recursive function. When a member leaves, it immediately
 * re-joins.
 */
void main_exit(void *env){
    state_t *s = (state_t*) env;
    
    ce_view_full_free(s->ls,s->vs);
    s->ls = NULL;
    s->vs = NULL;
    s->status = LeaveDone;
    TRACE_D("LeaveDone ", s->id);
}


void main_install(void *env, ce_local_state_t *ls, ce_view_state_t *vs){
    state_t *s = (state_t*) env;
    int i;
    
//    ce_trace(NAME,"%d:main_install(", ls->rank);
//    TRACE("main_install(")
    
    ce_lck_Lock(s->mutex);{
	ce_view_full_free(s->ls,s->vs);
	s->ls = ls;
	s->vs = vs;
	if (s->status == Joining
	    || s->status == Blocked) {
	    TRACE_D("Normal ", s->id);
	    s->status = Normal ;
	}
	s->next = 0;
	s->sent_xfer = 0;
    } ce_lck_Unlock(s->mutex);
    
    if (!quiet)
	if (s->ls->rank == 0) {
	    int day, hr, min, sec;
	    get_uptime(&day,&hr,&min,&sec);
	    printf("CE_RAND_MT:%s: View=(uptime=<%dd:%dh:%dm:%ds>,xfer=%d,nmembers=%d)  ",
		   s->ls->endpt, day, hr, min, sec,
		   s->vs->xfer_view, ls->nmembers);
	    
	    printf("[");
	    for(i=0; i<s->ls->nmembers; i++)
		printf("%s|", s->vs->view[i]);
	    printf("]\n");
	}
    
//  TRACE2("main_install",s->ls->endpt);

    ce_lck_Lock(s->mutex);{
	if (s->status == Normal)
	    if (rand () % nmembers == 0) 
		r_cast(s->intf, gen_msg());
    } ce_lck_Unlock(s->mutex);

    
//    TRACE(")");
}


void main_flow_block(void *env, ce_rank_t rank, ce_bool_t onoff){
///  state_t *s = (state_t*) env;
    
    //  TRACE2("main_flow_block",s->ls->endpt);
}

void main_block(void *env){
    state_t *s = (state_t*) env;
    int i;
    
//    TRACE("main_block(");
    ce_lck_Lock(s->mutex);

    if (s->ls->nmembers >= thresh
	&& s->vs->xfer_view == 0
	&& s->status == Normal
	)
	for(i=1; i<=5; i++)
	    block_msg (s);
    
    if (s->status == Normal) {
	TRACE_D("Blocked ", s->id);
	s->status = Blocked;
    }
    ce_lck_Unlock(s->mutex);

//    TRACE(")");
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
}


/**************************************************************/
ce_jops_t *
create_Jops(void)
{
    ce_jops_t *jops; 

    /* The rest of the fields should be zero. The
     * conversion code should be able to handle this. 
     */
    jops = record_create(ce_jops_t*, jops);
    record_clear(jops);
//    jops->transports = ce_copy_string("NETSIM");
    jops->transports = ce_copy_string("UDP");
    jops->group_name = ce_copy_string("ce_rand2");
    jops->properties = ce_copy_string(RAND_PROPS) ;
    jops->use_properties = 1;
    jops->hrtbt_rate = 3.0;

    return jops;
}

void rejoin(state_t *s)
{
    ce_jops_t *jops; 
    ce_appl_intf_t *main_intf;

    TRACE_D("rejoin ", s->id);
    s->status = Joining;
    main_intf = ce_create_flat_intf(s,
				    main_exit, main_install, main_flow_block,
				    main_block, main_recv_cast, main_recv_send,
				    main_heartbeat);
    
    s->intf= main_intf;
    jops = create_Jops();

    ce_Join(jops,main_intf);
} 


void act_thread(void* env)
{
    state_t *s = (state_t*) env;
//    struct timeval tv;

    while(1){
	/* Sleep for 30msecs*/
//	tv.tv_sec=0;
//	tv.tv_usec=30000;
//	select(0, NULL, NULL, NULL, &tv);
	
	ce_lck_Lock(s->mutex);
	switch (s->status) {
	case Normal:
	    action(env);
	    break;
	case LeaveDone:
	    rejoin(s);
	    break;
	default:
	    break;
	}
	ce_lck_Unlock(s->mutex);
    }
}


void join(){
    ce_jops_t *jops; 
    ce_appl_intf_t *main_intf;
    state_t *s;

    jops = create_Jops();
    s = (state_t*) record_create(state_t*, s);
    record_clear(s);
    s->status = Joining;
    s->mutex = ce_lck_Create();
    s->id = id_cnt++;
    
//    TRACE("Join(");
    main_intf = ce_create_flat_intf(s,
				    main_exit, main_install, main_flow_block,
				    main_block, main_recv_cast, main_recv_send,
				    main_heartbeat);
    
    s->intf= main_intf;
    ce_Join(jops,main_intf);
//    TRACE(")");

    ce_thread_Create(act_thread, (void*)s, 10000);
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
    ret[ml_args] = NULL;
    ce_Init(ml_args, ret); 
}

void
exn_handler(char *info)
{
    printf("Uncaught ML exception: %s\n", info);
    exit(1);
}

int
main(int argc, char **argv)
{
    int i;
    
    fifo_process_args(argc, argv);
    
    for (i=0; i<nmembers; i++){
	join();
    }
    
//    ce_MLUncaughtException(exn_handler) ;

    TRACE("starting the ce_Main_loop");
    ce_Main_loop ();
    return 0;
}


