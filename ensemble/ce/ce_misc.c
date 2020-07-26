/**************************************************************/
/* CE_VIEW.H */
/* Author: Ohad Rodeh 8/2001 */
/* Based on code by Mark Hayden in the CEnsemble system */
/**************************************************************/
#include "ce_internal.h"
#include "ce_trace.h"
#include <stdio.h>
/**************************************************************/
#define NAME "CE_MISC"
/**************************************************************/

void *ce_malloc(int size){
  void *ptr;

  ptr = malloc(size);
  if (ptr == NULL) {
    printf("Out of memory, exiting\n");
    exit(1);
  }
  return ptr;
}

void
ce_view_id_free(ce_view_id_t *id){
  free(id->endpt);
  free(id);
}

/* Free a null terminated string array.
 */
void
ce_string_array_free(char **sa){
  int i=0;
  
  while (sa[i] != NULL) {
    free(sa[i]);
    i++;
  }
  free(sa);
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
  free(va);
}


void ce_view_full_free(ce_local_state_t *ls, ce_view_state_t* vs) {
  if ((ls == NULL) && (vs == NULL))
    return;

  TRACE("ce_view_full_free(");
  free(vs->version);
  free(vs->group);
  free(vs->proto);
  free(vs->key);
  ce_view_id_array_free(vs->prev_ids);
  free(vs->params);
  ce_string_array_free(vs->view);
  ce_string_array_free(vs->address);
  free(vs);
  TRACE(".");

  free(ls->endpt);
  free(ls->addr);
  free(ls->name);
  ce_view_id_free(ls->view_id);
  free(ls);
  TRACE(")");
}

void ce_jops_free(ce_jops_t* jops) {
  free(jops->transports);
  free(jops->protocol);
  free(jops->group_name);
  free(jops->properties);
  free(jops->params);
  free(jops->endpt);
  free(jops->princ);
  free(jops->key);
  free(jops);
}

ce_appl_intf_t*
ce_create_intf(ce_env_t env, 
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
  intf->aq = ce_create_queue ();
  intf->req_heartbeat = 0;
  intf->exit = exit ;
  intf->install = install ;
  intf->flow_block = flow_block ;
  intf->block = block ;
  intf->receive_cast = receive_cast ;
  intf->receive_send = receive_send ;
  intf->heartbeat = heartbeat ;

  return ((ce_appl_intf_t*) intf);  
}

void
ce_intf_free(ce_appl_intf_t* intf){
  ce_queue_clear(intf->aq);
  ce_queue_free(intf->aq);
  free(intf);
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
      if (strcmp(argv[i], "-ctrace") == 0) {
	i++;
	continue;
      } else {
	ret[j]=argv[i];
	j++;
      }
    }

    return ret;
}
    
