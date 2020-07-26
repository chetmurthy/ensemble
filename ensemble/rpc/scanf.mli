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
(* SCANF.MLI *)
(* Author: Robbert vanRenesse *)
(**************************************************************)
exception Parse_error
type value =
    Char of char
  | Int of int
  | Float of float
  | String of string
  | End of int
val iscanf : string -> int -> string -> value list
val sscanf : string -> string -> value list
(*
val print_result : value list -> unit
*)
