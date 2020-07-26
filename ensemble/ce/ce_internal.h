/**************************************************************/
/* CE_VIEW.H */
/* Author: Ohad Rodeh  8/2001 */
/* Internal definitions and include files. */
/**************************************************************/

#ifndef __CE_INTERNAL_H__
#define __CE_INTERNAL_H__


#include "caml/mlvalues.h"
#include "caml/memory.h"
#include "caml/callback.h"
#include "caml/alloc.h"
#include "caml/config.h"
#include <string.h>  // UNIX

#include <assert.h>

#include "ce.h"
#include "mm.h"
#include "sockfd.h"
#include "ce_actions.h"
#include "ce_convert.h"

/* The representation of the application interface. This should
 * hidden from
 * the user, which has only a constructor in ce.h. The destructor is
 * not needed, because the interface is freed automatically when the
 * ce_app_exit_t function is called. 
 */
struct ce_appl_intf_t {
  ce_env_t env;
  ce_queue_t *aq; /*  Contains the current set of queued actions */
  ce_bool_t req_heartbeat;   /*  For internal use */

  /*  After this is called, the interface (ce_appl_intf_f*) is freed.
   */
  ce_appl_exit_t exit ;
  
  /*  Note that the view state and local state records passed up are
   * "owned" by the application.
   * These records are pointed to by the 'vs', and 'ls' variables. 
   */
  ce_appl_install_t install ;
  
  /* These use the state returned by install.
   */
  ce_appl_flow_block_t flow_block ;
  ce_appl_block_t block ;
  
  /* The data passed up with the receive call is not
   * owned by the application. It is freed after the callback
   * by Ensemble. 
   */
  ce_appl_receive_cast_t receive_cast ;
  ce_appl_receive_send_t receive_send ;
  
  ce_appl_heartbeat_t heartbeat ;
} ;

/* We provide our own allocation function that exits
 * the program if no space is left. 
 */
void* ce_malloc(int);

/* The user should not free application interfaces.
 * This is performed by the system upon the exit callback. 
 */
void ce_intf_free(ce_appl_intf_t*);

char **
ce_process_args(int argc, char **argv); 


/* For debugging
 */
//#define free(x)  printf("%s:freeing(", NAME); fflush(stdout); free(x); printf(")\n"); fflush(stdout);

#endif /*__CE_INTERNAL_H__*/
