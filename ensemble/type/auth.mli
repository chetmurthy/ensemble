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
(* AUTH.MLI *)
(* Authors: Mark Hayden, Ohad Rodeh, 8/96 *)
(**************************************************************)
(* This file gives a generic interface to authentication
 * services. *)
(**************************************************************)
open Trans
(**************************************************************)

type t

type clear = Buf.t			(* cleartext *)
type cipher = Buf.t			(* ciphertext *)

val lookup : Addr.id -> t

val principal : t -> Addr.id -> string -> Addr.t
(**************************************************************)

type ticket

val ticket : Addr.set(*me*) -> Addr.set(*him*) -> clear -> ticket option

val bckgr_ticket : bool (*simulation?*)-> Addr.set(*me*) -> Addr.set(*him*) ->
 	clear -> Alarm.t -> (ticket option -> unit) -> unit

val check : Addr.set(*me*) -> Addr.set (* him *) -> ticket -> clear option

val bckgr_check : bool (*simulation?*)-> Addr.set(*me*) -> Addr.set (*him*) -> 
	ticket -> Alarm.t -> (clear option -> unit) -> unit

(**************************************************************)

val create : 
  name ->
  (Addr.id -> string -> Addr.t) ->
  (Addr.id -> Addr.set -> Addr.set -> clear -> cipher option) ->
  (Addr.id -> Addr.set -> Addr.set -> clear -> Alarm.t -> 
    (cipher option -> unit) -> unit) -> 
  (Addr.id -> Addr.set -> Addr.set -> cipher -> clear option) ->
  (Addr.id -> Addr.set -> Addr.set -> cipher -> Alarm.t -> 
    (clear option -> unit) -> unit) -> 
  t

val install : Addr.id -> t -> unit

(**************************************************************)
