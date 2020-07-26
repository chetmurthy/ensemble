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
(* PARAM.MLI *)
(* Author: Mark Hayden, 12/96 *)
(**************************************************************)
open Trans
(**************************************************************)

(* The type of parameters.
 *)
type t =
  | String of string
  | Int of int
  | Bool of bool
  | Time of Time.t
  | Float of float

(* Parameter lists are (name,value) association lists.
 *)
type tl = (name * t) list

(* Add a parameter to the defaults.
 *)
val default : name -> t -> unit

(* Lookup a parameter in a param list.
 *)
val lookup : tl -> name -> t

(* Lookup a particular type of parameter.
 *)
val string : tl -> name -> string
val int : tl -> name -> int
val bool : tl -> name -> bool
val time : tl -> name -> Time.t
val float : tl -> name -> float

val to_string : (name * t) -> string

(* Print out default settings.
 *)
val print_defaults : unit -> unit
