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
(* SOCKSUPP.MLI *)
(* Author: Mark Hayden, 8/97 *)
(**************************************************************)

val is_unix : bool

val unit : 'a -> unit

val print_line : string -> unit

val max_header_len : int
