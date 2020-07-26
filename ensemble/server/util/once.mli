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
(* ONCE.MLI : set-once variables *)
(* Author: Mark Hayden, 12/96 *)
(**************************************************************)

type t

val create : string -> t

val set : t -> unit

val isset : t -> bool

val to_string : t -> string
