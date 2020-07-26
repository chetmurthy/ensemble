/**************************************************************/
/* HOT_ENDPT_TABLE.C */
/* Author: Ohad Rodeh 4/2002 */
/**************************************************************/
/* Implements a hash table mapping between endpoints and ranks.
 */
/**************************************************************/
#include "hot_endpt_tbl.h"
#include <stdio.h>
#include <memory.h>
#include <malloc.h>
#include <stdlib.h>

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

/****************************************************************************/

static int
hash_comp(hot_endpt_t *e, int num_buckets)
{
    int result = 0;
    int i;
    
    for(i=0; i< HOT_ENDP_MAX_NAME_SIZE; i++)
	result = (result * 33 + 5 + e->name[i]) % num_buckets;
    
    return result ;
}

/*
 *  Hash table item structure
 */
typedef struct item_t {
    hot_endpt_t endpt;         /* This is the record key */
    int         rank;
    struct item_t *next;
} item_t;

/* We do not free the application interface. 
 */
static void
free_item(item_t *item)
{
    free(item);
}

static item_t*
create_item(hot_endpt_t *endpt, int rank)
{
    item_t *tmp;
    
    tmp = (item_t*) hot_malloc(sizeof(item_t));
    memcpy(tmp->endpt.name, endpt->name, HOT_ENDP_MAX_NAME_SIZE);
    tmp->rank = rank;
    tmp->next = NULL;
    return tmp;
}


/*
 *  The hash table itself
 */
struct hot_endpt_tbl_inner_t {
    item_t **htbl;    /* A variable size array containing lists of items */
    int len ;           /* The length of the array */
};

/* Constructor.
 */
hot_endpt_tbl_t*
hot_endpt_tbl_t_create(int size)
{
    hot_endpt_tbl_t *h;
    
    h = (hot_endpt_tbl_t*) hot_malloc(sizeof(hot_endpt_tbl_t));
    memset(h, 0, sizeof(hot_endpt_tbl_t));
    h->htbl = (item_t**)hot_malloc(size * sizeof(int));
    memset(h->htbl, 0, size * sizeof(int));
    h->len = size;
    
    return h;
}

/*
 */
void
hot_endpt_tbl_t_free(hot_endpt_tbl_t *h)
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
tbl_exists(hot_endpt_tbl_t *h, hot_endpt_t *endpt)
{
    int slot;
    item_t *tmp;
    
    slot = hash_comp(endpt,h->len);
    tmp = h->htbl[slot];
    
    while (tmp) {
	if (memcmp(tmp->endpt.name, endpt->name, HOT_ENDP_MAX_NAME_SIZE) == 0)
	    return 1;
	tmp = tmp->next;
    }
    return 0;
}

/** lookup in the table. Return pointers to a context with the
 * requested id.
 */
ce_rank_t
hot_endpt_tbl_lookup(hot_endpt_tbl_t *h, hot_endpt_t *endpt)
{
    int slot;
    item_t *tmp;
    
    slot = hash_comp(endpt,h->len);
    tmp = h->htbl[slot];
    
    while (tmp) {
	if (memcmp(&tmp->endpt, endpt, HOT_ENDP_MAX_NAME_SIZE) == 0)
	    return tmp->rank;
	tmp = tmp->next;
    }
    return -1;
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
hot_endpt_tbl_insert(hot_endpt_tbl_t *h, hot_endpt_t *endpt, ce_rank_t rank)
{
    int slot;
    item_t *tmp, *new_item;
    
    if (tbl_exists(h,endpt) == 1){
	printf("CE_CONTEXT_TABLE: Internal error, trying to add an already existing entry\n");
	exit(1);
    }
    
    slot = hash_comp(endpt,h->len);
    tmp = h->htbl[slot];

    new_item = create_item(endpt,rank);
    new_item -> next = tmp;
    h->htbl[slot] = new_item;
}

/**************************************************************/

