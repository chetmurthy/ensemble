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
(* PROXY.MLI *)
(* Author: Mark Hayden, 11/96 *)
(* Designed with Roy Friedman *)
(**************************************************************)
open Trans
open Mutil
(**************************************************************)

(* Type of proxy clients.
 *)
type t

(* Create a proxy client.
 *)
val create : Alarm.t -> Hsys.socket -> t

(* Join a maestro group via a proxy.
 *)
val join : t -> group -> endpt -> ltime ->
  (coord_msg -> unit) -> (member_msg -> unit)

(* Initialize a proxy server.
 *)
val server : 
  Alarm.t ->
  port ->
  (group -> endpt -> ltime -> 
   (coord_msg -> unit) -> (member_msg -> unit)) ->
  unit

(**************************************************************)
