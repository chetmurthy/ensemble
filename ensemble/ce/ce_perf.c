/**************************************************************/
/* CE_PERF.C: performance test. */
/* Author: Ohad Rodeh 8/2001 */
/* Tests two scenarios: ping latency, and bandwith */
/**************************************************************/
#include "ce_trace.h"
#include "ce.h"
#include <stdio.h>
#include <stdlib.h>
#include <memory.h>
/**************************************************************/
#define NAME "CE_PERF"
/**************************************************************/
typedef enum test_t {RPC, THROU, FLOW} test_t;
typedef enum phase_t {START, BEGIN, END, DONE} phase_t;

static char* prog ;
static test_t test = RPC;
static int nmembers = 2;
static double rate = 0.1;
static int size = 4 ;
static double terminate_time = 100.0;
static int quiet = 0;
/**************************************************************/
ce_iovec_array_t prepare_iovl(ce_iovec_t *iovl, int size)
{
    Iov_len(iovl[0]) = size;
    Iov_buf(iovl[0]) = (char*) malloc(size);
    
    return iovl;
}

/**************************************************************/
typedef struct rpc_state_t {
    int rank;
    int nmembers;
    ce_appl_intf_t *intf ;
    int blocked;
    double start_time;
    int total ;
    phase_t phase;
} rpc_state_t ;

void rpc_exit(void *env){}

void rpc_install(void *env, ce_local_state_t *ls, ce_view_state_t *vs)
{
    rpc_state_t *s = (rpc_state_t*) env;
    
    s->rank = ls->rank;
    s->nmembers = ls->nmembers;
    s->blocked = 0;
    s->start_time = -1;
    s->total = 0;
    s->phase = START;
    printf("%s nmembers=%d\n", ls->endpt.name, ls->nmembers);
    TRACE2("rpc_install",ls->endpt.name);
}

void rpc_flow_block(void *env, ce_rank_t rank, ce_bool_t onoff){}

void rpc_block(void *env){
    rpc_state_t *s = (rpc_state_t*) env;
    
    s->blocked=1;
    TRACE_D("rpc_block",s->rank); 
}

void rpc_recv_send(void *env, int rank, int num, ce_iovec_array_t iovl) {
    rpc_state_t *s = (rpc_state_t*) env;
    static int last_report = 0;
    ce_iovec_t send_iovl[1];
    
    s->total++;
    //  TRACE("rpc_recv_send");
    if (s->blocked == 0
	&& s->nmembers ==2) {
	if (s->rank ==0) {
	    if (s->phase == BEGIN || s->phase == END)
		ce_Send1(s->intf, 1, 1, prepare_iovl(send_iovl, size));
	} else
	    ce_Send1(s->intf,0, 1, prepare_iovl(send_iovl, size));
    }

    if (!quiet && s->total - last_report >= 1000) {
	last_report = s->total;
	printf ("received %d messages\n", s->total);
    }
}

void rpc_recv_cast(void *env, int rank, int num, ce_iovec_array_t iovl) {
}

void rpc_heartbeat(void *env, ce_time_t time) {
    rpc_state_t *s = (rpc_state_t*) env;
    ce_iovec_t iovl[1];
    
    if (s->phase == START
	&& s->nmembers==2){
	s->phase =BEGIN;
	s->start_time = time + 2.0;
    }
    
    if (s->phase == BEGIN
	&& time > s->start_time){
	s->phase = END;
	s->start_time = time;
	if (s->rank == 0) {
	    printf ("Starting RPC test\n");
	    ce_Send1(s->intf, 1, 1, prepare_iovl(iovl, size));
	}
    }
    
    if (s->phase == END
	&& time > (s->start_time + terminate_time + 1)) {
	s->phase = DONE;
	printf("total=%d\n", s->total);
	printf("time=%5.3f\n", terminate_time);
	printf("round-trip latency=%1.6f(sec)\n", (time - s->start_time)/s->total);
	exit(0);
    }
}

