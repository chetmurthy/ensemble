(**************************************************************)
(*
 *  Ensemble, 1_42
 *  Copyright 2003 Cornell University, Hebrew University
 *           IBM Israel Science and Technology
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
(**************************************************************)
(* CE_UTIL.ML *)
(* Author : Ohad Rodeh 8/2001 *)
(* Based on code by: Alexey Vaysburd, Mark Hayden *)
(**************************************************************)
open Ensemble
open Printf
open Trans
open Util
open Buf
open View
open Appl_intf
(**************************************************************)
let name = Trace.file "CE_UTIL"
let failwith s = Trace.make_failwith name s
let log = Trace.log name
let log2 = Trace.log (name^"2")
(**************************************************************)

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
  | C_No_op*)
  | C_Properties of string  (* For backward compatibility with HOT *)
  | C_BlockOk of bool

let string_of_c_action = function
    C_Cast _ -> "C_Cast"
  | C_Send _ -> "C_Send"
  | C_Send1 _ -> "C_Send1"
  | C_Leave _ -> "C_Leave"
  | C_Prompt _ -> "C_Prompt"
  | C_Suspect _ -> "C_Suspect"
  | C_XferDone _ -> "C_XferDone"
  | C_Rekey _ -> "C_Rekey"
  | C_Protocol _ -> "C_Protocol"
  | C_Properties _ -> "C_Properties"
  | C_BlockOk _ -> "C_BlockOk"

let of_iovec_array = Iovecl.of_iovec_raw_array

let dncall_of_c (ls,vs) = 
  function dncall -> 
    log2 (fun () -> string_of_c_action dncall);
    match ( dncall : c_action) with 
      | C_Cast iovl ->
	  let iovl = of_iovec_array iovl in
	  (*let ilen = int_of_len (Iovecl.len iovl) in
	  log (fun () -> sprintf "Cast, len=%d msg=%s" 
	    ilen
	    (Iovec.string_of (Iovec.sub (Iovecl.flatten iovl) len0 len16))
	  );*)
	  Cast(iovl)
      | C_Send(dests,iovl) -> 
	  let iovl = of_iovec_array iovl in
	  log (fun () -> sprintf "dests=%s  iovl=%d" 
	    (string_of_int_array dests) (int_of_len (Iovecl.len iovl)));
	  Send(dests,iovl)
      | C_Send1(dest,iovl) -> 
	  let iovl = of_iovec_array iovl in
	  Send1(dest,iovl)
      | C_Leave () -> 
	  log (fun () -> "Leave");
	  Control Leave
      | C_Prompt () -> 
	  log (fun () -> "Prompt");
	  Control Prompt
      | C_Suspect sa -> Control (Suspect (Array.to_list sa))
      | C_XferDone () -> 
	  log (fun () -> "XferDone");
	  Control XferDone
      | C_Rekey () -> Control (Rekey false)
      | C_Protocol proto -> 
	  Control (Protocol (Proto.id_of_string proto))
      | C_Properties properties ->
	  let protocol =
	    let props = 
	      let props_l = Util.string_split ":" properties in
	      let props_l = List.map Property.id_of_string props_l in
	      if vs.groupd then
		Property.strip_groupd props_l
	      else 
		props_l
	    in
	    Property.choose props
	  in
	  Control (Protocol protocol)
      | C_BlockOk flag -> 
	  log (fun () -> sprintf "BlockOk(%b)" flag);
	  Control(Block flag)

(**************************************************************)

(* Some type aliases.
 *)
type endpt = string
type msg = string
type c_view_id = int * string

let c_view_id_of_ml (ltime,endpt) = 
  (ltime, Endpt.string_of_id endpt)

(**************************************************************)

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
  c_prev_ids : c_view_id array ; 
  c_params :   string ;
  c_uptime : float ;

  (* Per-member arrays.
   *)
  c_view : string array ;
  c_address : string array 
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

