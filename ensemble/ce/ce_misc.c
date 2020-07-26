/**************************************************************/
/* CE_VIEW.H */
/* Author: Ohad Rodeh 8/2001 */
/* Based on code by Mark Hayden in the CEnsemble system */
/**************************************************************/
#include "ce_internal.h"
#include "ce_trace.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
/**************************************************************/
#define NAME "CE_MISC"
/**************************************************************/

void *
ce_malloc(int size)
{
    void *ptr;
    
    ptr = malloc(size);
    if (ptr == NULL) {
	printf("Out of memory, exiting, tried to allocated <%d> bytes\n", size);
	exit(1);
    }
    return ptr;
}

void *
ce_realloc(void *ptr, int size)
{
    void *ptr2;
    
    ptr2 = realloc(ptr, size);
    if (ptr == NULL) {
	printf("Out of memory, realloc failed, exiting\n");
	exit(1);
    }
    return ptr2;
}

void ce_view_full_free(ce_local_state_t *ls, ce_view_state_t* vs)
{
    if ((ls == NULL) && (vs == NULL))
	return;
    
    TRACE("ce_view_full_free(");
    ce_free(vs->prev_ids);
    ce_free(vs->view);
    ce_free(vs->address);
    ce_free(vs);
    TRACE(".");
    ce_free(ls);
    TRACE(")");
}


void ce_jops_copy(ce_jops_t *src, ce_jops_t *trg)
{
    memcpy(trg, src, sizeof(ce_jops_t));
}

void ce_jops_free(ce_jops_t *jops)
{
    ce_free(jops);
}


/* A static counter for creating id's. 
 */
static int id_counter = 1;

ce_appl_intf_t*
ce_st_create_intf(ce_env_t env, 
	       ce_appl_exit_t exit,
	       ce_appl_install_t install,
	       ce_appl_flow_block_t flow_block,
	       ce_appl_block_t block,
	       ce_appl_receive_cast_t receive_cast,
	       ce_appl_receive_send_t receive_send,
	       ce_appl_heartbeat_t heartbeat
    )
{
    ce_appl_intf_t* intf = (ce_appl_intf_t*) ce_malloc(sizeof(ce_appl_intf_t));

    memset(intf, 0, sizeof(ce_appl_intf_t));
    intf->env = env;
    intf->id = id_counter++;

	intf->magic = CE_MAGIC;
    intf->joining = 0;
    intf->leaving = 0;
    intf->blocked = 0;
    
    intf->aq = ce_queue_create ();
    intf->req_heartbeat = 0;
    intf->exit = exit ;
    intf->install = install ;
    intf->flow_block = flow_block ;
    intf->block = block ;
    intf->receive_cast = receive_cast ;
    intf->receive_send = receive_send ;
    intf->heartbeat = heartbeat ;
    
    return intf;  
}


void
ce_intf_free(ce_pool_t *pool, ce_appl_intf_t* intf)
{
    if (pool != NULL)
	ce_queue_free(pool, intf->aq);
	memset(intf, 0, sizeof(ce_appl_intf_t));
    ce_free(intf);
}

char**
ce_process_args(int argc, char **argv)
{
    int i,j ;
    int ml_args=0;
    char **ret = NULL;
    
    for (i=0;i<argc;i++) {
	if (strcmp(argv[i], "-ctrace") == 0) {
	    if (++i >= argc) {
		continue ;
	    }
	    trace_add(argv[i]) ;
	} else
	    ml_args++ ;
    }
    
    ret = (char**) ce_malloc ((ml_args+1) * sizeof(char*));
    ret[ml_args] = NULL;
    
    for(i=0, j=0; i<argc; i++) {
	if (strcmp(argv[i], "-ctrace") == 0){
	    i++;
	    continue;
	} else {
	    ret[j]=argv[i];
	    j++;
	}
    }
    
    return ret;
}

/**************************************************************/

#ifndef _WIN32
void
ce_panic(char *s)
{
    printf("CE: Fatal error: %s\n", s);
    perror("");
    exit(1);
}

#else

void
ce_panic(char *s)
{
    char error[256];
    int errno;
    
    printf("CE: Fatal error\n");
    errno = GetLastError();
    (void) FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM ,
			 NULL,	// message format
			 errno,
			 0,		// language
			 error,
			 256,		// buffer size, ignored for ALLOC_BUF
			 NULL	// args for msg format
	);
    fprintf(stderr, "%s: (%d) %s\n", s, errno, error);
    exit(1);
}
#endif /*_WIN32*/

/**************************************************************/

