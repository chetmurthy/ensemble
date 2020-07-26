/**************************************************************/
/* ENS_HASHTBL.C */
/* Author: Ohad Rodeh 10/2003 */
/**************************************************************/
#include "ens_hashtbl.h"
#include "ens_utils.h"
#include <stdio.h>
/**************************************************************/
#define NAME "HASHTBL"
/**************************************************************/
#include <memory.h>
/**************************************************************/

void EnsHashtblInit(ens_hashtbl_t *h)
{
    memset(h, 0, sizeof(ens_hashtbl_t));
}

static int HashComp(int id, int num_buckets)
{
    return id % num_buckets;
}

ens_hitem_t *EnsHashtblLookup(ens_hashtbl_t *h, int id)
{
    int slot;
    ens_hitem_t *tmp;

    EnsTrace(NAME, "EnsHashtblLookup");
    slot = HashComp(id, ENS_HASHTBL_SIZE);
    tmp = h->arr[slot];
    
    while (tmp) {
	if (tmp->id == id)
	    return tmp;
	tmp = tmp->next;
    }
    return NULL;
}

/*
 *  insert: Insert an item into the hash table.
 */
void EnsHashtblInsert(ens_hashtbl_t *h, ens_hitem_t *item)
{
    int slot;
    ens_hitem_t *tmp;
    
    EnsTrace(NAME, "EnsHashtblInsert");
    if (EnsHashtblLookup(h,item->id))
	EnsPanic("ENS_HASHTBL: Internal error, trying to add an already existing entry\n");
    
    slot = HashComp(item->id, ENS_HASHTBL_SIZE);
    tmp = h->arr[slot];
    
    item -> next = tmp;
    h->arr[slot] = item;
    h->num++;
}

/*
 *  remove: Remove an item from the hash table
 * Does not consume its argument.
 */
void EnsHashtblRemove(ens_hashtbl_t *h, int id)
{
    int slot;
    ens_hitem_t *tmp, *prev;
    
    slot = HashComp(id, ENS_HASHTBL_SIZE);
    tmp = h->arr[slot];
    
    if (NULL == tmp) return;
    
    if (tmp->id == id) {
	h->arr[slot] = tmp->next;
	h->num--;
	return ;
    }
    
    prev = h->arr[slot]; 
    tmp = prev->next;
    
    while (tmp) {
	if (tmp->id == id) {
	    prev->next = tmp->next;
	    h->num--;
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
int EnsHashtblSize(ens_hashtbl_t *h)
{
    return h->num;
}


