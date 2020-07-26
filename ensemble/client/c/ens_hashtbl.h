/**************************************************************/
/*
 *  Ensemble, 2_00
 *  Copyright 2004 Cornell University, Hebrew University
 *           IBM Israel Science and Technology
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
/**************************************************************/
/* ENS_HASHTBL.H */
/* Author: Ohad Rodeh 10/2003 */
/**************************************************************/
/* Contains a hash table used to keep track of live members per
 * connection. The key to the hash-table is member id. 
 * 
 * The implementation uses an array of pointers to linked lists
 * of items. 
 */
/**************************************************************/

#ifndef __ENS_HASHTBL_H__
#define __ENS_HASHTBL_H__

/* Items in the hashtable. An item has to have, as its first field, a pointer to the
 * next item. This scheme is used to 
 */
typedef struct ens_hitem_t {
    struct ens_hitem_t *next;
    int id;
} ens_hitem_t;

/* We think there wouldn't be too many members, not more than
 * 100. Therefore, a prime close to 100 is used.
 */
#define ENS_HASHTBL_SIZE (101)

/*
 *  The hash table itself
 */
typedef struct ens_hashtbl_t {
    ens_hitem_t* arr[ENS_HASHTBL_SIZE];  /* An array pointing to item lists */
    int num ;                   /* The number of elements currently in the hashtable. */
} ens_hashtbl_t;

/* Constructor/Destructor
 */
void EnsHashtblInit(ens_hashtbl_t *h);

/** lookup in the table. Return the context matching the id.
 * Return NULL if no such context exists.
 *
 * @h - hash table
 * @id - the context id we are looking for.
 */
ens_hitem_t *EnsHashtblLookup(ens_hashtbl_t *h, int id);

/*
 *  insert: Insert an item into the hash table.
 *
 * Consumes its arguments.
 * 
 * @h - hash table
 * @id - the context id 
 * @c - the context to insert
 */
void EnsHashtblInsert(ens_hashtbl_t *h, ens_hitem_t *item);

/*
 *  remove: Remove an item from the hash table
 * Does not consume its argument.
 */
void EnsHashtblRemove(ens_hashtbl_t *h, int id);

/*
 *  size: return the number of items in the hash-table. 
 */
int EnsHashtblSize(ens_hashtbl_t *h); 

#endif /* __CE_CONTEXT_TABLE_H__ */
