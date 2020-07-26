/****************************************************************************/
/* CE_FLAT.C */
/* Author:  Ohad Rodeh, 11/2001. */
/* This provides a nicer, "flat" interface.
/****************************************************************************/
#include "ce_internal.h"
#include "ce_trace.h"
#include <stdio.h>
/****************************************************************************/
#define NAME "CE_FLAT"
/****************************************************************************/
/* This section deals with converting flat actions into regular actions.
 */

/* Create an iovl, to wrap the arguments.
 */
ce_iovec_array_t
ce_iovl_wrap(ce_len_t len, ce_data_t data){
  ce_iovec_array_t iovl;
  
  iovl = (ce_iovec_array_t)malloc(1 * sizeof(ce_iovec_t));
  Iov_len(iovl[0]) = len;
  Iov_buf(iovl[0]) = data;

  //  printf("ce_iovl_wrap: len=%d, buf=%s\n", Iov_len(iovl[0]), Iov_buf(iovl[0]));
  return iovl;
}

/* Flatten an iovec array. Use mm_alloc_fun to allocate
 * memory and copy into it if the iovec has more then one
 * element.
 */
void
ce_iovl_flatten(int num,
		ce_iovec_array_t iovl,
		/* OUT */
		ce_len_t *len,
		ce_data_t *data
		){
  int i;
  int total_len, cur;
  char *buf;

  if (num == 0) {
    printf("empty iovec\n");
    *len=0;
    *data=NULL;
    return;
  } 
  
  /* One segment, no copying.
   */
  if (num == 1) {
    *len = Iov_len(iovl[0]);
    *data = Iov_buf(iovl[0]);
  } else {
    TRACE("actually copying");
    
    /* Compute the total length
     */
    for (i=0, total_len=0;
	 i<num;
	 i++, total_len += Iov_len(iovl[i]));
    
    /* Allocate memory
     */
    buf = mm_alloc_fun(total_len);

    /* Copy into it.
     */
    cur=0;    
    for (i=0; i<num; i++){
      memcpy((char*)buf + cur, Iov_buf(iovl[i]), Iov_len(iovl[i]));
      cur += Iov_len(iovl[i]);
    }

    /* Return results (C style)
     */
    *len = total_len;
    *data = buf;
  }
}

void ce_flat_Cast(
	ce_appl_intf_t *c_appl,
	ce_len_t len, 
	ce_data_t buf
	) {
  ce_iovec_array_t iovl;

  iovl = ce_iovl_wrap(len,buf);
  ce_Cast(c_appl, 1, iovl);
}

void ce_flat_Send(
	ce_appl_intf_t *c_appl,
	int num_dests,
	ce_rank_array_t dests,
	ce_len_t len, 
	ce_data_t buf
	) {
  ce_iovec_array_t iovl;

  iovl = ce_iovl_wrap(len,buf);
  ce_Send(c_appl, num_dests, dests, 1, iovl);
}

void ce_flat_Send1(
	ce_appl_intf_t *c_appl,
	ce_rank_t dest,
	ce_len_t len, 
	ce_data_t buf
	) {
  ce_iovec_array_t iovl;

  iovl = ce_iovl_wrap(len,buf);
  ce_Send1(c_appl, dest, 1, iovl);
}



/****************************************************************************/
/* This part converts callbacks from the iovec interface into the flat
 * interface.
 */

/* A structure wrapping up a flat interface.
 */
typedef struct ce_flat_env_t {
  ce_env_t env;
  ce_appl_exit_t exit;
  ce_appl_install_t install;
  ce_appl_flow_block_t flow_block;
  ce_appl_block_t block;
  ce_appl_flat_receive_cast_t cast;
  ce_appl_flat_receive_send_t send;
  ce_appl_heartbeat_t heartbeat;
} ce_flat_env_t;


void
ce_flat_install(ce_env_t env, ce_local_state_t *ls, ce_view_state_t *vs){
  ce_flat_env_t *e = (ce_flat_env_t*)env;
  e->install(e->env, ls, vs);
}

void
ce_flat_exit(ce_env_t env){
  ce_flat_env_t *e = (ce_flat_env_t*)env;
  
  e->exit(e->env);

  /* Cleanup the environment structure.
   */
  TRACE("free(");
  free(env);
  TRACE("");
}

void
ce_flat_flow_block(ce_env_t env, ce_rank_t origin, ce_bool_t onoff){
  ce_flat_env_t *e = (ce_flat_env_t*)env;
  e->flow_block(e->env, origin, onoff);
}

void
ce_flat_block(ce_env_t env){
  ce_flat_env_t *e = (ce_flat_env_t*)env;
  e->block(e->env);
}


void
ce_flat_send_cbd(
	  ce_env_t env,
	  ce_rank_t origin,
	  int num,
	  ce_iovec_array_t iovl){
  ce_flat_env_t *e = (ce_flat_env_t*)env;
  ce_len_t len;
  ce_data_t buf = NULL;
  
  ce_iovl_flatten(num, iovl, &len, &buf);
  e->send(e->env, origin, len, buf);
  
  /* Be carefuly to free the buffer only if has been
   * newly allocated here. Otherwise, Ensemble's
   * refcounting will free it.
   */
  if (num>1) mm_free_fun(buf);
}

void
ce_flat_cast_cbd(
	  ce_env_t env,
	  ce_rank_t origin,
	  int num,
	  ce_iovec_array_t iovl){
  ce_flat_env_t *e = (ce_flat_env_t*)env;
  ce_len_t len;
  ce_data_t buf = NULL;
  
  ce_iovl_flatten(num, iovl, &len, &buf);
  e->cast(e->env, origin, len, buf);
  
  /* Be carefuly to free the buffer only if has been
   * newly allocated here. Otherwise, Ensemble's
   * refcounting will free it.
   */
  if (num>1) mm_free_fun(buf);
}


void
ce_flat_heartbeat(ce_env_t env, ce_time_t time){
  ce_flat_env_t *e = (ce_flat_env_t*)env;
  e->heartbeat(e->env, time);
}


/* Wrap a flat interface so that it would look like an iovec
 * interface.
 */
ce_appl_intf_t*
ce_create_flat_intf(ce_env_t env, 
		    ce_appl_exit_t exit,
		    ce_appl_install_t install,
		    ce_appl_flow_block_t flow_block,
		    ce_appl_block_t block,
		    ce_appl_flat_receive_cast_t cast,
		    ce_appl_flat_receive_send_t send,
		    ce_appl_heartbeat_t heartbeat
		    ){
  ce_flat_env_t *flat_env;
  flat_env = record_create(ce_flat_env_t*, flat_env);

  flat_env -> env = env;
  flat_env -> exit = exit;
  flat_env -> install = install;
  flat_env -> flow_block = flow_block;
  flat_env -> block = block;
  flat_env -> cast = cast;
  flat_env -> send = send;
  flat_env -> heartbeat = heartbeat;
  
  return
    (ce_create_intf(flat_env, ce_flat_exit, ce_flat_install,
		    ce_flat_flow_block, ce_flat_block, ce_flat_cast_cbd,
		    ce_flat_send_cbd, ce_flat_heartbeat));
}


/****************************************************************************/
