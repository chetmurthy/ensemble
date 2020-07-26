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