void rpc_join(void){
    ce_jops_t jops; 
    ce_appl_intf_t *rpc_intf;
    rpc_state_t *s;
    
    /* The rest of the fields should be zero. The
     * conversion code should be able to handle this. 
     */
    memset(&jops, 0, sizeof(ce_jops_t));
    //  jops.transports = "UDP";
    memcpy(jops.group_name, "ce_perf", strlen("ce_perf"));
    memcpy(jops.properties, CE_DEFAULT_PROPERTIES, strlen(CE_DEFAULT_PROPERTIES));
    jops.use_properties = 1;
    jops.hrtbt_rate = 1.0;
    
    s = (rpc_state_t*) malloc(sizeof(rpc_state_t));
    memset(s, 0, sizeof(rpc_state_t));
    
    rpc_intf = ce_create_intf(s,
			      rpc_exit, rpc_install, rpc_flow_block,
			      rpc_block, rpc_recv_cast, rpc_recv_send,
			      rpc_heartbeat);
    
    
    s->intf= rpc_intf;
    ce_Join(&jops,rpc_intf);
}

/**************************************************************/

typedef struct throu_state_t {
    int rank ;
    int nmembers;
    ce_appl_intf_t *intf ;
    int blocked;
    ce_time_t next;
    ce_time_t start_time;
    int flow_blocked ;
    int total ;
    phase_t phase;
} throu_state_t ;

void throu_exit(void *env){}

void throu_install(void *env, ce_local_state_t *ls, ce_view_state_t *vs)
{
    throu_state_t *s = (throu_state_t*) env;
    
    s->rank = ls->rank;
    s->nmembers = ls->nmembers;
    s->blocked = 0;
    s->next = -1;
    s->start_time = -1;
    s->flow_blocked = 0;
    s->total = 0;
    s->phase = START;
    printf("%s nmembers=%d\n", ls->endpt.name, ls->nmembers);
    TRACE2("throu_install",ls->endpt.name);
}

void throu_flow_block(void *env, ce_rank_t rank, ce_bool_t onoff){
    throu_state_t *s = (throu_state_t*) env;
    
    s->flow_blocked = onoff;
}

void throu_block(void *env)
{
    throu_state_t *s = (throu_state_t*) env;
    
    s->blocked=1;
    TRACE_D("throu_block",s->rank); 
}

void throu_recv_send(void *env, int rank, int num, ce_iovec_array_t iovl) {
}

void throu_recv_cast(void *env, int rank, int num, ce_iovec_array_t iovl) {
    throu_state_t *s = (throu_state_t*) env;
    int i;
    static int last_report = 0;

    TRACE("recv");
    /* Sum up the total received length
     */
    for(i=0; i< num; i++) 
	s->total += Iov_len(iovl[i]);
    
    if (!quiet && s->total - last_report > 100*1024) {
	last_report = s->total;
	printf ("received %d KBytes\n", (s->total/1024));
    }
}

void throu_heartbeat(void *env, ce_time_t time) {
    throu_state_t *s = (throu_state_t*) env;
    ce_iovec_t iovl[1];
    
    if (s->blocked == 0 
	&& s->nmembers == nmembers
	) {
	if (s->phase == START) {
	    s->phase = BEGIN;
	    s->start_time = time + 2.0;
	    s->next = time + 2.0;
	    printf("Starting in 2 seconds\n");
	}
	
	if (s->phase == BEGIN
	    && s->rank == 0) {
	    if (s->flow_blocked ==1)
		s->next = time;
	    else
		while (time > s->next) {
		    TRACE("Sending bcast");
		    ce_Cast(s->intf, 1, prepare_iovl(iovl, size));
		    s->next += rate;
		    s->total += size;
		}
	}
    }
    
    if (s->phase == BEGIN
	&& time > (s->start_time + terminate_time)) {
	s->phase = END;
	printf("total=%d\n", s->total);
	printf("time=%5.3f\n", terminate_time);
	printf("throughput=%5.3f(K/sec)\n", s->total/(1024 * (time - s->start_time)));
    }
}

