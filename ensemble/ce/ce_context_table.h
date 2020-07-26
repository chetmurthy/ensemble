/**************************************************************/
/*
 *  Ensemble, 1_42
 *  Copyright 2003 Cornell University, Hebrew University
 *           IBM Israel Science and Technology
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 */
/**************************************************************/
/**************************************************************/
/* CE_CONTEXT_TABLE.H */
/* Author: Ohad Rodeh 3/2002 */
/**************************************************************/
/* Contains the internal data-structures used by the outboard
 * mode.
 *
 * This includes a mapping between contexts and context ids (integers).
 */
/**************************************************************/

#ifndef __CE_CONTEXT_TABLE_H__
#define __CE_CONTEXT_TABLE_H__

#include "ce_internal.h"

/*
 *  The hash table itself
 */
typedef struct ce_ctx_tbl_inner_t ce_ctx_tbl_t;

/* This describes an endpoint context.
 */
typedef struct {
    ce_appl_intf_t *intf;	        /* application callbacks */
    int nmembers ;		        /* #members */
    int blocked;			/* is group blocked? */
    int joining ;			/* are we joining? */
    int leaving ;			/* are we leaving? */
} ce_ctx_t;

/* Constructor/Destructor
 */
ce_ctx_tbl_t *ce_ctx_tbl_t_create(void);
void ce_ctx_tbl_t_free(ce_ctx_tbl_t*);

/** lookup in the table. Return the context matching the id.
 * Return NULL if no such context exists.
 *
 * @h - hash table
 * @id - the context id we are looking for.
 */
ce_ctx_t *ce_ctx_tbl_lookup(ce_ctx_tbl_t *h, ce_ctx_id_t id);

/*
 *  insert: Insert an item into the hash table.
 *
 * Consumes its arguments.
 * 
 * @h - hash table
 * @id - the context id 
 * @c - the context to insert
 */
void
ce_ctx_tbl_insert(ce_ctx_tbl_t *h, ce_ctx_id_t id, ce_ctx_t *c);

/*
 *  remove: Remove an item from the hash table
 * Does not consume its argument.
 */
void
ce_ctx_tbl_remove(ce_ctx_tbl_t *h, ce_ctx_id_t id);

/*
 *  size: return the number of items in the hash-table. 
 */
int ce_ctx_tbl_size(ce_ctx_tbl_t *h);

#endif /* __CE_CONTEXT_TABLE_H__ */
