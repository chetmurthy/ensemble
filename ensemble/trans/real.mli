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
(* REAL.MLI *)
(* Author: Mark Hayden, 3/96 *)
(**************************************************************)

val export_socks : Hsys.socket Arrayf.t ref
val install_blocker : (Time.t -> unit) -> unit
