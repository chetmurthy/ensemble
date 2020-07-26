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
(* DTBL.MLI *)
(* Author: Zhen Xiao, 3/98 *)
(**************************************************************)

val init : string (* my_name *) -> string (* fname *) -> unit

val cut : string -> bool

val drop_rate : string -> float

val delay : string -> float