void throu_join(void)
{
    ce_jops_t jops; 
    ce_appl_intf_t *throu_intf;
    throu_state_t *s;
    
    /* The rest of the fields should be zero. The
     * conversion code should be able to handle this. 
     */
    memset(&jops, 0, sizeof(ce_jops_t));
    memcpy(jops.transports, "DEERING", strlen("DEERING"));
    memcpy(jops.group_name, "ce_perf", strlen("ce_perf"));
    memcpy(jops.properties, CE_DEFAULT_PROPERTIES, strlen(CE_DEFAULT_PROPERTIES));
    jops.use_properties = 1;
    jops.hrtbt_rate = 1.0;
    
    s = (throu_state_t*) malloc(sizeof(throu_state_t));
    memset(s, 0, sizeof(throu_state_t));
    throu_intf = ce_create_intf(s,
				throu_exit, throu_install, throu_flow_block,
				throu_block, throu_recv_cast, throu_recv_send,
				throu_heartbeat);
    
    s->intf= throu_intf;
    ce_Join (&jops, throu_intf);
}



/**************************************************************/
/* Adapted from a test by Ganesh N.
 */
/**************************************************************/

typedef struct {
    int rank;
    int nmembers;
    ce_appl_intf_t *intf ;
    int blocked;
    int msg_size ;
} flow_state_t;

void
flow_help_cast(flow_state_t *s, char *msg)
{
    if (s->blocked == 0) 
	ce_flat_Cast(s->intf, strlen(msg)+1, msg);
}

void flow_exit(void *env){}

void flow_install(void *env, ce_local_state_t *ls, ce_view_state_t *vs)
{
    flow_state_t *s = (flow_state_t*) env;
    
    s->rank = ls->rank;
    s->nmembers = ls->nmembers;
    s->blocked =0;
    printf("%s nmembers=%d\n", ls->endpt.name, ls->nmembers);
    TRACE2("main_install", ls->endpt.name); 
}

void
flow_flow_block(void *env, ce_rank_t rank, ce_bool_t onoff)
{}

void
flow_block(void *env)
{
    flow_state_t *s = (flow_state_t*) env;
    
    s->blocked=1;
}

void
flow_recv_cast(void *env, int rank, ce_len_t len, char *msg)
{
    printf("%d -> msg=%s(%d)\n", rank, "rcvd", len); 
}

void
flow_recv_send(void *env, int rank, ce_len_t len, char *msg)
{}

void
flow_heartbeat(void *env, double time)
{
    int i;
    flow_state_t *s = (flow_state_t*)env;
    char *buf;
    
    TRACE("heartbeat");
    if(s->nmembers != 2 /*3*/)
        return;

    buf = (char*) malloc(s->msg_size +1);
    if(!buf){
        printf("unable to alloc mem.. %d\n", s->msg_size);
        exit(0);
    }
        
    for(i=0; i<s->msg_size-1 ; i++)
        buf[i]='0' + s->rank;
    buf[s->msg_size-1]= '\0';
    flow_help_cast(s, buf);
    
    s->msg_size = s->msg_size * 2;
//    size = size+20;
}

void
flow_join(void)
{
    ce_jops_t jops; 
    ce_appl_intf_t *main_intf;
    flow_state_t *s;
    
    /* The rest of the fields should be zero. The
     * conversion code should be able to handle this. 
     */
    memset(&jops, 0, sizeof(ce_jops_t));

    jops.hrtbt_rate=1.0;
    //  jops->transports = ce_copy_string("UDP");
    memcpy(jops.group_name, "ce_mtalk", strlen("ce_mtalk"));
    memcpy(jops.properties, CE_DEFAULT_PROPERTIES, strlen(CE_DEFAULT_PROPERTIES));
    jops.use_properties = 1;
    
    s = (flow_state_t*) malloc(sizeof(flow_state_t));
    memset(s, 0, sizeof(flow_state_t));
    
    main_intf = ce_create_flat_intf(s,
				    flow_exit, flow_install, flow_flow_block,
				    flow_block, flow_recv_cast, flow_recv_send,
				    
				    flow_heartbeat);
    
    s->intf= main_intf;
    s->msg_size = 2;
    ce_Join (&jops, main_intf);
}

