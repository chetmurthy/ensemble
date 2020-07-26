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
(* ONCE.MLI : set-once variables *)
(* Author: Mark Hayden, 12/96 *)
(**************************************************************)

type t

val create : string -> t

val set : t -> unit

val isset : t -> bool

val to_string : t -> string
