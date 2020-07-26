/**************************************************************/
/* CE_OUTBOARD_C.C */
/* Author: Ohad Rodeh 3/2002 */
/* Based on code by Mark Hayden and Alexey Vaysbrud. */
/**************************************************************/
#include "ce_internal.h"
#include "mm_basic.h"
#include "ce_trace.h"
#include "ce_context_table.h"
#include "ce_sock_table.h"
#include "ce_outboard_comm.h"
#include <stdio.h>

#ifdef _WIN32
#include "process.h"
#else
#include <stdarg.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <sys/types.h>
#include <sys/wait.h>
#endif

/**************************************************************/
#define NAME "CE_OUTBOARD_C"
/**************************************************************/

/* Global state.
 */
static struct {
    int initialized;		/* Set when initialized. */
    ce_ctx_tbl_t *ctx_tbl ;	/* allocated group contexts */
    ce_sock_tbl_t *sock_tbl ;	/* A list of user-assigned sockets */
    fd_set readfds;             /* A set of file descriptors to listen on */
    int nfds;                   /* The total number of user sockets */
    CE_SOCKET fd;			/* fd for communication w/ Ensemble */
    
    char *read_buf ;
    int read_size ;
    int read_pos ;
    int read_hdr_len ;
    int read_iov_len ;
    int read_act_size ;
    ce_iovec_t iovec;           /* An iovec for receiving messages */
    
    char *write_buf;		/* Buffer where we are writing to */
    int write_size;		/* Buffer size */
    int write_pos;		/* Current position in buffer */
    int write_hdr_len  ;
    int write_iov_len  ;
    int num_iovl ;              /* The number of iovectors in [iovl] */
    ce_iovec_array_t iovl;      /* A pointer to an iovec to send */
} g ;


/**************************************************************/
/* This is to maintain the memory conventions of the inboard
 * mode
 */
static void
free_iovl(int num, ce_iovec_array_t iovl)
{
    int i;
    
    for(i=0; i<num; i++)
	free(Iov_buf(iovl[i]));
    free(iovl);
}
/**************************************************************/


INLINE static void
begin_write(void)
{
  g.write_hdr_len = 0 ;
  g.write_iov_len = 0 ;
}

INLINE static void
do_write(void *buf,int len)
{

  if (len > g.write_size - g.write_pos) {
    if (g.write_size <= 1024)
      g.write_size = 1024 ;
    while (len > g.write_size - g.write_pos)
      g.write_size *= 2 ;
    if (!g.write_buf)
      g.write_buf = (char*) ce_malloc(g.write_size) ;
    else
      g.write_buf = (char*) ce_realloc(g.write_buf, g.write_size) ;
  }

  memcpy(((char*)g.write_buf)+g.write_pos, buf, len) ;
  g.write_pos += len ;
}

/* Take note to first write the ML length, and then
 * the iovec length. 
 */
INLINE static void
end_write(void)
{
    int size ;
    
    /* Compute header length, and ML header length.
     * In case these arguments have not been set, then
     * this must be a case where send_msg has not been
     * called. Hence, the iovec length is zero, and the
     * ML header length is equal to our current position
     * in the write buffer. 
     */
    if (g.write_hdr_len == 0 && g.write_iov_len == 0) {
	g.write_hdr_len = g.write_pos;
	g.write_iov_len = 0;
    }
    ce_trace("  **** write_hdr_len=%d write_iov_len=%d  ****",
	  g.write_hdr_len, g.write_iov_len);
    
    /* Write header length
     */
    size = htonl(g.write_hdr_len) ;
    tcp_send(g.fd, sizeof(size), (char*)&size);
    
    /* Write iovec length
     */
    size = htonl(g.write_iov_len) ;
    tcp_send(g.fd, sizeof(size), (char*) &size);

    
    if (g.write_iov_len == 0)
	tcp_send(g.fd, g.write_pos, g.write_buf); 
    else
	tcp_send_iov(g.fd, g.write_hdr_len, g.write_buf,
		     g.num_iovl, g.iovl);
    
    g.write_pos = 0 ;
    g.write_iov_len = 0;
    free_iovl(g.num_iovl, g.iovl);
    g.iovl = NULL;
    g.num_iovl = 0;

    /* Shrink the buffer if it is >64K.
     */
    if (g.write_size > 1<<16) {
	g.write_size = 1<<12 ;
	g.write_buf = ce_realloc(g.write_buf, g.write_size) ;
    }
    
}

