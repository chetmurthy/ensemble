(**************************************************************)
(*
 *  Ensemble, 2_00
 *  Copyright 2004 Cornell University, Hebrew University
 *           IBM Israel Science and Technology
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
  let view_state, interface = Reflect.init appl view_state port false in
  Appl.config_new interface view_state
  (* end of init function *)


let run () = 
  Arge.parse [
  ] (Arge.badarg name) "gossip";

(*  let stat = Gc.get () in
  stat.Gc.verbose <- 3;
  Gc.set stat;*)

  (* Set the default pollcount value to 0.  This makes the
   * application somewhat more efficient.  
   *)
  Arge.set Arge.pollcount 0 ;

  let alarm = Appl.alarm name in
  init alarm ;

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
