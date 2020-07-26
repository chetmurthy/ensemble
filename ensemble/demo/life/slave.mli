(**************************************************************)
(*
 *  Ensemble, 1.10
 *  Copyright 2001 Cornell University, Hebrew University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
(* This module contains the slave endpoint code *)
(* Version 0, by Sam Weber *)

open Ensemble
open Msgs

(* Initializes a slave endpoint. (Does not start a main loop) *)
(*   initSlave masterendpt time                                 *)
(* creates a slave which connects to master "masterendpt" and   *)
(* with with timer "time"                                     *)

val initSlave: Endpt.id -> Time.t -> Appl_intf.Old.t


