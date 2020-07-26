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
(* REFLECT.MLI: server side of gossip transport *)
(* Author: Mark Hayden, 8/95 *)
(**************************************************************)
open Trans

val init : Alarm.t -> View.full -> port -> bool -> (View.full * Appl_intf.New.t)

