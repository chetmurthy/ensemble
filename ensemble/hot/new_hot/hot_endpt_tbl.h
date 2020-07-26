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

#ifndef __HOT_ENDPT_TBL_H__
#define __HOT_ENDPT_TBL_H__

#include "ce.h"

#include "hot_sys.h"
#include "hot_error.h"
#include "hot_thread.h"
#include "hot_msg.h"
#include "hot_mem.h"
#include "hot_ens.h"

/*
 *  The hash table itself
 */
typedef struct hot_endpt_tbl_inner_t hot_endpt_tbl_t;

hot_endpt_tbl_t *hot_endpt_tbl_t_create(int size);
void hot_endpt_tbl_t_free(hot_endpt_tbl_t*);

/** lookup in the table. Return the rank matching the endpt.
 * Return -1 if not found.
 *
 * @h - hash table
 * @endpt - the endpt we are matching against.
 */
ce_rank_t hot_endpt_tbl_lookup(hot_endpt_tbl_t *h, hot_endpt_t *endpt);

/*
 *  insert: Insert an item into the hash table.
 *
 * Does not consume its arguments.
 * 
 * @h - hash table
 * @endpt - the end-point
 * @rank - matching rank
 */
void
hot_endpt_tbl_insert(hot_endpt_tbl_t *h, hot_endpt_t *endpt, ce_rank_t rank);

#endif /* __HOT_ENDPT_TBL_H__ */
