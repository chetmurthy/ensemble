/**************************************************************/
/* SOCK_LIST.H */
/* Author: Ohad Rodeh 3/2002 */
/**************************************************************/
/* Implements a list of sockets.
 */
/**************************************************************/

#include "ce_sock_table.h"
#include <malloc.h>
#include <memory.h>
#include <assert.h>


static int
hash_comp(CE_SOCKET sock, int num_buckets)
{
    return sock % num_buckets;
}

/*
 *  Hash table item structure
 */
typedef struct item_t {
    CE_SOCKET sock;         /* This is the record key */
    ce_handler_t handler;    
    ce_env_t env;
    struct item_t *next;
} item_t;

static void
free_item(item_t *item)
{
    if (item==NULL) return;
    free(item);
}

static item_t*
create_item(CE_SOCKET sock, ce_handler_t handler, ce_env_t env)
{
    item_t *tmp;
    
    tmp = (item_t*) ce_malloc(sizeof(item_t));
    tmp->sock = sock;
    tmp->handler = handler;
    tmp->env = env;
    return tmp;
}


#define INIT_SIZE 1

/*
 *  The hash table itself
 */
struct ce_sock_tbl_inner_t {
    item_t **htbl;    /* A variable size array containing lists of items */
    int len ;           /* The length of the array */
    int num ;           /* The number of elements in the hashtable. Used
			   for resizeing decisions */
};

/* Resize a hashtable.
 * @new_len - is the new size. 
 */
static void
resize(ce_sock_tbl_t *h, int new_len)
{
    item_t **old_htbl, *tmp, *prev;
    int old_len, i;
    
//    zfs_trace("resize: %d->%d\n", h->len, new_len);
    old_len = h->len;
    old_htbl = h->htbl;
    h->len = new_len;
    h->num=0;
    h->htbl = (item_t**)ce_malloc(sizeof(int) * h->len);
    memset(h->htbl, 0, sizeof(int) * h->len);
    
    for(i=0; i<old_len; i++){
	tmp = old_htbl[i];
	while (tmp != NULL){
	    ce_sock_tbl_insert(h, tmp->sock, tmp->handler, tmp->env);
	    prev= tmp;
	    tmp = tmp->next;
	    free(prev);
	}
    }
    
    free(old_htbl);
}

/* Enlarge the hash table by a factor of two. 
 */
static void
enlarge(ce_sock_tbl_t *h)
{
    resize(h, 1 + 2*h->len);
}

/* Shrink the hash table by a factor of two. 
 */
static void
shrink(ce_sock_tbl_t *h)
{
    resize(h, h->len / 2);
}


/* Constructor.
 */
ce_sock_tbl_t*
ce_sock_tbl_t_create(void)
{
    ce_sock_tbl_t *h;
    
    h = (ce_sock_tbl_t*) ce_malloc(sizeof(ce_sock_tbl_t));
    memset(h, 0, sizeof(ce_sock_tbl_t));
    h->htbl = (item_t**)ce_malloc(INIT_SIZE * sizeof(int));
    memset(h->htbl, 0, INIT_SIZE * sizeof(int));
    h->len = INIT_SIZE;
    
    return h;
}

/*
 */
void
ce_sock_tbl_t_free(ce_sock_tbl_t *h)
{
    item_t *tmp,*prev;
    int i;
    
    if (h==NULL) return;
    
    for(i=0; i<h->len; i++){
	tmp = h->htbl[i];
	while (tmp != NULL){
	    prev= tmp;
	    tmp = tmp->next;
	    free_item(prev);
	}
    }
    
    free(h->htbl);
    free(h);
}

/** Check existence in the table.
 * @h - hash table
 * @o - object name to look for
 */
static ce_reply_t
tbl_exists(ce_sock_tbl_t *h, CE_SOCKET sock)
{
    int slot;
    item_t *tmp;
    
    slot = hash_comp(sock,h->len);
    tmp = h->htbl[slot];
    
    while (tmp) {
	if (tmp->sock == sock)
	    return CE_YES;
	tmp = tmp->next;
    }
    return CE_NO;
}

