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
(* APPL_DEBUG.MLI: debug application interface *)
(* Author: Mark Hayden, 11/97 *)
(**************************************************************)
open Trans

val f : debug -> 'msg Appl_intf.New.full -> 'msg Appl_intf.New.full
val view : debug -> 'msg Appl_intf.New.full -> 'msg Appl_intf.New.full

(**************************************************************)