INLINE static void
begin_read(void)
{
    int net_size;
    
    /* Read the length, this is the total ML and iovec length.
     * A total of 8 bytes should be read. 
     */
    tcp_recv(g.fd, sizeof(net_size), (char*)&net_size);
    g.read_hdr_len = ntohl(net_size) ;
    tcp_recv(g.fd, sizeof(net_size), (char*)&net_size);
    g.read_iov_len = ntohl(net_size);
    
    /* Ensure there is enough room in the read buffer.
     */
    if (g.read_hdr_len > g.read_act_size) {
	if (g.read_act_size <= 1024)
	    g.read_act_size = 1024 ;
	while(g.read_hdr_len > g.read_act_size)
	    g.read_act_size *= 2 ;
	if (g.read_buf) {
	    g.read_buf = (char*) ce_realloc(g.read_buf, g.read_act_size) ;
	} else {
	    g.read_buf = (char*) ce_malloc(g.read_act_size) ;
	}
    }
    
    /* Keep reading until we have the entire message.
     */
    g.read_pos = 0 ;
    g.read_size = g.read_hdr_len ;

    if (g.read_iov_len == 0)
	tcp_recv(g.fd,g.read_hdr_len, g.read_buf);
    else {
	Iov_len(g.iovec) = g.read_iov_len;
	Iov_buf(g.iovec) = mm_alloc_fun(g.read_iov_len);
	tcp_recv_iov(g.fd, g.read_hdr_len, g.read_buf, &g.iovec);
    }
    g.read_pos = 0 ;
}

INLINE static void
do_read(void *buf,int len)
{
    assert(len <= g.read_size - g.read_pos) ;
    memcpy(buf,((char*)g.read_buf)+g.read_pos,len) ;
    g.read_pos += len ;
}

INLINE static void
end_read(void)
{
    assert(g.read_pos == g.read_size) ;
    
    g.read_pos = 0 ;
    g.read_size = 0 ;
    Iov_len(g.iovec) = 0;

    /* To match the semantics of the inboard mode, we need to free
     * the buffer.
     */
    mm_free_fun(Iov_buf(g.iovec));
    Iov_buf(g.iovec) = NULL;
}

INLINE static void
force_end_read(void)
{
    g.read_pos = g.read_size;
}

/*********************** Endpoint Arrays ******************************/

/* Downcalls into Ensemble.  Must match the ML side.
 */
typedef enum {
    DN_JOIN,
    DN_CAST,
    DN_SEND,
    DN_SEND1,
    DN_SUSPECT,
    DN_XFERDONE,
    DN_PROTOCOL,
    DN_PROPERTIES,
    DN_LEAVE,
    DN_PROMPT,
    DN_REKEY,
    DN_BLOCK_OK,
} ce_dnType_t;

static const char *
string_of_dnType(ce_dnType_t t) {
    switch (t) {
#define CASE(s) case s: return #s ; break
        CASE(DN_JOIN) ;
        CASE(DN_CAST) ;
        CASE(DN_SEND) ;
        CASE(DN_SEND1) ;
        CASE(DN_SUSPECT) ;
	CASE(DN_XFERDONE) ;
        CASE(DN_PROTOCOL) ;
        CASE(DN_PROPERTIES) ;
        CASE(DN_LEAVE) ;
        CASE(DN_PROMPT) ;
	CASE(DN_REKEY) ;
        CASE(DN_BLOCK_OK) ;
#undef CASE
    default:
	ce_panic("bad dncall type");
	return ""; 
    }
}

/* Callbacks from Ensemble.  Must match the ML side.
 */
typedef enum {
    CB_VIEW,
    CB_CAST,
    CB_SEND,
    CB_HEARTBEAT,
    CB_BLOCK,
    CB_EXIT
} cbType_t;


static const char*
string_of_cbType(cbType_t cb)
{
    switch (cb){
#define CASE(s) case s: return #s ; break
	CASE(CB_VIEW);
	CASE(CB_CAST);
	CASE(CB_SEND);
	CASE(CB_HEARTBEAT);
	CASE(CB_BLOCK);
	CASE(CB_EXIT);
#undef CASE
    default:
	ce_panic("bad callback type");
	return ""; 
    }
}


