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
(* TIMESTAMP.MLI *)
(* Author: Mark Hayden, 4/97 *)
(**************************************************************)

type t

val register : Trans.debug -> t

val add : t -> unit

val print : unit -> unit

