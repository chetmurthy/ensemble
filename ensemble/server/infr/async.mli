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
(* ASYNC.MLI *)
(* Author: Mark Hayden, 4/97 *)
(**************************************************************)

type t

val create : Sched.t -> t

(* Async.add: called by "receiver" to register a callback.
 * It returns disable function.
 *)
val add : t -> (Group.id * Endpt.id) -> (unit -> unit) -> (unit -> unit) 

(* Find is called by "sender" to generate new callback.
 *)
val find : t -> (Group.id * Endpt.id) -> (unit -> unit)

