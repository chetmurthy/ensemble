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
(* APPL_DEBUG.MLI: debug application interface *)
(* Author: Mark Hayden, 11/97 *)
(**************************************************************)
open Trans

val f : debug -> 'msg Appl_intf.New.full -> 'msg Appl_intf.New.full
val view : debug -> 'msg Appl_intf.New.full -> 'msg Appl_intf.New.full

(**************************************************************)
