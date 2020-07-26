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
(* TIMESTAMP.MLI *)
(* Author: Mark Hayden, 4/97 *)
(**************************************************************)

type t

val register : Trans.debug -> t

val add : t -> unit

val print : unit -> unit

