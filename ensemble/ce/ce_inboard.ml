(**************************************************************)
(* CE_INBOARD.ML *)
(* Author: Ohad Rodeh  8/2001 *)
(* Based on code by Alexey Vaysburd and Mark Hayden *)
(**************************************************************)
open Ensemble
open Trans
open Buf
open Util
open View
open Appl_intf
open Appl_intf.New
open Ce_util
(**************************************************************)
let name = Trace.file "CE_INBOARD"
let failwith s = Trace.make_failwith name s
let log = Trace.log name
(**************************************************************)

(* External C functions.
 *)

type c_appl
type c_handler
type c_env

(* A table containing a cached function for asynchronous calls.
*)
let (async_tbl : (c_appl, unit -> unit) Hashtbl.t) = Hashtbl.create 13

external cback_exit : c_appl -> unit
  = "ce_Exit_cbd"

external cback_install : c_appl -> c_local_state -> c_view_state -> c_action array
  = "ce_Install_cbd"

external cback_flow_block : c_appl -> rank option -> bool -> unit
  = "ce_FlowBlock_cbd"

external cback_block : c_appl -> c_action array
  = "ce_Block_cbd"

(*
external cback_diable : c_appl -> unit
  = "ce_Disable_cbd"
*)

external cback_heartbeat : c_appl -> float -> unit
  = "ce_Heartbeat_cbd"

external cback_recv_cast : c_appl -> rank -> Iovec.raw array -> c_action array
  = "ce_ReceiveCast_cbd"

external cback_recv_send : c_appl -> rank -> Iovec.raw array -> c_action array
  = "ce_ReceiveSend_cbd"

(* Retrieve pending downcalls from C application.
 *)
external c_get_actions : c_appl -> c_action array
  = "ce_GetActions"

(* There is input on a socket, call the registered C function,
 * with its envrionment. 
*)
external c_pass_sock : c_handler -> c_env -> unit
  = "ce_PassSock"

(* Call out to C for printing and exceptions.
 *)
external c_printer : string -> bool
    = "ce_MLDoPrint"

external c_exception_handler : string -> bool
    = "ce_MLHandleException"

(**************************************************************)

let c_interface c_appl heartbeat_rate =
  (* When is the next heartbeat due 
   *)
  let alarm = Appl.alarm name in
  let hb_requested = ref false in
  let in_handler = ref false in

  let install ((ls,vs) as vf) = 
    log (fun () -> "(pre cback_install");
    let dncall_of_c = dncall_of_c (ls,vs) in
    let c_map = Array.map dncall_of_c  in
    let (c_ls,c_vs) = c_view_full vf in
    let c_init_acs = c_map (cback_install c_appl c_ls c_vs) in
    log (fun () -> ")");

    let receive o blk cs =
      let upcall = 
	match cs with
	| S ->
	    fun iovec ->
	      cback_recv_send c_appl o iovec
	| C ->
	    fun iovec ->
	      cback_recv_cast c_appl o iovec
      in
      fun iovl ->
      	let iovec_a = Iovecl.to_iovec_raw_array iovl in
      	let c_acs = upcall iovec_a in
	log (fun () -> "freeing(");
      	Iovecl.free iovl ;
	log (fun () -> ")");
	c_map c_acs
    in
    let heartbeat time = 
      let time = Time.to_float time in
      log (fun () -> "heartbeat(");
      cback_heartbeat c_appl time;
      log (fun () -> ")");
      let c_acs = c_get_actions c_appl in
      c_map c_acs

    in
    let block () = 
      log (fun () -> "block(");
      let c_acs = c_map (cback_block c_appl) in
      log (fun () -> ")");
      c_acs
    in
    let flow_block (rank_opt,onoff) = 
      log (fun () -> "flow_block(");
      cback_flow_block c_appl rank_opt onoff;
      log (fun () -> ")")
    in
    c_init_acs,{
      flow_block = flow_block ;
      heartbeat = heartbeat ;
      receive = receive ;
      block = block ; 
      disable = (fun () -> ())
    } 
  in
  let exit () = 
    log (fun () -> "exit(");
    cback_exit c_appl;
    Hashtbl.remove async_tbl c_appl;
    log (fun () -> ")")
  in
  { heartbeat_rate = Time.of_float heartbeat_rate ;
    install = install ;
    exit = exit }


let c_join c_appl jops = 
  let ls,vs = init_view_full jops in
  log (fun () -> "(Adding asynchronous call");
  let async = Appl.async (vs.group,ls.endpt) in
  Hashtbl.add async_tbl c_appl async;
  let heartbeat_rate = jops.jops_hrtbt_rate in
  log (fun () -> "c_interface(");
  let interface = c_interface c_appl heartbeat_rate in
  log (fun () -> ")");
  Appl.config_new interface (ls,vs) 


let c_async c_appl = 
  let f = Hashtbl.find async_tbl c_appl in
  f ()

(**************************************************************)
let run () = 
(*  let gc = Gc.get () in
  gc.Gc.verbose <- 2;
  Gc.set gc;*)

  (*Arge.set Arge.refcount true;*)

  Arge.parse [
  ] (Arge.badarg name) "C-Ensemble interface";
      
  if Arge.get Arge.modes = [Addr.Netsim] then (
    log(fun () -> "Setting short names");
    Arge.set Arge.short_names true ;
    Alarm.install_port (-2) ;
  ) ;

  let alarm = Appl.alarm name in
  (* Force linking of the Udp mode.  This causes
   * a port number to be installed in the 
   * Unique generator.
   *)
  let _ = Domain.of_mode alarm Addr.Udp in

  let c_add_sock_recv sock c_handler c_env = 
    Alarm.add_sock_recv alarm name sock 
      (Hsys.Handler0 (fun () -> 
	log (fun () -> "c_pass_sock(");
	c_pass_sock c_handler c_env;
	log (fun () -> ")"))
      ) in
  let c_rmv_sock_recv sock = Alarm.rmv_sock_recv alarm sock in
  
  (* Put all exported calls here. 
   *)
  Callback.register "ce_add_sock_recv_v" c_add_sock_recv ;
  Callback.register "ce_rmv_sock_recv_v" c_rmv_sock_recv ;
  Callback.register "ce_async_v" c_async ;
  Callback.register "ce_join_v" c_join ;
  Callback.register "ce_main_loop_v" Appl.main_loop ;
  ()

let _ =
  log (fun () -> "Starting ML side\n");

  (* HACK. 
   * This command should startup winsock on WIN32, and do 
   * nothing on other platforms.
   *)
  ignore (Unix.getpid ());

  let printer ch s =
    if not (c_printer s) then (
      output_string ch s ;
      flush ch
    )
  in
  Util.fprintf_override printer ;
  try run () with e ->
    let e = Util.error e in
    if not (c_exception_handler e) then
      eprintf "HOT_INBOARD:top:uncaught exception:%s\n" e ;
    exit 1

(**************************************************************)
