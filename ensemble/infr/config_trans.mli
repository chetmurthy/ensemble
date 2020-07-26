(**************************************************************)
(*
 *  Ensemble, 1.10
 *  Copyright 2001 Cornell University, Hebrew University
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
