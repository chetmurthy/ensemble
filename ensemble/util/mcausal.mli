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
(* MCAUSAL.MLI : Causal ordering support module. *)
(* Author: Ohad Rodeh, 7/97 *)
(**************************************************************)
open Trans

type t
type s

val create_state : int -> t
val last_of      : t -> seqno array
val can_deliver  : t -> s -> seqno -> bool
val incr         : t -> seqno -> s
val update       : t -> s -> seqno -> unit



