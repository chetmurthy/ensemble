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

(* Note: this file is modified from the Caml Light 7.1
 * distribution.  Does the above copyright apply?
 *)

(* Queues *)

(* This module implements queues (FIFOs), with in-place modification. *)

type 'a t
        (* The type of queues containing elements of type ['a]. *)

(*exception Empty*)
        (* Raised when [take] is applied to an empty queue. *)

val create: unit -> 'a t
        (* Return a new queue, initially empty. *)
val add: 'a -> 'a t -> unit
        (* [add x q] adds the element [x] at the end of the queue [q]. *)
val take: 'a t -> 'a
        (* [take q] removes and returns the first element in queue [q],
           or fails if the queue is empty. *)
val peek: 'a t -> 'a
        (* [peek q] returns the first element in queue [q], without removing
           it from the queue, or fails if the queue is empty. *)
val clear : 'a t -> unit
        (* Discard all elements from a queue. *)
val length: 'a t -> int
        (* Return the number of elements in a queue. *)
val iter: ('a -> 'b) -> 'a t -> unit
        (* [iter f q] applies [f] in turn to all elements of [q], from the
           least recently entered to the most recently entered.
           The queue itself is unchanged. *)

(* Ensemble additions.
 *)
val empty : 'a t -> bool
val takeopt : 'a t -> 'a option
val to_list : 'a t -> 'a list
val to_array : 'a t -> 'a array
val clean : ('a -> unit) -> 'a t -> unit
val transfer : 'a t -> 'a t -> unit
