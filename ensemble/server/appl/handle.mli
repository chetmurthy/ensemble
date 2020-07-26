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
(* HANDLE.MLI *)
(* Author: Mark Hayden, 10/97 *)
(**************************************************************)

val new_f : 'msg Appl_handle.New.full -> Appl_handle.handle_gen * 'msg Appl_intf.New.full