#define INT_SIZE sizeof(int)

INLINE static void
write_int(int i)
{
    int tmp = htonl(i);
    do_write(&tmp,INT_SIZE) ;
    ce_trace("write_int: %d", i);
}

INLINE static void
write_bool(ce_bool_t b)
{
    int i = b;
    write_int(i);
}

INLINE static void
write_buffer(void *body, int size)
{
    int i = htonl(size);

    if (size==0) {
	write_int(0) ;
	return;
    }

    assert(body);
    do_write(&i, INT_SIZE) ;
    do_write(body, size) ;

    ce_trace("write_buf_len: %d", size);
    ce_trace("write_buffer: %s", (char*) body);
}

INLINE static void
write_string(char *s)
{
    if (s==NULL)
	write_buffer(NULL,0);
    else
	write_buffer(s,strlen(s) /*+ 1*/); 
}

/* Convert time in double, to the Ensemble format: 
 * (1) sec10, an integer describing time in 10s of seconds.
 * (2) usec, an integer describing time 10s of microseconds.
 */
#define MILLION 1000000

INLINE static void
write_time(double time)
{
    double tmp;
    int sec10;
    int usec10;

    tmp = time / 10.0;
    
    sec10 =  (int) tmp;
    usec10 = (int)((tmp - sec10) * MILLION) ;
    //printf("sec10=%d, usec10=%d\n", sec10, usec10);
    write_int(sec10);
    write_int(usec10);
}


INLINE static void
write_endpID(ce_endpt_t ep)
{
    write_string(ep);
}

struct header {
    int id ;
    int type ;
} ;

INLINE static void
write_hdr(ce_ctx_t *s, ce_dnType_t type)
{
    struct header h ;
    assert(s) ;
    ce_trace("write_hdr:id=%d, type=%d(%s)",s->intf->id, type, string_of_dnType(type)) ;
    h.id = htonl(s->intf->id) ;
    h.type = htonl(type) ;
    do_write(&h,sizeof(h)) ;
}

/* write_iovl is the last call before a message is packaged and
 * sent. Therefore, we record the iovec length, and the header
 * length, so that end_write will write this on the outgoing
 * packet. 
 */
INLINE static void
write_iovl(int num, ce_iovec_array_t iovl)
{
    int size, i;
    
    /* Compute total size.
     */
    for(i=0, size=0; i<num ; i++)
	size+=Iov_len(iovl[i]);

    /* Put the actual size on the message.
     */
    g.write_hdr_len  = g.write_pos;
    g.write_iov_len  = size;
   
    /* Attach the iovec to the global structure.
     */
    g.num_iovl = num;
    g.iovl = iovl;
	
    ce_trace("write_iovl: size = %d", size);
}


INLINE static int
read_int(void)
{
    int tmp;
    do_read(&tmp, INT_SIZE);
    tmp = ntohl(tmp);
    ce_trace("read_int: %d", tmp);
    return tmp;
}

INLINE static ce_bool_t
read_bool(void)
{
    int tmp;
    tmp = read_int();
    return (tmp != 0) ;
}


/* Here, we read a 64bit value, split into:
 * sec10, an integer describing time in 10s of seconds.
 * usec, an integer describing time 10s of microseconds.
 */
#define MILLION 1000000

INLINE static ce_float_t
read_time(void)
{
    double tmp;
    int sec10;
    int usec10;

    sec10 = read_int();
    usec10 = read_int();
    tmp = (sec10 * 10 * MILLION + usec10 * 10) / MILLION;
    
    return tmp;
}


/* Allocate and copy into a buffer.
 */
INLINE static char *
read_string(void)
{
    int size, tmp;
    char *buf;

    do_read(&tmp, INT_SIZE);
    size = ntohl(tmp);
    buf = (char*) ce_malloc(size+1);
    do_read(buf, size);
    buf[size] = 0;
    ce_trace("read_string: <%d> %s", size, buf);

    return buf;
}

INLINE static ce_endpt_t
read_endpt(void)
{
    return (ce_endpt_t) read_string();
}

INLINE static ce_ctx_id_t
read_contextID(void)
{
    return read_int();
}

/* See comments on write_iovl().
 */
