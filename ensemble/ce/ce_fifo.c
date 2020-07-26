/**************************************************************/
/* CE_FIFO.C */
/* Author: Ohad Rodeh 8/2001 */
/* Based on demo/fifo.ml */
/**************************************************************/
#include "ce_trace.h"
#include "ce.h"
#include <stdio.h>
#include <stdlib.h>
#include <limits.h>
/**************************************************************/
#define NAME "CE_FIFO"
/**************************************************************/
typedef struct iov_t {
  int len;
  char *data;
} iov_t;

//#define free(x)  printf("%s:freeing(", NAME); fflush(stdout); free(x); printf(")\n"); fflush(stdout);


/**************************************************************/

typedef struct state_t {
  ce_local_state_t *ls;
  ce_view_state_t *vs;
  ce_appl_intf_t *intf ;
  int blocked;
  /*let time     = ref Time.zero in
   let last_msg = ref Time.zero in */

} state_t;

static int nrecd = 0;
static int nsent = 0;
static int nmembers = 5;

#define IGNORE_SIZE 20

typedef struct msg_t{
  enum {
    TOKEN,
    SPEW,
    F_IGNORE
  } type;
  union {
    struct {
      ce_rank_t dest;
      int seqno;
    } token;
    struct {
      char buf[IGNORE_SIZE];
    } ignore;
  } u ;
} msg_t;

void fifo_recv_cast (state_t *s, ce_rank_t rank, msg_t *msg);
void fifo_recv_send (state_t *s, ce_rank_t rank, msg_t *msg);

/**************************************************************/

msg_t* token(ce_rank_t dest, int seqno){
  msg_t *msg;

  msg = record_create(msg_t*, msg);
  record_clear(msg);

  msg->type = TOKEN;
  msg->u.token.dest=dest;
  msg->u.token.seqno=seqno;

  return msg;
}

msg_t* spew(){
  msg_t *msg;

  msg = record_create(msg_t*, msg);
  record_clear(msg);

  msg->type = SPEW;
  
  return msg;
}

// buf should be a C-string.
//
msg_t* ignore(char *buf){
  msg_t *msg;

  msg = record_create(msg_t*, msg);
  record_clear(msg);

  msg->type = F_IGNORE;
  memcpy(msg->u.ignore.buf, buf, strlen(buf)); 

  return msg;
}

iov_t *marsh (msg_t *msg){
  iov_t *iov;

  iov = record_create(iov_t*, iov);
  iov->len= sizeof(msg_t);
  iov->data= malloc(iov->len);
  memcpy(iov->data, (char*)msg, iov->len);
  return iov;
}

msg_t *unmarsh(iov_t *iov){
  msg_t *msg;

  msg = (msg_t*) malloc(sizeof(msg_t));
  memcpy((char*)msg,iov->data,iov->len);

  return msg;
}

char* string_of_msg(msg_t *msg){
  char* s = NULL;
  
  switch (msg->type) {
  case TOKEN:
    s = malloc(20);
    sprintf(s, "TOKEN: %d:%d", msg->u.token.dest, msg->u.token.seqno);
    break;
    
  case SPEW:
    s = malloc(6);
    sprintf(s, "SPEW");
    break;
    
  case F_IGNORE:
    s = malloc(IGNORE_SIZE + 10);
    sprintf(s, "F_IGNORE: %s", msg->u.ignore.buf);
    break;
  }
  return s;
}

void send1(
	   ce_appl_intf_t *c_appl,
	   ce_rank_t dest,
	   msg_t *msg
	   ){
  char *data = NULL;
  iov_t *iov;

  iov = marsh(msg);
  TRACE("send1");
  ce_flat_Send1(c_appl, dest, iov->len, iov->data);

  free(msg);
  free(iov);
}

void send2(
	   ce_appl_intf_t *c_appl,
	   ce_rank_t dest1,
	   ce_rank_t dest2,
	   msg_t *msg
	   ){
  char *data = NULL;
  int *dests;
  iov_t *iov;

  iov = marsh(msg);
  dests = (int*) malloc(2 * sizeof(int));
  
  TRACE("send2");
  dests[0] = dest1;
  dests[1] = dest2;
  ce_flat_Send(c_appl, 2, dests, iov->len, iov->data);

  free(msg);
  free(iov);
}



void cast(
	  ce_appl_intf_t *c_appl,
	  msg_t *msg
	  ) {
  char *data = NULL;
  iov_t *iov;

  iov = marsh(msg);
  TRACE("cast");
  ce_flat_Cast(c_appl, iov->len, iov->data);
  free(msg);
  free(iov);
}


void main_recv_cast(void *env, int rank, int len, char* data) {
  state_t *s = (state_t*) env;
  iov_t iov;
  msg_t *msg;
  
  iov.len=len;
  iov.data=data;
  msg = unmarsh(&iov);

  fifo_recv_cast (s, rank, msg);
  free(msg);
}

void main_recv_send(void *env, int rank, int len, char* data) {
  state_t *s = (state_t*) env;
  msg_t *msg ;
  iov_t iov;
  
  iov.len=len;
  iov.data=data;
  msg = unmarsh(&iov);
  fifo_recv_send (s, rank, msg);
  free(msg);
}

