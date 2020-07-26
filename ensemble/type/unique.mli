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
(* UNIQUE.MLI *)
(* Author: Mark Hayden, 8/96 *)
(**************************************************************)
open Trans

(* Id generator.
 *)
type t

(* Unique identifiers.
 *)
type id

(* Constructors.
 *)
val create : inet -> incarn -> t
val id : t -> id

(* Display functions.
 *)
val string_of_id : id -> string
val string_of_id_short : id -> string
val string_of_id_very_short : id -> string

(* Hash an id.
 *)
val hash_of_id : id -> int

(**************************************************************)
val set_port : t -> port -> unit
(**************************************************************)
