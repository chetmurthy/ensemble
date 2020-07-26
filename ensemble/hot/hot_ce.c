/****************************************************************************/
/* CE_HOT.C */
/* Author:  Ohad Rodeh, 4/2002. */
/* HOT compatibility wrapper. */
/****************************************************************************/
#include "ce.h"
#include "ce_trace.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "hot_sys.h"
#include "hot_error.h"
#include "hot_thread.h"
#include "hot_msg.h"
#include "hot_mem.h"
#include "hot_ens.h"

#include "hot_endpt_tbl.h"
/****************************************************************************/
#define NAME "HOT_CE"
/****************************************************************************/
static char *
hot_malloc(int size)
{
    void *ptr;
    
    ptr = malloc(size);
    if (ptr == NULL) {
	printf("Out of memory, exiting\n");
	exit(1);
    }
    return ptr;
}

/* A static variable, have we been initialized? 
 */
static int initialized = 0;
/****************************************************************************/

struct hot_gctx {
    ce_appl_intf_t *intf;
    void *user_env;
    hot_ens_cbacks_t conf;

    /* The current view
     */
    int nmembers ;      
    hot_endpt_t *view ;     /* A flat array of endpoints */
    hot_endpt_tbl_t *tbl;   /* A hash table mapping endpoints to rank */
};


static void
destroy_context(hot_gctx_t gctx)
{
    /* The interface is freed by CE automatically
     */
    free(gctx->view);
    hot_endpt_tbl_t_free(gctx->tbl);
    free(gctx);
}


/* Copy the message into a fresh string.
 */
static void
msg_of_hot_msg(hot_msg_t msg, /*OUT*/ int *len, char **send_data)
{
    void *data;
    hot_err_t err;
    
    err = hot_msg_GetPos(msg, len);
    if (err != HOT_OK)
	hot_sys_Panic(hot_err_ErrString(err));
    err = hot_msg_Look(msg, *len, &data);
    if (err != HOT_OK)
	hot_sys_Panic(hot_err_ErrString(err));
    
    *send_data = hot_malloc(*len);
    memcpy(*send_data, (char*)data, *len);
}

/* Copy (len,data) into a fresh msg
 */
static hot_msg_t
hot_msg_of_msg(int len, char *data)
{
    hot_msg_t msg ;
    hot_err_t err;
    
    msg = hot_msg_Create() ;
    assert(data != NULL);
    msg = hot_msg_CreateDontCopy(data, len, NULL, NULL);    
    return msg;
}

/* new is preallocated
 */
static hot_endpt_t *
copy_ce_endpt(ce_endpt_t e, /*OUT*/ hot_endpt_t *new)
{
    strncpy(new->name, e, HOT_ENDP_MAX_NAME_SIZE) ;
    return new;
}

static void
hot_view_state_of_vs(
    ce_local_state_t *ls, ce_view_state_t *vs,
    /*OUT*/ hot_view_state_t *view_state)
{
    int i;
    strncpy(view_state->version, vs->version, HOT_ENS_MAX_VERSION_LENGTH) ;
    strncpy(view_state->group_name, vs->group, HOT_ENS_MAX_GROUP_NAME_LENGTH) ;
    
    view_state->members =
	(hot_endpt_t*) hot_malloc(sizeof(hot_endpt_t) * ls->nmembers);
    for(i=0; i<ls->nmembers; i++)
	copy_ce_endpt(vs->view[i], &view_state->members[i]);

    view_state->nmembers = ls->nmembers;
    view_state->rank = ls->rank;
    strncpy(view_state->protocol, vs->proto, HOT_ENS_MAX_PROTO_NAME_LENGTH) ;
    view_state->groupd = vs->groupd;

    view_state->view_id.ltime = ls->view_id->ltime;
    strncpy(view_state->view_id.coord.name, ls->view_id->endpt, HOT_ENDP_MAX_NAME_SIZE);

    strncpy(view_state->params, vs->params, HOT_ENS_MAX_PARAMS_LENGTH) ;
    view_state->xfer_view = vs->xfer_view;
    view_state->primary = vs->primary;
    view_state->clients = NULL;
    strncpy(view_state->key, vs->key, HOT_ENS_MAX_KEY_LEGNTH);
}

/****************************************************************************/

static void
hot_ce_exit(ce_env_t env)
{
    hot_gctx_t gctx = (hot_gctx_t) env;
    gctx->conf.exit(gctx, gctx->user_env);
    destroy_context(gctx);
}

