/**************************************************************/
/* CE_CONTEXT_TABLE.C */
/* Author: Ohad Rodeh 3/2002 */
/**************************************************************/
/* Contains the internal data-structures used by the outboard
 * mode.
 *
 * This includes a mapping between contexts and context ids (integers).
 */
/**************************************************************/

#include "ce_context_table.h"
#include "ce_internal.h"
#include <stdio.h>
#include <memory.h>
#include <malloc.h>

static int
hash_comp(ce_ctx_id_t id, int num_buckets)
{
    return id % num_buckets;
}

/*
 *  Hash table item structure
 */
typedef struct item_t {
    ce_ctx_id_t id;         /* This is the record key */
    ce_ctx_t   *ctx;        /* The context */
    struct item_t *next;
} item_t;

/* We do not free the application interface. 
 */
static void
free_item(item_t *item)
{
    if (item==NULL) return;
    ce_intf_free(NULL, item->ctx->intf);
    free(item->ctx);
    free(item);
}

static item_t*
create_item(ce_ctx_id_t id, ce_ctx_t *ctx)
{
    item_t *tmp;
    
    tmp = (item_t*) ce_malloc(sizeof(item_t));
    tmp->id = id;
    tmp->ctx = ctx;
    tmp->next = NULL;
    return tmp;
}


#define INIT_SIZE 1

/*
 *  The hash table itself
 */
struct ce_ctx_tbl_inner_t {
    item_t **htbl;    /* A variable size array containing lists of items */
    int len ;           /* The length of the array */
    int num ;           /* The number of elements in the hashtable. Used
			   for resizeing decisions */
};

/* Resize a hashtable.
 * @new_len - is the new size. 
 */
static void
resize(ce_ctx_tbl_t *h, int new_len)
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
	    ce_ctx_tbl_insert(h, tmp->id, tmp->ctx);
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
enlarge(ce_ctx_tbl_t *h)
{
    resize(h, 1 + 2*h->len);
}

/* Shrink the hash table by a factor of two. 
 */
static void
shrink(ce_ctx_tbl_t *h)
{
    resize(h, h->len / 2);
}


/* Constructor.
 */
ce_ctx_tbl_t*
ce_ctx_tbl_t_create(void)
{
    ce_ctx_tbl_t *h;
    
    h = (ce_ctx_tbl_t*) ce_malloc(sizeof(ce_ctx_tbl_t));
    memset(h, 0, sizeof(ce_ctx_tbl_t));
    h->htbl = (item_t**)ce_malloc(INIT_SIZE * sizeof(int));
    memset(h->htbl, 0, INIT_SIZE * sizeof(int));
    h->len = INIT_SIZE;
    
    return h;
}

/*
 */
void
ce_ctx_tbl_t_free(ce_ctx_tbl_t *h)
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

/** Check existence in the table. Return 1 if true, 0 if false.
 * @h - hash table
 * @o - object name to look for
 */
static int
tbl_exists(ce_ctx_tbl_t *h, ce_ctx_id_t id)
{
    int slot;
    item_t *tmp;
    
    slot = hash_comp(id,h->len);
    tmp = h->htbl[slot];
    
    while (tmp) {
	if (tmp->id == id)
	    return 1;
	tmp = tmp->next;
    }
    return 0;
}

/** lookup in the table. Return pointers to a context with the
 * requested id.
 */
ce_ctx_t *
ce_ctx_tbl_lookup(ce_ctx_tbl_t *h, ce_ctx_id_t id)
{
    int slot;
    item_t *tmp;
    
    slot = hash_comp(id,h->len);
    tmp = h->htbl[slot];
    
    while (tmp) {
	if (tmp->id == id)
	    return tmp->ctx;
	tmp = tmp->next;
    }
    return NULL;
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
void
ce_ctx_tbl_insert(ce_ctx_tbl_t *h, ce_ctx_id_t id, ce_ctx_t *ctx)
{
    int slot;
    item_t *tmp, *new_item;
    
    if (tbl_exists(h,id) == 1){
	printf("CE_CONTEXT_TABLE: Internal error, trying to add an already existing entry\n");
	exit(1);
    }
    
    slot = hash_comp(id,h->len);
    tmp = h->htbl[slot];
    
    new_item = create_item(id,ctx);
    new_item -> next = tmp;
    h->htbl[slot] = new_item;
    h->num++;
    
    if (h->num >= h->len)
	enlarge(h);
    
}

/*
 *  Remove: Remove an item from the hash table
 * if the table becomes too small then shrink it.
 * Too small currently is less than a quarter full.
 *
 * does not consume its argument.
 */
void
ce_ctx_tbl_remove(ce_ctx_tbl_t *h, ce_ctx_id_t id)
{
    int slot;
    item_t *tmp, *prev;
    
    slot = hash_comp(id,h->len);
    tmp = h->htbl[slot];
    
    if (tmp==NULL) return;
    
    if (tmp->id == id) {
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
	if (tmp->id == id) {
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
ce_ctx_tbl_size(ce_ctx_tbl_t *h)
{
    return h->num;
}

/**************************************************************/

