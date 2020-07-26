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
(* HOT_OUTBOARD.ML *)
(* Author: Alexey Vaysburd, 11/96 *)
(* Bug Fixes, Cleanup: Mark Hayden, 4/97 *)
(* More Bug Fixes, Cleanup: Mark Hayden, 5/97 *)
(* Aded TCP outboard mode for NT: Werner Vogels 10/97 *)
(* More cleanup: Mark Hayden, 11/97 *)
(**************************************************************)
open Util
open View
open Appl_intf
open Appl_intf.Protosi
open Hot_util
open Marsh
open Buf
(**************************************************************)
let name = Trace.file "HOT_OUTBOARD"
let failwith s = Trace.make_failwith name s
let log = Trace.log name
(**************************************************************)
(* Marshalling and unmarshalling.  These functions are using
 * the Ensemble Marsh module.  For marshalling, we first write
 * into a "marshaller", then convert that to a string, and
 * finally write the string out preceded by its length.
 *)

let write_init = Marsh.marsh_init

let write_endpt = write_string
let write_msg m buf ofs len = write_string m (String.sub buf ofs len)
let write_gctx = write_int
let write_cbtype = write_int
let write_endpt_array m = write_array m (write_endpt m)
let write_bool_array m = write_array m (write_bool m)

(**************************************************************)

let up_view      = 0 
and up_cast      = 1 
and up_send      = 2 
and up_heartbeat = 3 
and up_block     = 4 
and up_exit      = 5 

let marsh_upcall mbuf id msg =
  let m = write_init mbuf in
  write_gctx m id ;
  begin
    match msg with
    | UInstall vf ->
	let v = c_view_state vf in
  	write_cbtype m up_view ;
  	write_string m v.c_version ;
  	write_string m v.c_group ;
  	write_endpt_array m v.c_view ;
  	write_int m v.c_rank ;
  	write_string m v.c_protocol ;
  	write_bool m v.c_groupd ;
  	let ltime,coord = v.c_view_id in
  	write_int m ltime ;
  	write_endpt m coord ;
  	write_string m v.c_params ;
  	write_bool m v.c_xfer_view ;
  	write_bool m v.c_primary ;
  	write_bool_array m v.c_clients
    | UReceive(origin,cs,iovl) -> (
	let typ = 
	  match cs with
	  | Appl_intf.New.C -> up_cast
	  | Appl_intf.New.S -> up_send
	in
	write_cbtype m typ ;
	write_int m origin ;
	write_iovl_len m iovl
      )
    | UHeartbeat time ->
	write_cbtype m up_heartbeat ;
  	let time = milli_of_time time in
  	write_int m time
    | UBlock ->
  	write_cbtype m up_block
    | UExit ->
  	write_cbtype m up_exit
  end ;
  Marsh.marsh_done m

(**************************************************************)

(* Process input from stdin.  Read a downcall + add to the
 * array of pending downcalls.
 *)
