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
(* TRANSPORT.MLI *)
(* Author: Mark Hayden, 7/95 *)
(**************************************************************)
open Trans
(**************************************************************)

(* This is the type of object used to send messages.
 *)
type 'msg t

(* Construct and enable a new transport instance.
 *)
val f :
  Alarm.t ->
  (Addr.id -> int) ->
  View.full ->
  Stack_id.t ->				(* stack id *)
  'msg Route.t ->			(* connection table *)
  (Conn.kind -> rank -> bool -> 'msg) -> (* message handler *)
  'msg t

val f2 :
  Alarm.t ->
  (Addr.id -> int) ->
  View.full ->
  Stack_id.t ->				(* stack id *)
  'msg Route.t ->			(* connection table *)
  ('msg t -> ((Conn.kind -> rank -> bool -> 'msg) * 'a)) -> (* message handler *)
  'a
	
(**************************************************************)

val disable	: 'msg t -> unit	(* disable the transport*)
val send	: 'msg t -> rank -> 'msg (* send on the transport *)
val cast	: 'msg t -> 'msg	(* cast on the transport *)
val gossip	: 'msg t -> 'msg	(* gossip on the transport *)
val merge	: 'msg t -> View.id option -> Endpt.full -> 'msg

(**************************************************************)
