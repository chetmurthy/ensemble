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
(* HSYSSUPP.MLI *)
(* Author: Mark Hayden, 6/96 *)
(**************************************************************)
open Trans
open Buf
(**************************************************************)

type 'a conn =
  (debug -> (Iovecl.t -> unit) ->
  ((Iovecl.t -> unit) * (unit -> unit) * 'a))

(* Turn a TCP socket into a send and recv function.
 *)

val server : 
  debug -> 
  Alarm.t ->
  port ->
  unit conn ->
  unit
     
val client : 
  debug -> 
  Alarm.t ->
  Hsys.socket ->
  'a conn ->
  'a
