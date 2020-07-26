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
(* RC4.ML *)
(* Author: Ohad Rodeh, 11/97 *)
(**************************************************************)
open Util
open Shared
open Buf
(**************************************************************)
let name = Trace.file "RC4"
let failwith s = Trace.make_failwith name s
let log = Trace.log name
(**************************************************************)

external rc4ml_context_length : unit ->  len
  = "rc4ml_context_length"
external rc4ml_Init : Buf.t -> Buf.t -> ofs -> unit
  = "rc4ml_Init"
external rc4ml_Encrypt : Buf.t -> Buf.t -> ofs -> len -> unit
  = "rc4ml_Encrypt"

let ctx_length = rc4ml_context_length () 
let key_len = len8 (* Was 5 *)

let init key = 
  if Buf.length key <|| key_len then 
    failwith ("init:key length < "^(string_of_int (int_of_len key_len))) ;
  let key = Buf.sub name key len0 key_len in
  log (fun () -> sprintf "initializing key=%s" (Buf.to_string key)) ;
  let ctx = Buf.create ctx_length in
  rc4ml_Init ctx key key_len;
  ctx

let encrypt_inplace ctx buf ofs len =
  Buf.check name buf ofs len ;
  rc4ml_Encrypt ctx buf ofs len

let encrypt ctx buf ofs len =
  let res = Buf.sub name buf ofs len in
  encrypt_inplace ctx res len0 len;
  res

let _ =
  (* Ignore the Encrypt/Decrypt flag
   *)
  let init key encrypt =
    match key with
    | Security.NoKey -> failwith "Cannot initialize a NoKey"
    | Security.Common s -> 
	if Buf.length s <|| key_len then
	  failwith "Key is too short" ;
	match encrypt with
	| false -> Cipher.Decrypt (init s)
	| true -> Cipher.Encrypt (init s)
  in
  
  let encrypt ctx buf ofs len =
    let ctx = 
      match ctx with 
      | Cipher.Encrypt ctx -> ctx
      | Cipher.Decrypt ctx -> ctx
    in
    let res = encrypt ctx buf ofs len in
(*
    log (fun () -> sprintf "buf=%s, res=%s" (Buf.to_string buf) res);
*)
    res
      
  and encrypt_inplace ctx buf ofs len =
    let ctx = 
      match ctx with 
      | Cipher.Encrypt ctx -> ctx
      | Cipher.Decrypt ctx -> ctx
    in
(*
    log (fun () -> sprintf "encrypt_inplace buf=%s" buf);
*)
    encrypt_inplace ctx buf ofs len 

  in  
  log (fun () -> "Cipher.Install");
  Cipher.install "RC4" init encrypt encrypt_inplace



