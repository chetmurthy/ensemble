(**************************************************************)
(*
 *  Ensemble, (Version 0.70p1)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
(**************************************************************)
(* HOT_UTIL.ML *)
(* Authors: Alexey Vaysburd, Mark Hayden 11/96 *)
(**************************************************************)
open Util
open Trans
open Buf
open Marsh
open View
open Protos
open Appl_intf
(**************************************************************)
let name = Trace.file "HOT_UTIL"
let failwith s = Trace.make_failwith name s
let log = Trace.log name
let trace s = log (fun () -> s)
(**************************************************************)

(* Some type aliases.
 *)
type endpt = string
type msg = string
type millisec = int

let start = Time.gettimeofday ()

let milli_of_time time =
  (* Subtract the starting time so that we will hopefully
   * not overflow.
   *)
  let time = Time.sub time start in
  let time = Time.to_timeval time in
  let usec = time.Hsys.usec in
  let time = time.Hsys.sec10 * 10000 + time.Hsys.usec / 1000 in
  time

(**************************************************************)

(* View state structure passed to the application. 
 *)
type c_view_state = {
  c_version	: string ;
  c_group	: string ;
  c_view	: endpt array ; 
  c_rank	: int ;
  c_protocol    : string ;
  c_groupd	: bool ;
  c_view_id	: Trans.ltime * endpt ;
  c_params	: string ;
  c_xfer_view	: bool ; 
  c_primary	: bool ;
  c_clients     : bool array
}

(* These options are passed with application's join()
 * downcalls.  
 *)
type join_options = {
  jops_hrtbt_rate	: millisec ;
  jops_transports	: string ;
  jops_protocol	        : string ;
  jops_group_name	: string ;
  jops_properties	: string ;
  jops_use_properties	: bool ;
  jops_groupd	        : bool ;
  jops_params	        : string ;
  jops_client           : bool ;
  jops_debug            : bool ;
  jops_endpt            : string
}

(**************************************************************)

(* Convert a param string into a param list.
 * Format of the param string: "name=val:type;...." 
 * (see Param.t for supported types).  The type of param list is Param.tl.
 *) 

let paraml_of_string s = 
  log (fun () -> sprintf "parameters=%s" s) ;
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

(**************************************************************)

(* Initialize a group member and return the initial singleton view 
 *)
let init_view_state jops = 
  let alarm = Appl.alarm name in
  let groupd = jops.jops_groupd in
  let setup_protocol () = 
    if jops.jops_use_properties then (
      let properties = 
	let props_l = Util.string_split ":" jops.jops_properties in
	let props_l = List.map Property.id_of_string props_l in
      	if groupd then
	  Property.strip_groupd props_l
	else 
	  props_l
      in
      Property.choose properties
    ) else (
      eprintf "HOT_ML:warning:using a raw protocol stack\n" ;
      Proto.id_of_string jops.jops_protocol
    )
  in      
  let group_name = jops.jops_group_name in
  let protocol = setup_protocol () in
  let protos = false in
  let transports = jops.jops_transports in
  let transp_list = string_split ":" transports in
  let modes = List.map Addr.id_of_string transp_list in
  let key = match Arge.get Arge.key with
  | None -> Security.NoKey
  | Some s -> Security.Common(Buf.pad_string s)
  in
  let params = jops.jops_params in
  let params = paraml_of_string params in

  let endpt =
    if jops.jops_endpt = "" then 
      Endpt.id (Alarm.unique alarm)
    else 
      Endpt.extern jops.jops_endpt
  in

  let (ls,vs) =
    Appl.full_info group_name endpt groupd protos protocol modes key
  in
  
  let clients = Arrayf.fset vs.View.clients 0 jops.jops_client in
  let vs = View.set vs [
    View.Vs_params params ;
    View.Vs_clients clients
  ] in
  (ls,vs)
(* init_view_state *)

(**************************************************************)

(* Convert a view state into a structure in the C
 * application format.
 *)
let c_view_state (ls,vs) = 
  let view_id = 
    let (ltime,endpt) = ls.View.view_id in
    (ltime,Endpt.string_of_id endpt)
  in

  { c_version = Version.string_of_id vs.View.version ;
    c_group = Group.string_of_id vs.View.group ;
    c_view = Array.map Endpt.string_of_id (Arrayf.to_array vs.View.view) ;
    c_rank = ls.View.rank ;
    c_protocol = Proto.string_of_id vs.View.proto_id ;
    c_groupd = vs.View.groupd ;
    c_view_id = view_id ;
    c_params = string_of_paraml vs.View.params ;
    c_xfer_view = vs.View.xfer_view ;
    c_primary = vs.View.primary ;
    c_clients = Arrayf.to_array vs.View.clients
  }

(**************************************************************)
