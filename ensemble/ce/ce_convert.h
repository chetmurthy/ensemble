/**************************************************************/
/* CE_CONVERT.H */
/* Author: Ohad Rodeh  8/2001 */
/* Conversion of ML <-> C data-structures */
/**************************************************************/
#include "ce.h"
#include "ce_actions.h"

#ifdef _WIN32
#include <windows.h>

/* From unixsupport.h
 */ 
extern value win_alloc_handle(HANDLE);

/* Get the file descriptor inside the wrapper.  We define Socket_val
 * in terms of Handle_val() to make it clear what is going on here.
 */
#define Handle_val(v) (*((HANDLE *)(v))) /* from unixsupport.h */

#define Val_socket(sock) (win_alloc_handle((HANDLE)sock))
#define Socket_val(sock_v) ((SOCKET) (Handle_val(sock_v)))

#else

/* Get the file descriptor inside the wrapper.
 */
#define Socket_val(sock_v) (Int_val(sock_v))
#define Val_socket(sock)   (Val_int(sock))

#endif



value Val_string_opt(char*);

value Val_msg(ce_len_t, ce_data_t);

//ce_view_id_t*
//View_id_of_val(value view_id_v);

/* Create a copy of an ML string on the C side. 
 */
char *String_copy_val(value);
		
//ce_view_id_t*
//View_id_val(value view_id_v);

ce_endpt_array_t Endpt_array_val(value, int n);


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

value Val_action (ce_action_t*);

/**************************************************************/
