(**************************************************************)
(*
 *  Ensemble, (Version 1.00)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
(**************************************************************)
(* GOSSIP.ML: server side of gossip transport *)
(* Author: Mark Hayden, 8/95 *)
(**************************************************************)
open Ensemble
open Util
(**************************************************************)
let name = Trace.file "GOSSIP"
let failwith s = Trace.make_failwith name s
(**************************************************************)

let init appl =
  (*
   * Get default transport and alarm info.
   *)
  let view_state = Appl.default_info "gossip" in

  (* Get the port number to use from the argument module.
   *)
  let port = Arge.check name Arge.gossip_port in

  (* Initialize the Gossip stack.
   *)
  let view_state, interface = (Elink.get name Elink.reflect_init) appl view_state port false in
  Appl.config_new interface view_state
  (* end of init function *)


let run () = 
  (* Set the default pollcount value to 0.  This makes the
   * application somewhat more efficient.  
   *)
  Arge.set Arge.pollcount 0 ;

  let groupd = ref false in
  let protos = ref false in

  (*
   * Parse command line arguments.
   *)
  Arge.parse [
    (*
     * Extra arguments go here.
     *)
    "-also_groupd", Arg.Set(groupd), "also run as groupd" ;
    "-also_protos", Arg.Set(protos), "also run as protos"
  ] (Arge.badarg name) "gossip server" ;
 
  let alarm = Appl.alarm name in

  if !groupd || !protos then (
    let groupd_started = ref false in
    let gossip_started = ref false in
    let protos_started = ref false in

    if !groupd then (
      try
    	Groupd.init alarm ;
	groupd_started := true ;
      with e ->
	printf "GOSSIP:error initializing groupd (%s)\n" (Hsys.error e) ;
    ) ;

    if !protos then (
      let port = Arge.check name Arge.protos_port in
      try
	let marsh,unmarsh = Elink.get name Elink.protos_make_marsh (Alarm.mbuf alarm) in
	let client_init info send =
	  let send msg =
	    send (marsh msg)
	  in
	  let recv,disable,() =
	    Elink.get name Elink.protos_server alarm Appl.addr Appl.config_new info send
	  in

	  let recv msg =
	    recv (unmarsh msg)
	  in
	  recv,disable,()
	in

	(Elink.get name Elink.hsyssupp_server) name alarm port client_init ;
	protos_started := true ;
      with e ->
	printf "GOSSIP:error initializing protos (%s)\n" (Hsys.error e) ;
    ) ;

    begin
      try
    	init alarm ;
	gossip_started := true ;
      with e ->
	printf "GOSSIP:error initializing gossip (%s)\n" (Hsys.error e) ;
    end ;

    begin
      match !groupd_started, !gossip_started, !protos_started with
      | false, false, false ->
	  printf "GOSSIP:no servers started successfully, exiting\n" ;
	  exit 0
      | true, true, true -> ()
      | _ ->
	  printf "GOSSIP:at least one server is running, will continue\n"
    end
  ) else (
    (* Do basic initialization.
     *)
    init alarm
  ) ;

  (*
   * Enter a main loop
   *)
  Appl.main_loop ()
 (* end of run function *)


(* Run the application, with exception handlers to catch any
 * problems that might occur.
 *)
let _ = Appl.exec ["gossip"] run

(**************************************************************)
