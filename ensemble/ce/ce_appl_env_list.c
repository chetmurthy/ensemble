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
/* CE_APPL_LIST.H: Handle a (presumebly short) list of application interfaces. */
/* Author: Ohad Rodeh 12/2002 */
/**************************************************************/
#include "ce_appl_env_list.h"
#include "ce_trace.h"
/**************************************************************/
#define NAME "CE_APPL_ENV_LIST"
/**************************************************************/

#define SIZE sizeof(void*)

ce_appl_env_list_t* ce_appl_env_list_create(void)
{
    ce_appl_env_list_t *apl ;
    
    apl = (ce_appl_env_list_t*) ce_malloc(sizeof(ce_appl_env_list_t));
    apl->alen = 4  ;		/* must be a power of 2 */
    apl->len = 0 ;
    apl->arr = ce_malloc(SIZE * apl->alen) ;
    memset(apl->arr, 0, SIZE * apl->alen) ;
    return apl ; 
}


static void grow(ce_appl_env_list_t *apl)
{
    void **oarr = apl->arr ;
    
    apl->alen = 2 * apl->alen ;
    apl->arr = ce_malloc(SIZE * apl->alen) ;
    
    //   if (q->alen * q->size > 1<<12) {
    //	eprintf("QUEUE:expand:getting large:len=%d:%s\n", q->alen * q->size, q->debug) ;
    //    }
    
    memset(apl->arr, 0, SIZE * apl->alen) ;
    memcpy(apl->arr, oarr, SIZE * apl->len); 
    free(oarr) ;
}

void ce_appl_env_list_add(ce_appl_env_list_t *apl, void *env)
{
    int i;

    /* If there is an empty list, use it
     */
    for (i=0; i<apl->len; i++) {
	if (apl->arr[i] == 0) {
	    apl->arr[i] = env;
	    return;
	}
    }
    
    if (apl->len >= apl->alen) {
	TRACE("grow");
	grow(apl) ;
    }
    apl->arr[apl->len] = env;
    apl->len++;
}

void ce_appl_env_list_remove(ce_appl_env_list_t *apl, void *env)
{
    int i;
    
    for (i=0; i<apl->len; i++) {
	if (apl->arr[i] == env) {
	    apl->arr[i] = 0;
	    return;
	}
    }
    CE_ERROR(("could not find the c_appl to remove"));
}