INLINE static ce_iovec_t *
read_iovl(void)
{
    if (g.read_iov_len == 0)
	return NULL;
    return &(g.iovec);
}

INLINE static ce_endpt_array_t
read_endpt_array(void)
{
    int i, size;
    ce_endpt_array_t epa;

    size = read_int ();
    epa = (ce_endpt_array_t) ce_malloc((size+1) *sizeof(int)); 

    for (i = 0; i < size; i++)
	epa[i] = read_endpt();
    epa[size] = NULL;

    return epa;
}

INLINE static ce_addr_array_t
read_addr_array(void)
{
    int i, size;
    ce_addr_array_t aa;

    size = read_int ();
    aa = (ce_addr_array_t) ce_malloc((size+1) *sizeof(int)); 

    for (i = 0; i < size; i++)
	aa[i] = read_string();
    aa[size] = NULL;

    return aa;
}

INLINE static cbType_t
read_cbType(void)
{
    return read_int();
}


INLINE static ce_view_id_t *
read_view_id(void)
{
    ce_view_id_t *vid;

    vid = (ce_view_id_t*) ce_malloc(sizeof(ce_view_id_t));
    vid -> ltime = read_int();
    vid -> endpt = read_string();

    return vid;
}

static ce_view_id_array_t  
read_view_id_array(void)
{
    ce_view_id_array_t a;
    int i, num;

    num = read_int ();
    a = (ce_view_id_array_t) ce_malloc((num+1) * sizeof(int));
    for (i=0; i<num; i++)
	a[i] = read_view_id();
    a[num] = NULL;
    return a;
}

/************************** Callback processing ****************************/

static ce_ctx_t * alloc_context(ce_ctx_id_t id);
static void release_context(ce_ctx_t *);
static ce_ctx_t *lookup_context(ce_ctx_id_t id);

static void
cb_View(ce_ctx_t *s)
{
    ce_view_state_t *vs;
    ce_local_state_t *ls;
    
    ls = record_create(ce_local_state_t*,ls);
    vs = record_create(ce_view_state_t*,vs);
    record_clear(ls);
    record_clear(vs);
    
    ce_trace("VIEW");

    /* Reading local state
     */
    ls->endpt = read_endpt ();
    ls->addr =  read_string ();
    ls->rank = read_int ();
    ce_trace("\t rank: %d", ls->rank);
    ls->name = read_string ();
    ls->nmembers = read_int ();
    ls->view_id = read_view_id ();
    ce_trace("\t view_id.ltime: %d", ls->view_id->ltime);
    ce_trace("\t view_id.coord: %s", ls->view_id->endpt);
    ls->am_coord = read_bool ();

    /* Reading view state
     */
    vs->version = read_string ();
    ce_trace("\t version: %s", vs->version);
    vs->group = read_string ();
    ce_trace("\t group_name: %s", vs->group);
    vs->proto = read_string ();
    ce_trace("\t protocol: %s", vs->proto);
    vs->coord = read_int ();
    vs->ltime = read_int ();
    vs->primary = read_bool ();
    ce_trace("\t primary: %d", vs->primary);
    vs->groupd = read_bool ();
    ce_trace("\t groupd: %d", vs->groupd);
    vs->xfer_view = read_bool ();
    ce_trace("\t xfer_view: %d", vs->xfer_view);
    vs->key = read_string ();
    ce_trace("\t key: %s", vs->key);
    vs->num_ids = read_int ();
    vs->prev_ids = read_view_id_array ();
    vs->params = read_string ();
    ce_trace("\t params: %s", vs->params);
    vs->uptime = read_time ();
    vs->view = read_endpt_array ();
    ce_trace("\t nmembers: %d", ls->nmembers);
    { 
	int i;
	for (i = 0; i < ls->nmembers; i++)
	    ce_trace("\t\t member[%d] = %s", i, vs->view[i]);
    }
    vs->address = read_addr_array ();
    
    /* The group is unblocked now.
     */
    s->blocked = 0;
    s->nmembers = ls->nmembers ;
    if (s->intf->install != NULL)
	(s->intf->install) (s->intf->env, ls, vs);

    s->joining = 0 ;
}

