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
