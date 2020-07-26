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
(* IDEA.ML *)
(* Author: Ohad Rodeh, 4/2000 *)
(**************************************************************)
open Trans
open Util
open Shared
(**************************************************************)
let name = Trace.file "IDEA"
let failwith s = failwith (name^":"^s)
let log = Trace.log name 
(**************************************************************)
type context = Cipher.context
type iv = Cipher.iv
type ctx = Cipher.ctx

type ofs = int
type len = int
type src = string
type dst = string

external ideaml_context_length : unit -> int
  = "ideaml_context_length" 

external ideaml_iv_length : unit -> int
  = "ideaml_iv_length" 

external ideaml_set_encrypt_key : string -> ctx -> unit 
  = "ideaml_set_encrypt_key" 

external ideaml_set_decrypt_key : string -> ctx -> unit
  = "ideaml_set_decrypt_key" 

external ideaml_set_iv : iv -> unit
  = "ideaml_set_iv" 

external ideaml_cbc_encrypt : ctx -> iv -> src -> ofs -> dst -> ofs -> len -> bool -> unit 
  = "ideaml_cbc_encrypt_bytecode" "ideaml_cbc_encrypt_native" 


let key_len = 16

let init key encrypt = 
  let iv_length = ideaml_iv_length () in
  let iv = String.create iv_length in
  ideaml_set_iv iv;

  if String.length key < key_len then 
    invalid_arg (sprintf "init:key length < %d" key_len);
  let key = String.sub key 0 key_len in
  let ctx_length = ideaml_context_length () in
  let ctx = String.create ctx_length in
  if encrypt then (
    ideaml_set_encrypt_key key ctx;
    Cipher.Encrypt (ctx, iv)
  ) else (
    ideaml_set_decrypt_key key ctx;
    Cipher.Decrypt (ctx, iv)
  ) 

let check name buf ofs len =
  if ofs < 0 or len < 0 or ofs + len > String.length buf then
    invalid_arg ("IDEA:"^name^":bad string offsets")
      
let update ctx_fl sbuf sofs dbuf dofs len =
  let sbuf = Buf.break sbuf
  and sofs = Buf.int_of_len sofs
  and dbuf = Buf.break dbuf
  and dofs = Buf.int_of_len dofs
  and len =  Buf.int_of_len len in
  check name dbuf dofs len ;
  check name sbuf sofs len ;
  if (len mod 8) <> 0 then
    invalid_arg("IDEA:update:buffer length not mult of 8") ;
  let ctx,iv,encrypt = match ctx_fl with
  | Cipher.Encrypt (c,iv) -> c,iv,true
  | Cipher.Decrypt (c,iv) -> c,iv,false
  in

  let _ = ideaml_cbc_encrypt ctx iv sbuf sofs dbuf dofs len encrypt in 
  ()

open Security
    
let _ =
  let key_ok _ = true in
    
  let init cipher encrypt =
    let key = Security.buf_of_cipher cipher in
    let key = Buf.break key in
    init key encrypt
  in
  
  let update = update in
  
  Cipher.install "OpenSSL/IDEA" key_ok init update 
