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
(* DES.MLI *)
(* Authors: Mark Hayden, Ohad Rodeh, 3/97 *)
(**************************************************************)
open Trans
(**************************************************************)
(*
type context
type init
type key = string

type src = string
type dst = string

val key_len : int
val init : key -> init -> bool -> context
val update : context -> src -> ofs -> dst -> ofs -> len -> unit
val final : context -> unit
*)