static void
hot_ce_install(ce_env_t env ,ce_local_state_t *ls, ce_view_state_t *vs)
{
    int i;
    hot_gctx_t gctx = (hot_gctx_t) env;
    hot_view_state_t view_state;
    hot_endpt_t tmp;
    
    /* Convert the view state 
     */
    hot_view_state_of_vs(ls, vs, &view_state);

    /* update the group-context
     */
    if (gctx->view != NULL) free(gctx->view);
    hot_endpt_tbl_t_free(gctx->tbl);
    gctx->nmembers = ls->nmembers;
    gctx->view = view_state.members;
    gctx->tbl = hot_endpt_tbl_t_create(ls->nmembers);
    for (i=0; i<ls->nmembers; i++)
	hot_endpt_tbl_insert(gctx->tbl,
			     copy_ce_endpt(vs->view[i], &tmp), i);

    /* deliver
     */
    gctx->conf.accepted_view(gctx, gctx->user_env, &view_state);

    /* Free anything that has been allocated on the heap
     * There is no need for this, because gctx->view points to
     * the view structure already. It will be freed automatically
     * in the next view installed. 
     */
    //free(view_state.members);
    ce_view_full_free(ls,vs);
}

static void
hot_ce_flow_block(ce_env_t env, ce_rank_t origin, ce_bool_t onoff)
{
}

static void
hot_ce_block(ce_env_t env)
{
    hot_gctx_t gctx = (hot_gctx_t) env;
    gctx->conf.block(gctx, gctx->user_env);
}

static void
hot_ce_cast(ce_env_t env, ce_rank_t origin, int len, char *data)
{
    hot_gctx_t gctx = (hot_gctx_t) env;
    hot_endpt_t *e = &gctx->view[origin];
    hot_msg_t msg;
    hot_err_t err;
    
    msg = hot_msg_of_msg(len, data);
    gctx->conf.receive_cast(gctx, gctx->user_env, e, msg);
    err = hot_msg_Release(&msg);
    if (err != HOT_OK)
	hot_sys_Panic(hot_err_ErrString(err));
}

static void
hot_ce_send(ce_env_t env, ce_rank_t origin, int len, char *data)
{
    hot_gctx_t gctx = (hot_gctx_t) env;
    hot_endpt_t *e = &gctx->view[origin];
    hot_msg_t msg;
    hot_err_t err;
    
    msg = hot_msg_of_msg(len, data);
    gctx->conf.receive_send(gctx, gctx->user_env, e, msg);
    err = hot_msg_Release(&msg);
    if (err != HOT_OK)
	hot_sys_Panic(hot_err_ErrString(err));
}

/* Convert time in seconds to time in milliseconds.
 */
static void
hot_ce_heartbeat(ce_env_t env, ce_time_t time)
{
    hot_gctx_t gctx = (hot_gctx_t) env;
    gctx->conf.heartbeat(gctx, gctx->user_env, (int) time * 1000);
}


static hot_gctx_t 
create_intf(void *user_env, hot_ens_cbacks_t *conf)
{
    hot_gctx_t gctx;
    ce_appl_intf_t *intf;

    TRACE("ce_create_intf(");
    gctx = (hot_gctx_t) hot_malloc(sizeof(struct hot_gctx));
    memset(gctx, 0, sizeof(struct hot_gctx));
    intf = ce_create_flat_intf((void*)gctx, hot_ce_exit, hot_ce_install,
			       hot_ce_flow_block, hot_ce_block, hot_ce_cast,
			       hot_ce_send, hot_ce_heartbeat);
    TRACE(".");
    gctx->intf = intf;
    gctx->user_env = user_env;
    TRACE(".");
    gctx->conf.receive_cast = conf->receive_cast ;
    TRACE(".");
    gctx->conf.receive_send = conf->receive_send ;
    gctx->conf.accepted_view = conf->accepted_view ;
    gctx->conf.heartbeat = conf->heartbeat ;
    gctx->conf.block = conf->block ;
    gctx->conf.exit = conf->exit ;

    TRACE(")");

    return gctx;
}

static ce_jops_t *
ce_of_hot_ops(hot_ens_JoinOps_t *ops)
{
    ce_jops_t *res;

    res = (ce_jops_t*) hot_malloc(sizeof(ce_jops_t));

    res->hrtbt_rate = ops->heartbeat_rate / 1000 ;
    res->transports = ce_copy_string(ops->transports);
    res->protocol = ce_copy_string(ops->protocol);
    res->group_name = ce_copy_string(ops->group_name);
    res->properties = ce_copy_string(ops->properties);
    res->use_properties = ops->use_properties;
    res->groupd = ops->groupd;
    res->params = ce_copy_string(ops->params);
    res->client = ops->client;
    res->debug = ops->debug;
    res->endpt = ce_copy_string(ops->endpt.name);
    res->princ = ce_copy_string(ops->princ);
    res->key = ce_copy_string(ops->key);
    res->secure = ops->secure;
    return res;
}
/****************************************************************************/

/* Start Ensemble in the current thread.  
 * If successful, this call will block forever.
 */