/** lookup in the table. Return pointers to a context with the
 * requested id.
 */
ce_reply_t
ce_sock_tbl_lookup(ce_sock_tbl_t *h, CE_SOCKET sock,
		   /* OUT */ ce_handler_t *handler, ce_env_t *env)
{
    int slot;
    item_t *tmp;
    
    slot = hash_comp(sock,h->len);
    tmp = h->htbl[slot];
    
    while (tmp) {
	if (tmp->sock == sock){
	    *handler = tmp->handler;
	    *env = tmp->env;
	    return CE_YES;
	}
	tmp = tmp->next;
    }
    
    *handler = NULL;
    *env = NULL;
    return CE_NO;
}


/*
 *  insert: Insert an item into the hash table
 * first check if the item already exists. In this case, return NO.
 * Otherwise, insert the item at the start of the list, and return
 * YES.
 *
 * The function consumes its arguments. 
 *
 * If the table gets too full, then enlarge it.
 * Too full currently means an item per slot. 
 */
ce_reply_t
ce_sock_tbl_insert(ce_sock_tbl_t *h, CE_SOCKET sock,
		   ce_handler_t handler, ce_env_t env)
{
    int slot;
    item_t *tmp, *new_item;
    
    if (tbl_exists(h,sock) == CE_YES)
	return CE_NO;
    
    slot = hash_comp(sock,h->len);
    tmp = h->htbl[slot];
    
    new_item = create_item(sock,handler,env);
    new_item -> next = tmp;
    h->htbl[slot] = new_item;
    h->num++;
    
    if (h->num >= h->len)
	enlarge(h);

    return CE_YES;
}

/*
 *  Remove: Remove an item from the hash table
 * if the table becomes too small then shrink it.
 * Too small currently is less than a quarter full.
 *
 * does not consume its argument.
 */
void
ce_sock_tbl_remove(ce_sock_tbl_t *h, CE_SOCKET sock)
{
    int slot;
    item_t *tmp, *prev;
    
    slot = hash_comp(sock,h->len);
    tmp = h->htbl[slot];
    
    if (tmp==NULL) return;
    
    if (tmp->sock == sock) {
	h->htbl[slot] = tmp->next;
	free_item(tmp);
	h->num--;
	if (h->num < 0.25 * h->len)
	    shrink(h);
	return ;
    }
    
    prev = h->htbl[slot]; 
    tmp = prev->next;
    
    while (tmp) {
	if (tmp->sock == sock) {
	    prev->next = tmp->next;
	    free_item(tmp);
	    h->num--;
	    if (h->num < 0.25 * h->len)
		shrink(h);
	    return ;
	}
	prev = tmp;
	tmp = tmp->next;
    }
    return ;
}

/*
 *  size: return the number of items in the hash-table. 
 */
int
ce_sock_tbl_size(ce_sock_tbl_t *h)
{
    return h->num;
}

/**************************************************************/

void
ce_sock_tbl_fdset(ce_sock_tbl_t *h, fd_set *fds)
{
    item_t *tmp,*prev;
    int i;

    if (h==NULL) return;

    for(i=0; i<h->len; i++){
	tmp = h->htbl[i];
	while (tmp != NULL){
	    FD_SET(tmp->sock, fds);
	    prev= tmp;
	    tmp = tmp->next;
	}
    }
}

void
ce_sock_tbl_invoke(ce_sock_tbl_t *h, fd_set *fds)
{
    item_t *tmp,*prev;
    int i;

    if (h==NULL) return;

    for(i=0; i<h->len; i++){
	tmp = h->htbl[i];
	while (tmp != NULL){
	    if (FD_ISSET(tmp->sock, fds))
		tmp->handler(tmp->env);
	    prev= tmp;
	    tmp = tmp->next;
	}
    }
}

/**************************************************************/

