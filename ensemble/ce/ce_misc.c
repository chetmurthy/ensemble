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
	printf("Out of memory, exiting\n");
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

#define ce_free(x) if (x != NULL) free(x)

LINKDLL char*
ce_copy_string(char *str){
    char *buf;
    int len;
    
    TRACE("ce_copy_string(");
    len = strlen(str);
    buf = malloc(len+1);
    TRACE(".");
    memcpy(buf,str,len);
    buf[len] = '\0';
    TRACE(")");
    return buf;
}

void
ce_view_id_free(ce_view_id_t *id){
    ce_free(id->endpt);
    ce_free(id);
}

/* Ce_Free a null terminated string array.
 */
void
ce_string_array_free(char **sa){
    int i=0;
    
    while (sa[i] != NULL) {
	ce_free(sa[i]);
	i++;
    }
    ce_free(sa);
}

/* Free a null terminated view_id array.
 */
void
ce_view_id_array_free(ce_view_id_array_t va){
    int i=0;
    
    while (va[i] != NULL) {
	ce_view_id_free(va[i]);
	i++;
    }
    ce_free(va);
}


LINKDLL void ce_view_full_free(ce_local_state_t *ls, ce_view_state_t* vs) {
    if ((ls == NULL) && (vs == NULL))
	return;
    
    TRACE("ce_view_full_free(");
    ce_free(vs->version);    ce_free(vs->group);
    ce_free(vs->proto);
    ce_free(vs->key);
    ce_view_id_array_free(vs->prev_ids);
    ce_free(vs->params);
    ce_string_array_free(vs->view);
    ce_string_array_free(vs->address);
    ce_free(vs);
    TRACE(".");
    
    ce_free(ls->endpt);
    ce_free(ls->addr);
    ce_free(ls->name);
    ce_view_id_free(ls->view_id);
    ce_free(ls);
    TRACE(")");
}

LINKDLL void ce_jops_free(ce_jops_t* jops) {
    TRACE("ce_jops_free(");
    ce_free(jops->transports);
    TRACE(".");
    ce_free(jops->protocol);
    TRACE(".");
    ce_free(jops->group_name);
    TRACE(".");
    ce_free(jops->properties);
    TRACE(".");
    ce_free(jops->params);
    TRACE(".");
    ce_free(jops->endpt);
    TRACE(".");
    ce_free(jops->princ);
    TRACE(".");
    ce_free(jops->key);
    TRACE(".");
    ce_free(jops);
    TRACE(")");
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
    ){
    ce_appl_intf_t* intf = record_create(ce_appl_intf_t*, intf) ;

    intf->env = env;
    intf->id = id_counter++;

    intf->joining = 0;
    intf->leaving = 0;
    intf->blocked = 0;
    
    intf->aq = ce_create_queue ();
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
ce_intf_free(ce_appl_intf_t* intf){
    ce_queue_clear(intf->aq);
    ce_queue_free(intf->aq);
    ce_free(intf);
}

char**
ce_process_args(int argc, char **argv){
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

