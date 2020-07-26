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
(* REAL.MLI *)
(* Author: Mark Hayden, 3/96 *)
(**************************************************************)

val export_socks : Hsys.socket Arrayf.t ref
val install_blocker : (Time.t -> unit) -> unit