static void
cb_Cast(ce_ctx_t *s)
{
    int origin ;
    ce_iovec_array_t iovl;

    ce_trace("cb_Cast");
    origin = read_int();
    iovl = read_iovl();
    
    assert(origin < s->nmembers) ;

    if (s->intf->receive_cast != NULL) 
	(s->intf->receive_cast) (s->intf->env, origin, 1, iovl);
}

static void
cb_Send(ce_ctx_t *s)
{
    int origin ;
    ce_iovec_array_t iovl;

    ce_trace("cb_Cast");
    origin = read_int();
    iovl = read_iovl();
    
    assert(origin < s->nmembers) ;

    if (s->intf->receive_send != NULL) 
	(s->intf->receive_send) (s->intf->env, origin, 1, iovl);
}

static void
cb_Heartbeat(ce_ctx_t *s)

{
    double time;

    time = read_time();
 
    if (s->intf->heartbeat != NULL)
	(s->intf->heartbeat)(s->intf->env, time);
}

static void
cb_Block(ce_ctx_t *s)
{
    if (s->intf->block != NULL)
	(s->intf->block)(s->intf->env);
    s->blocked = 1;

    /* Write the block_ok downcall.
     */
    begin_write(); {
	write_hdr(s,DN_BLOCK_OK) ;
    } end_write();
}

static void
cb_Exit(ce_ctx_t *s)
{
    
    if (!s->leaving)
	ce_panic("ce_Exit_cbd: mbr state is not leaving");
    
    if (s->intf->exit != NULL)
	(s->intf->exit)(s->intf->env);

    release_context(s);
}

typedef void (*cback_f)(ce_ctx_t*);
static cback_f ce_callback[6] = { 
    cb_View, 
    cb_Cast, 
    cb_Send, 
    cb_Heartbeat, 
    cb_Block, 
    cb_Exit 
};

/* Loop reading + processing Ensemble upcalls.
 */
void
ce_intrn_Main_loop()
{
    ce_ctx_id_t id;
    cbType_t cb;
    struct timeval tv;
    int res;
    ce_ctx_t *s;
    
    while (1) {
	/* Prepare all data structures for this iteration.
	 */
	tv.tv_sec=1000;
	tv.tv_usec=0;
	FD_ZERO(&g.readfds);
	FD_SET(g.fd, &g.readfds);
	ce_sock_tbl_fdset(g.sock_tbl, &g.readfds);
	
#ifndef _WIN32
	res= select(FD_SETSIZE, &g.readfds, NULL, NULL, &tv);
#else
	res= select(1 + g.nfds, &g.readfds, NULL, NULL, &tv);
#endif
	
	if (res==0) continue;

	/* Call user-handlers if there is input on the user-sockets.
	 */
	ce_sock_tbl_invoke(g.sock_tbl, &g.readfds);
	
	if (FD_ISSET(g.fd, &g.readfds)){
	    begin_read() ; {
		id = read_contextID();
		ce_trace("CALLBACK: group ID: %d", id);
		
		cb = read_cbType();
		ce_trace("CALLBACK: callback type: %s", string_of_cbType(cb));
		
		if (cb > CB_EXIT) {
		    ce_trace("bad callback type (%d)", cb);
		    ce_panic("");
		}
		s = lookup_context(id);


		/* We block any upcalls to an endpoint
		 * after it requested to leave.
		 */
		if (s->leaving == 0)
		    (*(ce_callback[cb]))(s);
		else
		    if (cb == CB_EXIT)
			(*(ce_callback[cb]))(s);
		    else
			force_end_read();
	    } end_read () ;
	} 
    }
}

/**************************************************************/

void
ce_intrn_AddSockRecv(CE_SOCKET sock, ce_handler_t handler, ce_env_t env)
{
    TRACE("ce_AddSockRecv");
    ce_sock_tbl_insert(g.sock_tbl, sock, handler, env);
    FD_SET(sock, &g.readfds);
    g.nfds++;
}

void
ce_intrn_RmvSockRecv(CE_SOCKET sock)
{
    ce_sock_tbl_remove(g.sock_tbl, sock);
    FD_CLR(sock, &g.readfds);
    g.nfds--;
}

/*************************** Initialization *********************************/

/* Initialize Ensemble.
 */ 
