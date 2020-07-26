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
(* PROTOS.MLI *)
(* Authors: Mark Hayden, Alexey Vaysburd 11/96 *)
(**************************************************************)
open Trans
open Appl_intf
open Appl_intf.Protosi
(**************************************************************)

(* NOTE: these types are defined in Appl_intf.Protosi
 * (for the Elink module).
 *)
(*
type id = int

type endpt = string

type dncall = (Iovecl.t,Iovecl.t) Appl_intf.action

type upcall = 
  | UInstall of View.full
  | UReceive of origin * blocked * cast_or_send * Iovecl.t
  | UHeartbeat of Time.t
  | UBlock
  | UExit

type message =
  | Create of id * View.state * Time.t * (Addr.id list)
  | Upcall of id * upcall
  | Dncall of id * ltime * dncall
  | SendEndpt of id * ltime * endpt * Iovecl.t
  | SuspectEndpts of id * ltime * endpt list
*)

val string_of_message : 'a message_gen -> string

val string_of_dncall : 'a dncall_gen -> string

val string_of_upcall : 'a upcall_gen -> string

(**************************************************************)

(* The type of a protos connection.
 *)
type config = View.full -> Layer.state -> unit

(**************************************************************)

(* Generate a message marshaller.
 *)
val make_marsh :
  Mbuf.t -> 
    (message -> Iovecl.t) *
    (Iovecl.t -> message)

(* Handle a new client connection.
 *)
val server :
  Alarm.t ->
  (Addr.id list -> Addr.set) ->
  (Appl_intf.New.t -> View.full -> unit) ->
  debug -> (message -> unit) ->
  ((message -> unit) * (unit -> unit) * unit)

(* Create a client instance given message channels.
 *)
val client :
  Alarm.t -> 
  debug -> (message -> unit) ->
  ((message -> unit) * (unit -> unit) * config)

(**************************************************************)
