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