void 
ce_intrn_Init(int argc, char *argv[])
{
    ce_trace("ce_Init");

    /* Process command line arguments. 
     */
    ce_process_args(argc, argv);
    
    /* Start Ensemble in an outboard mode.
     */ 
    ens_tcp_init(0, argv, &g.fd);

    g.initialized = 1;
    g.ctx_tbl = ce_ctx_tbl_t_create();
    g.sock_tbl = ce_sock_tbl_t_create();
    FD_ZERO(&g.readfds);
    g.nfds = 0;
}

/****************************** Context management ****************************/

/* Allocate a new context.
 * The global data record must be locked at this point.
 */
static ce_ctx_t *
alloc_context(ce_ctx_id_t id)
{
    ce_ctx_t *ctx;

    ce_trace("alloc_context <%d>", id);
    ctx = (ce_ctx_t*) ce_malloc(sizeof(ce_ctx_t)) ;
    ce_ctx_tbl_insert(g.ctx_tbl, id, ctx);
    
    return ctx;
}

/* Release a context descriptor.
 */
static void
release_context(ce_ctx_t *ctx)
{
    ce_ctx_tbl_remove(g.ctx_tbl, ctx->intf->id);
}

/* Lookup a context descriptor.
 */
static ce_ctx_t *
lookup_context(ce_ctx_id_t id)
{
    return ce_ctx_tbl_lookup(g.ctx_tbl, id);
}

/************************ User Downcalls ****************************/

/* Join a group.  The group context is returned in *contextp.  
 */
void
ce_intrn_Join(ce_jops_t *ops,	ce_appl_intf_t *c_appl) 
{
    ce_ctx_t *ctx ;

    /* Initialize global state if not done so already.
     */
    if (!g.initialized) {
	printf("CE_OUTBOARD: must initialise Ensemble.");
	exit(1);
    }
    begin_write(); {   
	/* Allocate a new group context 
	 * Initialize the group record.
	 */
	ctx = alloc_context(c_appl->id);
	ctx->nmembers = 1;
	ctx->blocked = 1 ;
	ctx->joining = 1 ;
	ctx->leaving = 0 ;
	ctx->intf = c_appl;
	
	/* Write the downcall.
	 */
  	write_hdr(ctx,DN_JOIN);
	write_time(ops->hrtbt_rate);
	write_string(ops->transports);
	ce_trace(".");
	write_string(ops->protocol);
	ce_trace(".");
	write_string(ops->group_name);
	ce_trace("write ops->properties:");
	write_string(ops->properties);
	ce_trace("write ops->use_properties:");
	write_bool(ops->use_properties);
	ce_trace("write ops->groupd:");
	write_bool(ops->groupd);
	ce_trace("write ops->params:");
	write_string(ops->params);
	ce_trace("write ops->client:");
	write_bool(ops->client);
	ce_trace("write ops->debug:");
	write_bool(ops->debug);
	
	if (ops->endpt != NULL) {
	    printf("CE_OUTBOARD does not support 'endpt' in join ops\n");
	    ops->endpt = NULL;
	}
	write_string(ops->princ);
	write_string(ops->key);
	write_bool(ops->secure);

	ce_jops_free(ops);
    } end_write();
}

/* Leave a group.  This should be the last call made to a given context.
 * No more events will be delivered to this context after the call
 * returns.  
 */
void
ce_intrn_Leave(ce_appl_intf_t *intf)
{
    ce_ctx_t *s = lookup_context(intf->id);

    begin_write(); {
	if (s->leaving) 
	    ce_panic("ce_Leave:this member is already leaving") ;
	s->leaving = 1 ;
	
	/* Write the downcall.
	 */
	write_hdr(s,DN_LEAVE);
    } end_write();
}

/* Send a multicast message to the group.
 */
void
ce_intrn_Cast(ce_appl_intf_t *intf,  int num, ce_iovec_array_t iovl)
{
    ce_ctx_t *s = lookup_context(intf->id);
    
    begin_write(); {
	if (s->leaving)
	    ce_panic("ce_Cast: member is leaving") ;
	
	/* Write the downcall.
	 */
	write_hdr(s,DN_CAST);
	write_iovl(num, iovl);
    } end_write();
}

/* Send a point-to-point message to a list of members.
 */
