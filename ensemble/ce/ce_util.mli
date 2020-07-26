(**************************************************************)
(* HOT_UTIL.MLI *)
(* Authors: Alexey Vaysburd, Mark Hayden 11/96 *)
(**************************************************************)
open Ensemble
open Trans
open Buf
(**************************************************************)

(* Types of C application's downcalls to Ensemble.  The
 * 'unit's are to force Ocaml to not use constant tags
 * in the representation.
 *)
type c_action = 
  | C_Cast of Iovec.raw array
  | C_Send of rank array * Iovec.raw array
  | C_Send1 of rank * Iovec.raw array
  | C_Leave of unit
  | C_Prompt of unit
  | C_Suspect of rank array
  | C_XferDone of unit
  | C_Rekey of unit
  | C_Protocol of string
(*  | C_Timeout of time
  | C_Dump
  | C_Block of bool
  | C_No_op*)
  | C_Properties of string  (* For backward compatibility with HOT *)

val dncall_of_c : View.full -> c_action -> (Iovecl.t, Iovecl.t) Appl_intf.action

(**************************************************************)

type endpt = string
type msg = string
type c_view_id = int * string

(**************************************************************)
(* Types shared with the C application.
 *
 * NOTE: Changes to type definitions below require
 * corresponding modifications to be done in the C stubs.
 *)


(* View state structure passed to the application. 
 *)
type c_view_state = {
  c_version : string ;
  c_group : string ;
  c_proto : string ;
  c_coord : rank ;
  c_ltime : ltime ;
  c_primary : bool ;
  c_groupd : bool ;
  c_xfer_view : bool ;
  c_key : string ;
  c_num_ids : int ;
  c_prev_ids : c_view_id array ; 
  c_params   : string ;
  c_uptime     : float ;

  (* Per-member arrays.
   *)
  c_view  : string array ;
  c_address : string array ;
} 


type c_local_state = {
  c_endpt	: string ;
  c_addr	: string ; 
  c_rank        : int ;
  c_name	: string ; 
  c_nmembers    : int ;
  c_view_id 	: c_view_id ;	
  c_am_coord    : bool ;  
}  


(* These options are passed by an application's join() call.
 *)
type jops = {
  jops_hrtbt_rate	: float ;
  jops_transports	: string ;
  jops_protocol	        : string ;
  jops_group_name	: string ;
  jops_properties	: string ;
  jops_use_properties	: bool ;
  jops_groupd	        : bool ;
  jops_params	        : string ;
  jops_client           : bool ;
  jops_debug            : bool ;
  jops_endpt            : string ;
  jops_princ            : string ;
  jops_key              : string ;
  jops_secure           : bool
}

(**************************************************************)

val init_view_full : jops -> View.full
val c_view_full : View.full -> c_local_state * c_view_state

(**************************************************************)

