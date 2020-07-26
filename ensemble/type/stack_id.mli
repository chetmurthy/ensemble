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
(**************************************************************)
(* STACK_ID.MLI *)
(* Author: Mark Hayden, 3/96 *)
(**************************************************************)

type t =
  | Primary
  | Bypass
  | Gossip
  | Unreliable

val string_of_id : t -> string

val id_of_string : string -> t
