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
(* IDEA.ML *)
(* Author: Ohad Rodeh, 11/97 *)
(**************************************************************)
open Trans
open Util
open Shared
(**************************************************************)
let name = Trace.source_file "IDEA"
let failwith s = failwith (name^":"^s)
let log = Trace.log name ""
(**************************************************************)
(*
 * There is a compatibility problem between DES and IDEA. In 
 * IDEA the encrypt/decrypt choice is performed in the update
 * function. In DES, when a key is created. 
*)

type src = string
type dst = string

external ideaml_context_length : unit -> int 
  = "ideaml_context_length"
external ideaml_CfbInit : string -> string -> unit
  = "ideaml_CfbInit"
external ideaml_CfbUpdate : string -> string -> int -> string -> int -> int -> bool -> unit
  = "ideaml_CfbUpdate_bytecode" "ideaml_CfbUpdate_native"

let key_len = 16

let init key encrypt = 
  if String.length key < key_len then 
    failwith (sprintf "init:key length < %d" key_len);
  let key = String.sub key 0 key_len in
  let ctx_length = ideaml_context_length () in
  let ctx = String.create ctx_length in
  ideaml_CfbInit ctx key ;
  if encrypt then
    Encrypt ctx
  else 
    Decrypt ctx

let check name buf ofs len =
  if ofs < 0 or len < 0 or ofs + len > String.length buf then
    invalid_arg ("IDEA:"^name^":bad string offsets")

let update ctx sbuf sofs dbuf dofs len =
  check name dbuf dofs len ;
  check name sbuf sofs len ;
  if (len mod 8) <> 0 then
    invalid_arg("IDEA:update:buffer length not mult of 8") ;
  let ctx,encrypt = match ctx with
  | Encrypt c -> c,true
  | Decrypt c -> c,false
  in

  let _ = ideaml_CfbUpdate ctx sbuf sofs dbuf dofs len encrypt in 
  ()

(*
let updateE ctx sbuf sofs dbuf dofs len =
  update ctx sbuf sofs dbuf dofs len true

let updateD ctx sbuf sofs dbuf dofs len =
  update ctx sbuf sofs dbuf dofs len false
*)

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
    init key encrypt
  in

  let update = update in

  let final = final in

  Shared.install key_ok init update final
