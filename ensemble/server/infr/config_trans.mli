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
(* CONFIG_TRANS.MLI *)
(* Author: Mark Hayden, 10/96 *)
(**************************************************************)

val f :
  Alarm.t ->
  (Addr.id -> int) ->
  ('local,'abv,'hdr) Layer.msg -> View.full ->
  (Event.t -> ('local,'abv,'hdr) Layer.msg -> unit) ->
  (Event.t -> ('local,'abv,'hdr) Layer.msg -> unit)
