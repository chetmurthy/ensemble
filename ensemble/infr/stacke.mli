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
(* STACKE.MLI *)
(* Author: Mark Hayden, 4/96 *)
(**************************************************************)

val config_full : 
  Glue.glue ->				(* glue *)
  Alarm.t ->
  (Addr.id -> int) ->
  Layer.state ->			(* application *)
  View.full ->				(* view state *)
  (Event.up -> unit) ->			(* events out of top *)
  (Event.dn -> unit)			(* events into top *)

(**************************************************************)

val config :
  Glue.glue ->				(* glue *)
  Alarm.t ->
  (Addr.id -> int) ->
  Layer.state ->			(* application *)
  View.full ->				(* view state *)
  unit

(**************************************************************)
