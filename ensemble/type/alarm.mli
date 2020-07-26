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
(* ALARM.MLI *)
(* Author: Mark Hayden, 4/96 *)
(**************************************************************)
open Trans
(**************************************************************)

(* ALARM: a record for requesting timeouts on a particular
 * callback.  
 *)
type alarm

val disable : alarm -> unit
val schedule : alarm -> Time.t -> unit

(**************************************************************)

(* ALARM.T: The type of alarms.
 *)
type t

(**************************************************************)

type poll_type = SocksPolls | OnlyPolls

val name	: t -> string		(* name of alarm *)
val gettime 	: t -> Time.t		(* get current time *)
val alarm 	: t -> (Time.t -> unit) -> alarm (* create alarm object *)
val check 	: t -> unit -> bool	(* check if alarms have timed out *)
val min 	: t -> Time.t		(* get next alarm to go off *)
val add_sock_recv : t -> debug -> Hsys.socket -> Hsys.handler -> unit (* add a socket *)
val rmv_sock_recv : t -> Hsys.socket -> unit (* remove socket *)
val add_sock_xmit : t -> debug -> Hsys.socket -> (unit->unit) -> unit (* add a socket *)
val rmv_sock_xmit : t -> Hsys.socket -> unit (* remove socket *)
val add_poll 	: t -> string -> (bool -> bool) -> unit (* add polling fun *)
val rmv_poll 	: t -> string -> unit	(* remove polling function *)
val block 	: t -> unit		(* block until next timer/socket input *)
val poll 	: t -> poll_type -> unit -> bool (* poll for socket data *)
val handlers    : t -> Route.handlers
val mbuf        : t -> Mbuf.t
val sched       : t -> Sched.t
val async       : t -> Async.t
val unique      : t -> Unique.t
val local_xmits : t -> Route.xmits

(**************************************************************)
(**************************************************************)
(* For use only by alarms.
 *)

type gorp = Unique.t * Sched.t * Async.t * Route.handlers * Mbuf.t

val create :
  string ->				(* name *)
  (unit -> Time.t) ->			(* gettime *)	
  ((Time.t -> unit) -> alarm) ->	(* alarm *)	      
  (unit -> bool) ->			(* check *)
  (unit -> Time.t) ->			(* min *)
  (string -> Hsys.socket -> Hsys.handler -> unit) -> (* add_sock *)	
  (Hsys.socket -> unit) ->		(* rmv_sock *)
  (string -> Hsys.socket -> (unit->unit) -> unit) -> (* add_sock_xmit *)	
  (Hsys.socket -> unit) ->		(* rmv_sock_xmit *)
  (unit -> unit) ->			(* block *)
  (string -> (bool -> bool) -> unit) ->	(* add_poll *)	
  (string -> unit) ->			(* rmv_poll *)
  (poll_type -> unit -> bool) ->	(* poll	*)
  gorp ->
  t

val alm_add_poll	: string -> (bool -> bool) -> ((bool -> bool) option)
val alm_rmv_poll	: string -> ((bool -> bool) option)

val wrap : ((Time.t -> unit) -> Time.t -> unit) -> t -> t
val c_alarm : (unit -> unit) -> (Time.t -> unit) -> alarm
(**************************************************************)
