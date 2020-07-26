/**************************************************************/
/* CE_MTALK.H */
/* Author: Ohad Rodeh 8/2001 */
/* A simple program implementing a multi-person talk. */
/* Works only on Unix platforms. */
/**************************************************************/
#include "ce_trace.h"
#include "ce.h"
#include <stdio.h>
#include <memory.h>
#include <malloc.h>

#ifndef _WIN32
#include <sys/types.h>
#include <sys/socket.h>
#endif
/**************************************************************/
#define NAME "CE_MTALK"
/**************************************************************/


typedef struct state_t {
    int rank;
    int nmembers;
    ce_endpt_t endpt;
    ce_appl_intf_t *intf ;
    int blocked;
} state_t;


/**************************************************************/

void
cast(state_t *s, char *msg)
{
    if (s->blocked == 0) 
	ce_flat_Cast(s->intf, strlen(msg)+1, msg);
}


void
stdin_handler(void *env)
{
    state_t *s = (state_t*)env;
    char buf[100], *msg;
    int len ;
    
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
    cast(s, msg);
}

/**************************************************************/

void main_exit(void *env)
{}

void
main_install(void *env, ce_local_state_t *ls, ce_view_state_t *vs)
{
    state_t *s = (state_t*) env;
    
    s->rank = ls->rank;
    s->nmembers = ls->nmembers;
    s->blocked =0;
    memcpy(s->endpt.name, ls->endpt.name, CE_ENDPT_MAX_SIZE);

    printf("%s nmembers=%d\n", ls->endpt.name, ls->nmembers);
    TRACE2("main_install",s->endpt.name); 
}

void
main_flow_block(void *env, ce_rank_t rank, ce_bool_t onoff)
{}

void
main_block(void *env)
{
    state_t *s = (state_t*) env;
    
    s->blocked=1;
}

void
main_recv_cast(void *env, int rank, ce_len_t len, char *msg)
{
//    state_t *s = (state_t*) env;
    
//    TRACE2("main_recv_send", s->ls->endpt.name);
    printf("%d -> msg=%s", rank, msg); fflush(stdout);
}

void
main_recv_send(void *env, int rank, ce_len_t len, char *msg)
{}

void
main_heartbeat(void *env, double time)
{
    TRACE("heartbeat");
}

void
join(void)
{
    ce_jops_t jops; 
    ce_appl_intf_t *main_intf;
    state_t *s;
    
    /* The rest of the fields should be zero. The
     * conversion code should be able to handle this. 
     */
    memset(&jops, 0, sizeof(ce_jops_t));
    jops.hrtbt_rate=10.0;
    strcpy(jops.group_name, "ce_mtalk");
    strcpy(jops.properties, CE_DEFAULT_PROPERTIES);
    jops.use_properties = 1;
    
    s = (state_t*) malloc(sizeof(state_t));
    memset(s, 0, sizeof(state_t));
    
    main_intf = ce_create_flat_intf(s,
				    main_exit, main_install, main_flow_block,
				    main_block, main_recv_cast, main_recv_send,
				    
				    main_heartbeat);
    
    s->intf= main_intf;
    ce_Join (&jops, main_intf);
    
    ce_AddSockRecv(0, stdin_handler, s);
}

int
main(int argc, char **argv)
{
#ifdef WIN32
    printf("On WIN32 platforms, this program will not work correctly."
	   " This is due to difference in the behavior of sockets between"
	   " Unix and windows\n");
    exit(0);
#endif
    ce_set_alloc_fun((mm_alloc_t)malloc);
    ce_set_free_fun((mm_free_t)free);
    
    ce_Init(argc, argv); /* Call Arge.parse, and appl_process_args */
    
    
    join();
    
    ce_Main_loop ();
    return 0;
}
