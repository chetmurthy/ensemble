/**************************************************************/
/* CE_MTALK_MT.C */
/* Author: Ohad Rodeh 5/2002 */
/* A simple program implementing a multi-person talk, */
/* uses the thread-safe library, and works on all platforms */
/**************************************************************/
#include "ce_trace.h"
#include "ce.h"
#include "ce_threads.h"
#include <stdio.h>
#include <stdlib.h>
#include <memory.h>
#include <malloc.h>
/**************************************************************/
#define NAME "CE_MTALK_MT"
/**************************************************************/


typedef struct state_t {
    int rank;
    int nmembers;
    ce_endpt_t endpt;
    ce_appl_intf_t *intf ;
    int blocked;
    int joining;
    int leaving;
    ce_lck_t *mutex;
} state_t;

/**************************************************************/

void main_exit(void *env){}

void
main_install(void *env, ce_local_state_t *ls, ce_view_state_t *vs)
{
    state_t *s = (state_t*) env;
    
    ce_lck_Lock(s->mutex);{
	s->rank = ls->rank;
	s->nmembers = ls->nmembers;
	s->blocked =0;
	memcpy(s->endpt.name, ls->endpt.name, CE_ENDPT_MAX_SIZE);
	s->blocked =0;
	s->joining =0;
	
	printf("%s nmembers=%d\n", ls->endpt.name, ls->nmembers);
	TRACE2("main_install",ls->endpt.name); 
    } ce_lck_Unlock(s->mutex);
}

void
main_flow_block(void *env, ce_rank_t rank, ce_bool_t onoff)
{}

void
main_block(void *env)
{
    state_t *s = (state_t*) env;
    
    ce_lck_Lock(s->mutex);{
	s->blocked=1;
    } ce_lck_Unlock(s->mutex);
}

void
main_recv_cast(void *env, int rank, ce_len_t len, char *msg)
{
    printf("%d -> msg=%s", rank, msg); fflush(stdout);
}

void
main_recv_send(void *env, int rank, ce_len_t len, char *msg)
{}

void
main_heartbeat(void *env, double time)
{
    static int counter = 0;

    TRACE("heartbeat");
}


/* A thread that reads input from the user
 */
void
get_input(void *env)
{
    state_t *s = (state_t*)env;
    char buf[100], *msg;
    int len ;

    while (1) {
	TRACE("stdin_handler");
	fgets(buf, 100, stdin);
	len = strlen(buf);
	if (len>=100)
	    /* string too long, dumping it.
	     */
	    return;
	
	msg = (char*) malloc(len+1);
	memcpy(msg, buf, len);
	msg[len] = 0;
	TRACE2("Read: ", msg);
	
	ce_lck_Lock(s->mutex);{
	    if (s->joining || s->leaving || s->blocked)
		printf("Cannot send while group is joining/leaving/blocked, try later\n");
	    else {
		ce_flat_Cast(s->intf, strlen(msg)+1, msg);
	    }
	} ce_lck_Unlock(s->mutex);
    }
}

state_t *
join(void)
{
    ce_jops_t jops; 
    ce_appl_intf_t *main_intf;
    state_t *s;
    
    /* The rest of the fields should be zero. The
     * conversion code should be able to handle this. 
     */
    memset(&jops, 0, sizeof(ce_jops_t));
    jops.hrtbt_rate=3.0;
    strcpy(jops.group_name, "ce_mtalk_mt");
    strcpy(jops.properties, CE_DEFAULT_PROPERTIES);
    jops.use_properties = 1;
    
    s = (state_t*) malloc(sizeof(state_t));
    memset(s, 0, sizeof(state_t));
    
    main_intf = ce_create_flat_intf(s,
				    main_exit, main_install, main_flow_block,
				    main_block, main_recv_cast, main_recv_send,
				    
				    main_heartbeat);
    
    s->intf= main_intf;
    s->mutex = ce_lck_Create();
    s->joining = 1;
    ce_Join (&jops, main_intf);
    return s;
}

int
main(int argc, char **argv)
{
    state_t *s;
    
    ce_set_alloc_fun((mm_alloc_t)malloc);
    ce_set_free_fun((mm_free_t)free);

    ce_Init(argc, argv); /* Call Arge.parse, and appl_process_args */

    /* Join the group
     */
    s = join();
    
/* Create a thread to read input from the user.
 */
    ce_thread_Create(get_input, s, 10000);
    
    
    ce_Main_loop ();
    return 0;
}
