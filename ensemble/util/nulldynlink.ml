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
(* NULLDYNLINK.ML : no-op dynlink library for ocamlopt *)
(* Author: Mark Hayden, 12/98 *)
(**************************************************************)

let failwith s = 
  failwith ("NULLDYNLINK:no dynamic linker for ocamlopt:"^s)

let init _ = raise Not_found
let loadfile _ = failwith "loadfile"
let loadfile_private _ = failwith "loadfile_private"
let add_interfaces _ _ = failwith "add_interface"
let add_available_units _ = failwith "add_available_units"
let clear_available_units _ = failwith "clear_available_units"
let allow_unsafe_modules _ = failwith "allow_unsafe_modules"

type linking_error =
    Undefined_global of string
  | Unavailable_primitive of string
  | Uninitialized_global of string
type error =
    Not_a_bytecode_file of string
  | Inconsistent_import of string
  | Unavailable_unit of string
  | Unsafe_file
  | Linking_error of string * linking_error
  | Corrupted_interface of string
  | File_not_found of string

exception Error of error
  
let error_message _ = failwith "error_message"
let digest_interface _ = failwith "digest_interfaces"
