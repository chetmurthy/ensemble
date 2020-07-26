(**************************************************************)
(*
 *  Ensemble, (Version 1.00)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
(**************************************************************)
(* POOL.MLI *)
(* Author: Mark Hayden, 10/97 *)
(**************************************************************)
open Trans
(**************************************************************)

(* Pools of objects.
 *)
type 'a t

(**************************************************************)
(* Create your own pool of objects.
 *)

type nlive = int
type nfree = int

val create :
  debug ->				(* Debugging name *)
  (unit -> 'a) ->			(* Alloc *)
  ('a -> unit) ->			(* Release *)
  (nlive -> nfree -> 'a list) ->	(* Refill policy function *)
  'a t  				(* Pool object *)

(**************************************************************)

(* Release free buffers.
 *)
val compact : 'a t -> unit

(* Return string of info about the pool
 *)
val info : 'a t -> string

(* Return the number of bufs in use.
 *)
val nbufs : 'a t -> int

(**************************************************************)

(* Allocation from a pool.
 *)
val alloc : debug -> 'a t -> 'a Refcnt.t

(**************************************************************)

val debug : 'a t -> string list

val grow : 'a t -> int -> unit

(**************************************************************)
val actually_use_counts : 'a t -> bool -> unit
val force_major_gc : 'a t -> bool -> unit
(**************************************************************)
