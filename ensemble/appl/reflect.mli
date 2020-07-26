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
(* REFLECT.MLI: server side of gossip transport *)
(* Author: Mark Hayden, 8/95 *)
(**************************************************************)
open Trans

val init : Alarm.t -> View.full -> port -> bool -> (View.full * Appl_intf.New.t)