(* These options are passed with application's join()
 * downcalls.  
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

(* Convert a param string into a param list.
 * Format of the param string: "name=val:type;...." 
 * (see Param.t for supported types).  The type of param list is Param.tl.
 *) 

let paraml_of_string s = 
  log2 (fun () -> sprintf "parameters=%s" s) ;
  let params = Util.string_split ";" s in
  List.map (fun param ->
    try
      match Util.string_split "=" param with
      | [param_name;rest] -> (
	  let value =
	    match Util.string_split ":" rest with
	    | [param_str;param_type] -> (
		match param_type with
		| "string" -> Param.String(param_str)
		| "int"    -> Param.Int(int_of_string param_str)
		| "float"  -> Param.Float(float_of_string param_str)
		| "bool"   -> Param.Bool(bool_of_string param_str)
		| "time"   -> Param.Time(Time.of_float(float_of_string param_str))
		| _ -> failwith "HOT_UTIL: bad parameter type"
	      )
	    | _ -> failwith "HOT_UTIL: bad parameter format"
	  in param_name,value
	)
      | _ -> failwith "HOT_UTIL: bad parameter format"
    with _ ->
      eprintf "HOT_UTIL: parameter parsing error\n" ;
      eprintf "  parameter='%s'\n" param ;
      eprintf "  sample format: 'integerparam=1:int;timeparam2=1.0:time'\n" ;
      exit 1
  ) params
   
(* Convert a param list into a param string.
 *)
let string_of_paraml p = 
  let p = List.map Param.to_string p in
  String.concat ";" p


(* Add an address my list of addresses.
 *)
let add_principal princ (ls,vs) = 
  log2 (fun () -> "add_principal"); 
  if String.length princ = 0 then (
    (ls,vs)
  ) else if String.length princ <= 5 then 
    failwith (sprintf "principal name is too short (%s)" princ)
  else (
    let sub = String.sub princ 0 4 in
    match sub with
      | "Pgp(" -> 
	  let princ = String.sub princ 4 (String.length princ - 5) in
	  let base = Addr.arrayf_of_set (Arrayf.get vs.address ls.rank) in
	  let pgp = Addr.PgpA(princ) in
	  let pgp = Arrayf.singleton pgp in
	  let addr = Arrayf.append base pgp in
	  let addr = Addr.set_of_arrayf addr in
	  let addr = Arrayf.singleton addr in
	  let vs = View.set vs [Vs_address addr] in
	  let ls = View.local name ls.endpt vs in
	  (ls,vs)
      | _ -> 
	  failwith "Only Pgp is currently supported"
  )
(**************************************************************)

(* Initialize a group member and return the initial singleton view 
 *)
let init_view_full jops = 
  let groupd = jops.jops_groupd in
  let properties = 
    if jops.jops_use_properties then (
      let properties = 
	let props_l = Util.string_split ":" jops.jops_properties in
	let props_l = List.map Property.id_of_string props_l in
      	if groupd then
	  Property.strip_groupd props_l
	else 
	  props_l
      in
      Some properties
    ) else (
      None
    )
  in      
  let group_name = jops.jops_group_name in
  let protocol = match properties with
    | None -> 
	eprintf "HOT_ML:warning:using a raw protocol stack\n" ;
	Proto.id_of_string jops.jops_protocol
    | Some properties -> 
	Property.choose properties
  in
  let protos = false in
  let transports = jops.jops_transports in
  let modes = 
    if transports = "" then 
      Arge.get Arge.modes
    else
      let transp_list = string_split ":" transports in
      List.map Addr.id_of_string transp_list 
  in
    
  let params = jops.jops_params in
  let params = paraml_of_string params in

  let endpt =
    if jops.jops_endpt = "" then 
      let alarm = Appl.alarm name in
      Endpt.id (Alarm.unique alarm)
    else 
      Endpt.extern jops.jops_endpt
  in

  let princ = jops.jops_princ in
  let key = match Arge.get Arge.key with
  | None -> 
      let key = jops.jops_key in
      if String.length key = 0 then (
	log2 (fun () -> "Key is empty, setting to NoKey");
	Security.NoKey
      ) else Security.key_of_buf (Buf.of_string key)
  | Some s -> Security.key_of_buf (Buf.of_string s)
  in
  let secure = jops.jops_secure in

  let (ls,vs) =
    Appl.full_info group_name endpt groupd protos protocol modes key
  in
  let clients = Arrayf.fset vs.View.clients 0 jops.jops_client in
  let vs = View.set vs [
    View.Vs_params params ;
    View.Vs_clients clients
  ] in
  let (ls,vs) = add_principal princ (ls,vs) in
  let (ls,vs) = 
    if secure then match properties with
      | None -> 
	  failwith "Cannot set a secure group, without the properties"
      | Some props -> 
	  let vs = View.set vs [
	    View.Vs_key key ;
	  ] in
	  Appl.set_secure (ls,vs) props
    else (ls,vs)
  in
  (ls,vs)

(**************************************************************)

(* Convert a view state into a structure in the C
 * application format.
 *)
let c_view_full (ls,vs) = 
  let key = match vs.key with 
    | Security.NoKey -> ""
    | Security.Common _ -> Buf.string_of (Security.buf_of_key vs.key)
  in    
  let c_prev_ids = Array.of_list (List.map c_view_id_of_ml vs.prev_ids) in
  let c_vs = { 
    c_version = Version.string_of_id vs.version ;
    c_group = Group.string_of_id vs.View.group ;
    c_coord = vs.coord;
    c_ltime = vs.View.ltime ;
    c_primary = vs.View.primary ;
    c_proto = Proto.string_of_id vs.View.proto_id ;
    c_groupd = vs.View.groupd ;
    c_xfer_view = vs.View.xfer_view ;
    c_key  =  key ;
    c_prev_ids = c_prev_ids ;
    c_params = string_of_list Param.to_string vs.params ;
    c_uptime = Time.to_float vs.uptime ;
    c_view = Array.map Endpt.string_of_id (Arrayf.to_array vs.View.view) ;
    c_address = Array.map Addr.string_of_set (Arrayf.to_array vs.address)
  } in
  let c_ls = {
    c_endpt = Endpt.string_of_id ls.endpt ;
    c_addr = Addr.string_of_set ls.addr ;
    c_rank = ls.rank ;
    c_name = ls.name ;
    c_nmembers = ls.nmembers ;
    c_view_id = c_view_id_of_ml ls.view_id ;
    c_am_coord = ls.am_coord
  } in
  (c_ls,c_vs)
  
(**************************************************************)
