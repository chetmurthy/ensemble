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
(* GROUP.MLI *)
(* Author: Mark Hayden, 4/96 *)
(**************************************************************)

(* Type of group identifiers.
 *)
type id

(* Constructors.
 *)
val id    : Unique.id -> id		(* anonymous groups *)
val named : string -> id		(* named groups *)

(* Display function.
 *)
val string_of_id : id -> string

(* Hash an id (used for selecting IP multicast address).
 *)
val hash_of_id : id -> int

(**************************************************************)