/**************************************************************/
// Utitility functions

int random_member(ce_local_state_t *ls){
  int rank ;

  if (ls->nmembers == 1) {
    printf("Cannot send a message to myself\n");
    exit(1);
  }
  
  rank = (rand ()) % (ls->nmembers) ;
  if (rank == ls->rank) 
    return random_member(ls);
  else 
    return rank;
}

// Return  a floating point number in the range [0 - 1].
float float_rand() {
  return (rand() / (float)INT_MAX);
}

/**************************************************************/

void main_exit(void *env){}

void main_install(void *env, ce_local_state_t *ls, ce_view_state_t *vs){
  state_t *s = (state_t*) env;
  int i;

  ce_view_full_free(s->ls,s->vs);
  s->ls = ls;
  s->vs = vs;
  s->blocked = 0;
  TRACE2("main_install",s->ls->endpt);

  printf("FIFO: view=[");
  for(i=0; i<s->ls->nmembers; i++)
    printf("%s|", s->vs->view[i]);
  printf("]\n");

  if (s->ls->rank ==0 && s->ls->nmembers>=2){
    cast(s->intf, token(1,0));
  }
}


void main_flow_block(void *env, ce_rank_t rank, ce_bool_t onoff){
  state_t *s = (state_t*) env;

  TRACE2("main_flow_block",s->ls->endpt);
}

void main_block(void *env){
  state_t *s = (state_t*) env;

  s->blocked=1;
  TRACE2("main_block",s->ls->endpt); 
}

void fifo_recv_cast(state_t *s, int rank, msg_t *msg) {
  char *msg_s = string_of_msg(msg);
  int next ;
  
  TRACE2("fifo_recv_cast(", s->ls->endpt);
  //  printf("recv_cast <- %d msg=%s\n", rank, msg_s);

  if (s->blocked == 0) 
    switch(msg->type){
    case TOKEN:
      TRACE("TOKEN(");
      if (msg->u.token.dest == s->ls->rank) {
	if (float_rand() < 0.1)
	  cast(s->intf, spew());
	
	next = random_member (s->ls);
	cast(s->intf, token(next,(msg->u.token.seqno) + 1)) ;
	
	if (msg->u.token.seqno % 23 == 0) {
	  printf("FIFO:token=%d, %d->%d->%d\n",
		 msg->u.token.seqno, rank, s->ls->rank, next);
	}
	TRACE(")");
      }
      break;
      
    case SPEW: 
      if (float_rand() < 0.5) {
      	send1(s->intf, random_member(s->ls), ignore("junk"));
      	send2(s->intf, random_member(s->ls), random_member(s->ls),ignore("junk"));
      } else {
      	cast(s->intf, ignore("junk"));
      }
      break;
       
    case F_IGNORE:
      break;
      
    default:
      printf ("Error, bad message type\n");
      exit(1);
    }

  free(msg_s);
  TRACE(")");
}


void fifo_recv_send(state_t *s, int rank, msg_t *msg) {
  char *msg_s = string_of_msg(msg) ;

  TRACE2("fifo_recv_send", s->ls->endpt);
  free(msg_s);
}

void main_heartbeat(void *env, double time) {
  state_t *s = (state_t*) env;

  //  TRACE("main_heartbeat");
}

/**************************************************************/
void join(){
  ce_jops_t *jops; 
  ce_appl_intf_t *main_intf;
  state_t *s;
  
  /* The rest of the fields should be zero. The
   * conversion code should be able to handle this. 
   */
  jops = record_create(ce_jops_t*, jops);
  record_clear(jops);
  jops->transports = ce_copy_string("NETSIM");
  jops->group_name = ce_copy_string("ce_fifo");
  jops->properties = ce_copy_string(CE_DEFAULT_PROPERTIES);
  jops->use_properties = 1;
  jops->hrtbt_rate = 10.0;

  s = (state_t*) record_create(state_t*, s);
  record_clear(s);
    
  main_intf = ce_create_flat_intf(s,
			main_exit, main_install, main_flow_block,
			main_block, main_recv_cast, main_recv_send,
				  main_heartbeat);
  
  s->intf= main_intf;
  ce_Join(jops, main_intf);
}


void fifo_process_args(int argc, char **argv){
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
	ml_args++ ;
    }

    ret = (char**) malloc ((ml_args+3) * sizeof(char*));
    
    for(i=0, j=0; i<argc; i++) {
      if (strcmp(argv[i], "-n") == 0) {
	i++;
	continue;
      } else {
	ret[j]=argv[i];
	j++;
      }
    }
    ret[ml_args] = "-alarm";
    ret[ml_args+1] = "Netsim";
    ret[ml_args+2] = NULL;

    ce_Init(ml_args+2, ret); /* Call Arge.parse, and appl_process_args */
}

int main(int argc, char **argv){
  int i;

  fifo_process_args(argc, argv);
  
  for (i=0; i<nmembers; i++){
    join();
  }
  
  ce_Main_loop ();
  return 0;
}

