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
(* DEBUG.MLI *)
(* Author: Mark Hayden, 11/96 *)
(**************************************************************)
open Trans

val client : Alarm.t -> inet -> port -> unit
val server : Alarm.t -> port -> unit
