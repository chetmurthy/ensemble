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
(* APPL_DEBUG.MLI: debug application interface *)
(* Author: Mark Hayden, 11/97 *)
(**************************************************************)
open Trans

val f : debug -> 'msg Appl_intf.New.full -> 'msg Appl_intf.New.full
val view : debug -> 'msg Appl_intf.New.full -> 'msg Appl_intf.New.full

(**************************************************************)
