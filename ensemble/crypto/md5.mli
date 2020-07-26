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
(* MD5.MLI *)
(* Author: Ohad Rodeh, 11/97 *)
(**************************************************************)
(*
open Trans
open Util
open Shared
*)
(**************************************************************)
(*
let name = Trace.source_file "MD5"
let failwith s = failwith (name^":"^s)
let log = Trace.log name ""
*)
(**************************************************************)
type ctx
type digest = string

val create_ctx : unit -> ctx

(* The hack versions take a preallocated string 
*)
val init : string -> ctx
val init_hack : ctx -> string -> unit

val update : ctx -> string -> int -> int -> unit
val final : ctx -> digest
val final_hack : ctx -> string -> int -> unit



