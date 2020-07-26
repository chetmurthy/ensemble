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
(* DTBL.MLI *)
(* Author: Zhen Xiao, 2/98 *)
(**************************************************************)

val create : string -> int -> string -> Hsys.socket

val get_input : Hsys.socket -> unit -> unit

val leave : string -> Hsys.socket -> unit

val drop : string -> bool