let dncall_unmarsh mbuf iovl =
  let iovl = Iovecl.take name iovl in
  let m = Marsh.unmarsh_init mbuf iovl in
  let read_int () = Marsh.read_int m in
  let read_string () = Marsh.read_string m in
  let read_bool () = 
    let b = read_int() in
    (b != 0)
  in
  let read_iovl () =
    let len_iov = Marsh.read_iovl m len4 in
    let len_int = Iovecl.read_net_int name len_iov len0 in
    let len_len = ceil len_int in
    let iovl = Marsh.read_iovl m len_len in
    Iovecl.append name len_iov iovl
  in
  let read_endpt = read_string in
  let id = read_int () in
  let ltime = read_int () in
  let dntype = read_int () in
  let ret =
    match dntype with
    | 0 ->
	let rate = read_int () in
	let transports = read_string () in
	let protocol = read_string () in
	let group_name = read_string () in
	let properties = read_string () in
	let use_properties = read_bool () in
	let groupd = read_bool () in
	let params = read_string () in
	let client = read_bool () in
	let debug = read_bool () in

	(* This is currently unsupported for outboard mode.
	 *)
	let endpt = "" in

	let jops = {
	  jops_hrtbt_rate = rate;
	  jops_transports = transports;
	  jops_protocol = protocol;
	  jops_group_name = group_name;
	  jops_properties = properties;
	  jops_use_properties = use_properties;
	  jops_groupd = groupd;
	  jops_params = params;
	  jops_client = client;
	  jops_debug = debug;
	  jops_endpt = endpt;
	} in
	let _,vs = init_view_state jops in
	let heartbeat_rate = Time.of_float (float jops.jops_hrtbt_rate /. 1000.0) in
	let modes = Arrayf.to_list (Addr.ids_of_set (Arrayf.get vs.address 0)) in
	Create(id,vs,heartbeat_rate,modes)
    | 1 ->				(* Cast *)
	let iovl = read_iovl () in
	Dncall(id,ltime,Cast(iovl))
    | 2 ->				(* Send*)
	let dest = read_endpt () in
	let iovl = read_iovl () in
	SendEndpt(id,ltime,dest,iovl)
    | 3 ->				(* Suspect *)
	let size = read_int () in
	let susp = ref [] in
	for i = 1 to size do
	  let endpt = read_endpt () in
	  susp := endpt :: !susp
	done;
	let suspects = List.rev !susp in
	SuspectEndpts(id,ltime,suspects)
    | 4 ->				(* Protocol *)
	let proto = read_string () in
	Dncall(id,ltime,Control(Protocol(Proto.id_of_string proto)))
    | 5 ->				(* Property *)
	let props = read_string () in
	let protocol =
	  let props = 
	    let props_l = Util.string_split ":" props in
	    let props_l = List.map Property.id_of_string props_l in
	    props_l
	  in
	  Property.choose props
	in
	Dncall(id,ltime,Control(Protocol protocol))
    | 6 ->				(* Leave *)
	Dncall(id,ltime,Control Leave)
    | 7 ->				(* Prompt *)
	Dncall(id,ltime,Control Prompt)
    | 8 ->				(* Block *)
	Dncall(id,ltime,Control(Block true))
    | 9 ->
	let dest = read_int () in
	let iovl = read_iovl () in
	Dncall(id,ltime,Send([|dest|],iovl))
    | _ -> failwith sanity
  in
  Marsh.unmarsh_done_all m ;
  ret

(**************************************************************)

let run () =
  (* Set the default pollcount value to 0.  This makes the
   * application somewhat more efficient.  
   *)
  Arge.set Arge.pollcount 0 ;
  let set_ident name v = v in
  let tcp_channel  = Arge.bool set_ident false "tcp_channel" "active TCP channel in outboard mode" in
  let tcp_port     = Arge.int set_ident 5002 "tcp_port" "set port outboard TCP channel" in

  Arge.parse [
    (*
     * Extra arguments can go here.
     *)
  ] (Arge.badarg name) "outboard:Ensemble HOT tools outboard daemon";

  let alarm = Appl.alarm name in
  let mbuf = Alarm.mbuf alarm in

  (* Force linking of the Udp mode.  This causes
   * a port number to be installed in the 
   * Unique generator.
   *)
  let _ = Elink.domain_of_mode alarm Addr.Udp in

  Appl.start_monitor ();

  (* Get the server.
   *)
  let protos_server = (Elink.get name Elink.protos_server) alarm Appl.addr Appl.config_new in

  (* Wrap the client handler with the HOT outboard marshaller.
   *)
  let client info send =
    let send = function
      |	Upcall(id,msg) ->
	  let iovl = marsh_upcall mbuf id msg in
	  send iovl
      |	_ -> failwith sanity
    in

    let recv,disable,() = protos_server info send in

    let recv iovl =
      let msg = dncall_unmarsh mbuf iovl in
      recv msg
    in

    (recv,disable,())
  in

  (* Use stdin or TCP for establishing connections.
   *)
  let chan =
    if Arge.get tcp_channel then (
      let port = Arge.get tcp_port in
      Elink.get name Elink.hsyssupp_server name alarm port
    ) else (
      let stdin = Hsys.stdin () in
      Elink.get_hsyssupp_client name name alarm stdin
    )
  in
  chan client ;

  eprintf "HOT_OUTBOARD:starting Ensemble in outboard mode\n";
  Appl.main_loop ()

(* Run the application, with exception handlers to catch any
 * problems that might occur.
 *)
let _ = Appl.exec ["outboard"] run

(**************************************************************)
