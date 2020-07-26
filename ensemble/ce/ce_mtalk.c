/**************************************************************/
/* CE_VIEW.H */
/* Author: Ohad Rodeh 8/2001 */
/* Based somewhat on code by Mark Hayden in the CEnsemble system */
/**************************************************************/
/**************************************************************/
#define NAME "CE_MTALK"
/**************************************************************/
#include "ce_trace.h"
#include "ce.h"
#include <stdio.h>
#include <memory.h>

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

void cast(state_t *s, char *msg){
  if (s->blocked == 0)
    ce_Cast(s->intf, strlen(msg), msg);
}
 

void stdin_handler(void *env){
  state_t *s = (state_t*)env;
  char buf[100], *tmp;
  int len ;
  
  fgets(buf, 100, stdin);
  len = strlen(buf);
  tmp = (char*) malloc(len+1);
  memcpy(tmp, buf, len);
  tmp[len] = '\0';
  printf("Read :len=%d:%s:\n", len, tmp);
  cast(s, tmp);
}

/**************************************************************/

void main_exit(void *env){}

void main_install(void *env, ce_local_state_t *ls, ce_view_state_t *vs){
  state_t *s = (state_t*) env;

  ce_view_full_free(s->ls,s->vs);
  s->ls = ls;
  s->vs = vs;
  s->blocked =0;
  printf("%s nmembers=%d\n", ls->endpt, ls->nmembers);
  TRACE2("main_install",s->ls->endpt); 
}

void main_flow_block(void *env, ce_rank_t rank, ce_bool_t onoff){}

void main_block(void *env){
  state_t *s = (state_t*) env;

  s->blocked=1;
}

void main_recv_cast(void *env, int rank, ce_len_t len, char *msg) {
  state_t *s = (state_t*) env;

  TRACE2("main_recv_cast", s->ls->endpt);
  printf("recv_cast <- %d msg=%s\n", rank, msg);
}

void main_recv_send(void *env, int rank, ce_len_t len, char *msg) {
  state_t *s = (state_t*) env;

  TRACE2("main_recv_send", s->ls->endpt);
  printf("recv_send <- %d msg=%s\n", rank, msg);
}

void main_heartbeat(void *env, double time) {}

void join(){
  ce_jops_t jops; 
  ce_appl_intf_t *main_intf;
  state_t *s;
  
  /* The rest of the fields should be zero. The
   * conversion code should be able to handle this. 
   */
  record_clear(&jops);
  jops.hrtbt_rate=10.0;
  jops.transports = "DEERING";
  jops.group_name = "ce_mtalk";
  jops.properties = CE_DEFAULT_PROPERTIES;
  jops.use_properties = 1;

  s = (state_t*) record_create(state_t*, s);
  record_clear(s);
    
  main_intf = ce_create_intf(s,
			main_exit, main_install, main_flow_block,
			main_block, main_recv_cast, main_recv_send,

			     main_heartbeat);
  
  s->intf= main_intf;
  ce_Join (&jops, main_intf);
  
  ce_AddSockRecv(0, stdin_handler, s);
}

int main(int argc, char **argv){
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
