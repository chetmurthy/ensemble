/**************************************************************/
/* CE_OUTBOARD_C.H */
/* Author: Ohad Rodeh 3/2002 */
/* Based on code by Mark Hayden and Alexey Vaysbrud. */
/**************************************************************/
/* These functions allow customizing the locking functions used
 * by the single-threaded outboard mode.
 *
 * This is used by the multi-threaded mode in the block function.
 */
#ifndef __CE_OUTBOARD_H__
#define __CE_OUTBOARD_H__
typedef void (*routine_t)(void);

void ce_st_set_lock_fun(routine_t f);
void ce_st_set_unlock_fun(routine_t f);

#endif
