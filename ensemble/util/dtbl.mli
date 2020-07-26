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
(* DTBL.MLI *)
(* Author: Zhen Xiao, 2/98 *)
(**************************************************************)

val create : string -> int -> string -> Hsys.socket

val get_input : Hsys.socket -> unit -> unit

val leave : string -> Hsys.socket -> unit

val drop : string -> bool
