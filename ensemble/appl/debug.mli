(**************************************************************)
(*
 *  Ensemble, (Version 1.00)
 *  Copyright 2000 Cornell University
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
