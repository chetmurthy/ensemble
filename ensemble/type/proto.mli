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
(* PROTO.MLI *)
(* Author: Mark Hayden, 11/96 *)
(* see also appl/property.mli *)
(**************************************************************)
open Trans
(**************************************************************)

type id					(* stack *)
type l					(* layer *)

(**************************************************************)

val string_of_id : id -> string
val id_of_string : string -> id

(**************************************************************)

val layers_of_id : id -> l list
val string_of_l : l -> name
val l_of_string : name -> l

(**************************************************************)
