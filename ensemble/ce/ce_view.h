/**************************************************************/
/* CE_VIEW.H */
/* Author: Ohad Rodeh  8/2001 */
/* Based on code by Mark Hayden in the CEnsemble system */
/**************************************************************/

#ifndef __CE_VIEW_H__
#define __CE_VIEW_H__

#include "caml/mlvalues.h"
#include "caml/memory.h"
#include "caml/callback.h"
#include "caml/alloc.h"
#include "caml/config.h"
#include <string.h>  // UNIX

#define record_create(type, var) ((type)malloc(sizeof(*var)))
#define record_free(rec) free(rec)
#define record_clear(rec) memset(rec, 0, sizeof(*rec))

typedef struct ce_iovec_t {
  int len ;
  char *data;
} ce_iovec_t;

typedef double      ce_float_t ;
typedef int         ce_bool_t ;
typedef int         ce_rank_t ;
typedef int         ce_nmembers_t ;
typedef int         ce_ltime_t ;
typedef char*       ce_name_t ;
typedef ce_rank_t   ce_origin_t ;
typedef int         ce_ofs_t ;
typedef int         ce_len_t ;
typedef void       *ce_env_t ;
typedef double      ce_time_t ;
typedef char*       ce_endpt_t;
typedef char*       ce_addr_t;

typedef ce_endpt_t *ce_endpt_array_t ;
typedef ce_rank_t  *ce_rank_array_t ;
typedef ce_bool_t  *ce_bool_array_t ;
typedef ce_addr_t  *ce_addr_array_t ;

typedef struct ce_view_id_t {
    ce_ltime_t ltime ;
    ce_endpt_t endpt ;
} ce_view_id_t ;

typedef ce_view_id_t **ce_view_id_array_t;

typedef struct ce_view_state_t {
  char* version ;
  char* group ;
  ce_rank_t coord ;
  int ltime ;
  ce_bool_t primary ;
  char* proto ;
  ce_bool_t groupd ;
  ce_bool_t xfer_view ;
  char* key ;
  int num_ids ;
  ce_view_id_array_t prev_ids ;
  char *params;
  ce_time_t uptime ;
  ce_endpt_array_t view ;
  ce_addr_array_t address ;
} ce_view_state_t ;


typedef struct ce_local_state_t {
  ce_endpt_t endpt ;
  ce_addr_t addr ;
  ce_rank_t rank ;
  char* name ;
  int nmembers ;
  ce_view_id_t *view_id ;
  ce_bool_t am_coord ;
} ce_local_state_t ;

typedef struct ce_jops_t {
  ce_time_t hrtbt_rate ;
  char *transports ;
  char *protocol ;
  char *group_name ;
  char *properties ;
  ce_bool_t use_properties ;
  ce_bool_t groupd ;
  char *params ;
  ce_bool_t debug ;
  ce_bool_t client;
  char *endpt ;
  char *princ ;
  char *key ;
  ce_bool_t secure ;
} ce_jops_t;

#define CE_DEFAULT_TRANSPORT "DEERING"
#define CE_DEFAULT_PROTOCOL \
    "Top:Heal:Switch:Leave:" \
    "Inter:Intra:Elect:Merge:Sync:Suspect:" \
    "Stable:Vsync:Frag_Abv:Top_appl:" \
    "Frag:Pt2ptw:Mflow:Pt2pt:Mnak:Bottom"
#define CE_DEFAULT_PROPERTIES "Gmp:Sync:Heal:Switch:Frag:Suspect:Flow"

/**************************************************************/
/* Utilities
 */

void ce_view_full_free(ce_local_state_t *ls, ce_view_state_t* vs);
void ce_jops_free(ce_jops_t*) ;
void ce_iovec_free(ce_iovec_t*) ;

/**************************************************************/
#endif /* __CE_VIEW_H__ */
