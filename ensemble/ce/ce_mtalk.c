/**************************************************************/
/* CE_VIEW.H */
/* Author: Ohad Rodeh 8/2001 */
/* Based somewhat on code by Mark Hayden in the CEnsemble system */
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
    ce_local_state_t *ls;
    ce_view_state_t *vs;
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
    char buf[100], *tmp;
    int len ;
    
    TRACE("stdin_handler");
    fgets(buf, 100, stdin);
    len = strlen(buf);
    if (len>=100)
	/* string too long, dumping it.
	 */
	return;
    
    tmp = ce_copy_string(buf);
    TRACE2("Read: ", tmp);
    cast(s, tmp);
}

/**************************************************************/

void main_exit(void *env){}

void
main_install(void *env, ce_local_state_t *ls, ce_view_state_t *vs)
{
    state_t *s = (state_t*) env;
    
    ce_view_full_free(s->ls,s->vs);
    s->ls = ls;
    s->vs = vs;
    s->blocked =0;
    printf("%s nmembers=%d\n", ls->endpt, ls->nmembers);
    TRACE2("main_install",s->ls->endpt); 
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
    state_t *s = (state_t*) env;
    
    TRACE2("main_recv_send", s->ls->endpt);
    printf("%d -> msg=%s", rank, msg);
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
    ce_jops_t *jops; 
    ce_appl_intf_t *main_intf;
    state_t *s;
    
    /* The rest of the fields should be zero. The
     * conversion code should be able to handle this. 
     */
    jops = record_create(ce_jops_t*, jops);
    record_clear(jops);
    jops->hrtbt_rate=10.0;
    //  jops->transports = ce_copy_string("UDP");
    jops->group_name = ce_copy_string("ce_mtalk");
    jops->properties = ce_copy_string(CE_DEFAULT_PROPERTIES);
    jops->use_properties = 1;
    
    s = (state_t*) record_create(state_t*, s);
    record_clear(s);
    
    main_intf = ce_create_flat_intf(s,
				    main_exit, main_install, main_flow_block,
				    main_block, main_recv_cast, main_recv_send,
				    
				    main_heartbeat);
    
    s->intf= main_intf;
    ce_Join (jops, main_intf);
    
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
    
    ce_Init(argc, argv); /* Call Arge.parse, and appl_process_args */
    
    
    join();
    
    ce_Main_loop ();
    return 0;
}
