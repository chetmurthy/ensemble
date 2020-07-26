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
(* DES.ML *)
(* Authors: Mark Hayden, Ohad Rodeh, 3/97 *)
(**************************************************************)
open Trans
open Util
open Shared
(**************************************************************)
let name = Trace.source_file "DES"
let failwith s = failwith (name^":"^s)
let log = Trace.log name ""
(**************************************************************)

type context = string
type key = string
type init = string

type src = string
type dst = string

external desml_context_length : unit -> int 
  = "desml_context_length"
external desml_CBCInit : string -> string -> string -> bool -> unit
  = "desml_CBCInit"
external desml_CBCUpdate : string -> string -> int -> string -> int -> int -> int 
  = "desml_CBCUpdate_bytecode" "desml_CBCUpdate_native"

let key_len = 8

let init key iv encrypt =
  if String.length key < 8 then failwith "init:key length < 8" ;
  if String.length iv < 8 then failwith "init:iv length < 8" ;
  let key = String.sub key 0 8 in
  let iv = String.sub iv 0 8 in
  let ctx_length = desml_context_length () in
  let ctx = String.create ctx_length in
  desml_CBCInit ctx key iv encrypt ;
  if encrypt then Encrypt ctx else Decrypt ctx

let check name buf ofs len =
  if ofs < 0 or len < 0 or ofs + len > String.length buf then
    invalid_arg ("DES:"^name^":bad string offsets")

let update ctx sbuf sofs dbuf dofs len =
  let ctx = match ctx with Encrypt c -> c | Decrypt c -> c in
  let sofs = int_of_len sofs in
  let dofs = int_of_len dofs in
  let len = int_of_len len in
  check name dbuf dofs len ;
  check name sbuf sofs len ;
  if (len mod 8) <> 0 then
    invalid_arg("DES:update:buffer length not mult of 8") ;
  let ret = desml_CBCUpdate ctx sbuf sofs dbuf dofs len in
  if ret <> 0 then
    failwith "update:error"

let final ctx =
  let ctx = match ctx with Encrypt c -> c | Decrypt c -> c in
  String.fill ctx 0 (String.length ctx) (Char.chr 0)

open Security

let _ =
  let key_ok key =
    match key with
    | Security.Common s -> 
	String.length s >= key_len
    | _ -> false
  in

  let init key encrypt =
    let key = Security.str_of_key key in
    let vi = String.make 8 (Char.chr 0) in
    init key vi encrypt
  in

  let update = update in

  let final = final in

  Shared.install key_ok init update final
