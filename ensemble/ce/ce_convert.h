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
/* CE_CONVERT.H */
/* Author: Ohad Rodeh  8/2001 */
/* Conversion of ML <-> C data-structures */
/**************************************************************/

#ifndef __CE_CONVERT_H__
#define __CE_CONVERT_H__

#include "ce_internal.h"

//value Val_string_opt(char*);

/* Conversions between ML<->C iovec representations.
 */
value Val_iovl(int, ce_iovec_array_t);

/* The returned array is STATICALLY allocated.
 * Whenever this function is called, the previous result
 * is invalidated.
 */
ce_iovec_array_t Iovl_val(value);

//ce_view_id_t*
//View_id_of_val(value view_id_v);

/* Create a copy of an ML string on the C side. 
 */
//char *String_copy_val(value);
		
//ce_view_id_t*
//View_id_val(value view_id_v);

//ce_endpt_array_t Endpt_array_val(value, int n);


/* Convert a view state into a C version.
 * The ls and vs variables should be preallocated. 
 */
void ViewFull_val(value ls_v, value vs_v,
		  ce_local_state_t *ls, ce_view_state_t *vs);

value Val_jops (ce_jops_t*);

value Val_c_appl(ce_appl_intf_t*);
ce_appl_intf_t *C_appl_val(value);

value Val_env(ce_env_t);
ce_env_t Env_val(value);

value Val_handler(ce_handler_t);
ce_handler_t Handler_val(value);

ce_appl_intf_t *C_appl_val(value);

//value Val_action (ce_action_t*);

/* Convert a queue of actions into an ML value
 */
value Val_queue(struct ce_queue_t *q);

#endif /*__CE_CONVERT_H__*/
/**************************************************************/