void
ce_intrn_Send(
    ce_appl_intf_t *c_appl,
    int num_dests,
    ce_rank_array_t dests,
    int num,
    ce_iovec_array_t iovl
    )
{
    ce_ctx_t *s = lookup_context(c_appl->id);
    int i;
    
    begin_write(); { 
	if (s->leaving)
	    ce_panic("ce_Send: member is leaving") ;
	
	if (s->blocked) 
	    ce_panic("ce_Send: member is blocked") ;

	write_hdr(s,DN_SEND);
	write_int(num_dests);
	for (i=0; i<num_dests; i++) {
	    assert(dests[i] < s->nmembers) ;
	    write_int(dests[i]);
	}
	free(dests);
	write_iovl(num, iovl);
    } end_write();
}

/* Send a point-to-point message to the specified group member.
 */
void
ce_intrn_Send1(ce_appl_intf_t *intf, ce_rank_t dest, int n, ce_iovec_array_t iovl)
{
    ce_ctx_t *s = lookup_context(intf->id);

    begin_write(); { 
	if (s->leaving)
	    ce_panic("ce_Send: member is leaving") ;
	
	if (s->blocked) 
	    ce_panic("ce_Send: member is blocked") ;

	assert(dest<s->nmembers) ;
	write_hdr(s,DN_SEND1);
	write_int(dest);
	write_iovl(n, iovl);
    } end_write();
}

/* Report group members as failure-suspected.
 * 
 */
void
ce_intrn_Suspect(
	ce_appl_intf_t *c_appl,
	int num,
	ce_rank_array_t suspects
    )
{
    ce_ctx_t *s = lookup_context(c_appl->id);
    int i;

    begin_write(); {
	if (s->leaving) 
	    ce_panic("ce_Suspect: member is leaving") ;
	write_hdr(s,DN_SUSPECT);
	write_int(num);
	for (i=0; i<num; i++) {
	    assert(suspects[i] < s->nmembers);
	    write_int(suspects[i]);
	}

	free(suspects);
    } end_write();
}

/* Inform Ensemble that the state-transfer is complete. 
 */
void
ce_intrn_XferDone(ce_appl_intf_t *c_appl)
{
    ce_ctx_t *s = lookup_context(c_appl->id);

    begin_write(); {
	if (s->leaving) 
	    ce_panic("ce_XferDone: member is leaving") ;
	write_hdr(s,DN_XFERDONE);
    } end_write();
}



/* Request a protocol change.
 */
void
ce_intrn_ChangeProtocol(ce_appl_intf_t *c_appl, char *protocol_name)
{
    ce_ctx_t *s = lookup_context(c_appl->id);

    assert(protocol_name);
    begin_write(); {
	if (s->leaving) 
	    ce_panic("ce_ChangeProtocol: member is leaving") ;
	write_hdr(s,DN_PROTOCOL);
	write_string(protocol_name); 
	free(protocol_name);
    } end_write();
}

/* Request a protocol change specifying properties.
 */
void
ce_intrn_ChangeProperties(ce_appl_intf_t *c_appl, char *properties)
{
    ce_ctx_t *s = lookup_context(c_appl->id);

    assert(properties) ;
    begin_write(); {
	if (s->leaving) 
	    ce_panic("ce_ChangeProperties: member is leaving") ;
	write_hdr(s,DN_PROPERTIES);
	write_string(properties);
	free(properties);
    } end_write();
}

/* Request a new view to be installed.
 */
void
ce_intrn_Prompt(ce_appl_intf_t *c_appl)
{
    ce_ctx_t *s = lookup_context(c_appl->id);

    begin_write(); {
	if (s->leaving) 
	    ce_panic("ce_Prompt: member is leaving") ;
	write_hdr(s,DN_PROMPT);
    } end_write();
}


/* Request a Rekey operation.
 */
void
ce_intrn_Rekey(ce_appl_intf_t *c_appl)
{
    ce_ctx_t *s = lookup_context(c_appl->id);

    begin_write(); {
	if (s->leaving)
	    ce_panic("ce_Rekey: member is leaving") ;
	write_hdr(s,DN_REKEY);
    } end_write();
}

/*****************************************************************************/
/* These are both no-ops for the outboard mode.
 */

void ce_intrn_MLPrintOverride(
	void (*handler)(char *msg)
) {
    return;
}

void ce_intrn_MLUncaughtException(
	void (*handler)(char *info)
) {
    return;
}

/*****************************************************************************/