hot_err_t
hot_ens_Start(char **argv)
{
    int num=0;

    /* We need to recompute argc for compatibility
     */
    while (argv[num] != NULL) num++;
    ce_Init(num, argv);
    initialized = 1;
    return HOT_OK;
}

/* Initialize/reset an options struct.
 */
void
hot_ens_InitJoinOps(hot_ens_JoinOps_t *ops)
{
    if (ops == NULL)
	hot_sys_Panic("hot_ens_InitJoinOps: bad argument (NULL)");
    
    memset(ops, 0, sizeof(hot_ens_JoinOps_t));
    ops->heartbeat_rate = HOT_ENS_DEFAULT_HEARTBEAT_RATE;
    strcpy(ops->transports, HOT_ENS_DEFAULT_TRANSPORT);
    strcpy(ops->group_name, HOT_ENS_DEFAULT_GROUP_NAME);
    strcpy(ops->protocol, HOT_ENS_DEFAULT_PROTOCOL);
    strcpy(ops->properties, HOT_ENS_DEFAULT_PROPERTIES);
    ops->use_properties = 1;
    strcpy(ops->params, "");
    strcpy(ops->princ, "");
    strcpy(ops->key, "");
    ops->groupd = 0;
    ops->argv = NULL ;
    ops->env = NULL ;
    strcpy(ops->endpt.name, "") ;
}

/* Join a group.  On success, returns group context in *gctxp.
 */ 
hot_err_t
hot_ens_Join(hot_ens_JoinOps_t *ops, hot_gctx_t *gctxp /*OUT*/)
{
    ce_jops_t *ce_ops;
    hot_gctx_t gctx;

    if (!initialized)
	hot_ens_Start(ops->argv);
    gctx = create_intf(ops->env, &ops->conf);
    ce_ops = ce_of_hot_ops(ops);
    ce_Join(ce_ops, gctx->intf);
    *gctxp = gctx;
    return HOT_OK;
}

hot_err_t
hot_ens_Leave(hot_gctx_t gctx)
{
    ce_Leave(gctx->intf);
    return HOT_OK;
}

hot_err_t
hot_ens_Cast(hot_gctx_t g, hot_msg_t msg,  hot_ens_MsgSendView *dummy)
{
    char *data = NULL;
    int len;
    /*
    msg_of_hot_msg(msg, &len, &data);
    assert(data != NULL);
    ce_flat_Cast(g->intf, len, data);
    */
    return HOT_OK;
}

hot_err_t
hot_ens_Send(hot_gctx_t g, hot_endpt_t *dest, hot_msg_t msg,
	     hot_ens_MsgSendView *dummy)
{
    char *data = NULL;
    int len;
    ce_rank_t rank;

    rank = hot_endpt_tbl_lookup(g->tbl, dest);
    if (rank == -1)
	return hot_err_Create(0, "hot_ens_Send: lookup failed, not such endpoint");
    /*
    msg_of_hot_msg(msg, &len, &data);
    assert(data != NULL);
    ce_flat_Send1(g->intf, rank, len, data);
    */
    return HOT_OK;
}

hot_err_t
hot_ens_Suspect(hot_gctx_t g, hot_endpt_t *suspects, int nsuspects)
{
    int *arr, i;

    arr = (int*)hot_malloc (sizeof(int) * nsuspects);
    for(i=0; i<nsuspects; i++) {
	arr[i] = hot_endpt_tbl_lookup(g->tbl, &suspects[i]);
	if (arr[i] == -1) {
	    free(arr);
	    return hot_err_Create(0, "hot_ens_Suspect: lookup failed, not such endpoint");
	}
    }
    ce_Suspect(g->intf, nsuspects, arr);
    return HOT_OK;
}


hot_err_t
hot_ens_XferDone(hot_gctx_t g)
{
    ce_XferDone(g->intf);
    return HOT_OK;
}


hot_err_t
hot_ens_ChangeProtocol(hot_gctx_t g, char *protocol_name)
{
    ce_ChangeProtocol(g->intf, protocol_name);
    return HOT_OK;
}

hot_err_t
hot_ens_ChangeProperties(hot_gctx_t g, char *properties)
{
    ce_ChangeProperties(g->intf, properties);
    return HOT_OK;
}

hot_err_t
hot_ens_RequestNewView(hot_gctx_t g)
{
    ce_Prompt(g->intf);
    return HOT_OK;
}

hot_err_t
hot_ens_Rekey(hot_gctx_t g)
{
    ce_Rekey(g->intf);
    return HOT_OK;
}

hot_err_t
hot_ens_MLPrintOverride(void (*handler)(char *msg))
{
    ce_MLPrintOverride(handler);
    return HOT_OK;
}
    
hot_err_t
hot_ens_MLUncaughtException(void (*handler)(char *info))
{
    ce_MLUncaughtException(handler);
    return HOT_OK;
}