/**************************************************************/


void process_args(int argc, char **argv){
    int i,j ;
    int ml_args=0;
    char **ret = NULL;
    
    for (i=0;i<argc;i++) {
	if (strcmp(argv[i], "-prog") == 0) {
	    if (++i >= argc){
		continue ;
	    }
	    prog = (argv[i]);
	    printf ("prog=%s\n", prog);
	} else 
	    if (strcmp(argv[i], "-n") == 0) {
		if (++i >= argc){
		    continue ;
		}
		nmembers = atoi(argv[i]);
		printf ("nmembers=%d\n", nmembers);
	    } else
		if (strcmp(argv[i], "-r") == 0) {
		    if (++i >= argc){
			continue ;
		    }
		    rate = atof(argv[i]);
		    printf ("rate=%f\n", rate);
		} else 
		    if (strcmp(argv[i], "-s") == 0) {
			if (++i >= argc){
			    continue ;
			}
			size = atoi(argv[i]);
			printf ("size=%d\n", size);
		    } else 
			if (strcmp(argv[i], "-terminate_time") == 0) {
			    if (++i >= argc){
				continue ;
			    }
			    terminate_time = (float) atoi(argv[i]);
			    printf ("terminate_time=%d\n", size);
			} else 
			    if (strcmp(argv[i], "-quiet") == 0) {
				quiet = 1;
				printf ("quiet mode\n");
			    } else
				ml_args++ ;
    }
    
    ret = (char**) malloc ((ml_args+1) * sizeof(char*));
    ret[ml_args] = NULL;
    
    for(i=0, j=0; i<argc; i++) {
	if ((strcmp(argv[i], "-prog") == 0)
	    ||(strcmp(argv[i], "-n") == 0)
	    || (strcmp(argv[i], "-r") == 0)
	    || (strcmp(argv[i], "-s") == 0)
	    || (strcmp(argv[i], "-quiet") == 0)
	    || (strcmp(argv[i], "-terminate_time") == 0)) {
	    i++;
	    continue ;
	} else {
	    ret[j]=argv[i];
	    j++;
	}
    }
    
    TRACE("before init("); 
    ce_Init(ml_args, ret); /* Call Arge.parse, and appl_process_args */
    TRACE(")"); 
}

void usage(void)
{
    if (prog !=NULL) {
	if (strcmp(prog,"rpc") ==0) {
	    test = RPC;
	}
	else if (strcmp(prog,"throu") == 0
		|| strcmp(prog,"1-n") ==0) {
		test = THROU;
	    }
	else if (strcmp(prog,"flow") == 0) {
	    test = FLOW;
	}
	else {
	    printf("Usage: ce_perf -n _ -prog [rpc|1-n|throu|flow]\n");
	    printf("Other tests are not supported\n");
	    exit(1);
	}
    }
}

int main(int argc, char **argv)
{
    void (*join_fun)(void);
    
    ce_set_alloc_fun((mm_alloc_t)malloc);
    ce_set_free_fun((mm_free_t)free);

    //ce_Init(argc, argv);
    process_args(argc, argv);
    usage();
    printf("nmembers=%d, rate=%1.4f, size=%d\n", nmembers, rate, size);
    
    TRACE("determining test");
    switch (test) {
    case RPC:
	join_fun = rpc_join;
	break;
    case THROU:
	join_fun = throu_join;
	break;
    case FLOW:
	join_fun = flow_join;
	break;
    default:
	printf("Bad test\n");
	exit(1);
    }
    
    TRACE("Joining group");
    join_fun ();
    
    ce_Main_loop ();
    return 0;
}
