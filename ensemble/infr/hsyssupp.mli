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


(* These are the same as above, except that the inet & port
 * of the client to the server instead of just a debugging
 * string.  
 *)
type 'a conn_gen =
  (Hsys.inet -> Hsys.port -> (Iovecl.t -> unit) ->
  ((Iovecl.t -> unit) * (unit -> unit) * 'a))

val server_gen : 
  debug -> 
  Alarm.t ->
  port ->
  unit conn_gen ->
  unit
