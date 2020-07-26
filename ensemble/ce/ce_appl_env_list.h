/**************************************************************/
/* CE_APPL_ENV_LIST.H: Handle a (presumebly short) list of application environments. */
/* Author: Ohad Rodeh 12/2002 */
/**************************************************************/
#ifndef __CE_APPL_ENV_LIST_H__
#define __CE_APPL_ENV_LIST_H__

#include "ce_internal.h"

typedef struct ce_appl_env_list_t {
    int alen;
    int len ;
    void **arr;
} ce_appl_env_list_t;


ce_appl_env_list_t *ce_appl_env_list_create(void);
void ce_appl_env_list_add(ce_appl_env_list_t *apl, void *env);
void ce_appl_env_list_remove(ce_appl_env_list_t *apl, void *env);

#endif
