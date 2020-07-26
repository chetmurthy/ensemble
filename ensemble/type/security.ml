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
(* SECURITY *)
(* Author: Mark Hayden, 6/95 *)
(* Refinements: Ohad Rodeh 10/98 *)
(**************************************************************)
open Trans
open Buf
open Util
(**************************************************************)
let name = Trace.file "SECURITY"
let log = Trace.log name
let failwith = Trace.make_failwith name
(**************************************************************)

(* Type of keys in Ensemble.
 *)
type key = 
  | NoKey
  | Common of Buf.t

let buf_of_key = function
  | NoKey -> raise (Failure "Key=NoKey")
  | Common s -> s

let str_of_key k = Buf.to_string (buf_of_key k)
      
let string_of_key_short = function
  | NoKey -> "None"
  | Common key -> 
      let key = Buf.to_string key in
      let key = Digest.string key in
      let key = Util.hex_of_string key in
      let len = String.length key in
      let len = int_min 16 len in
      let key = String.sub key 0 len in
      sprintf "%s(sig)" key
      
let string_of_key = function
  | NoKey -> "{Key:None}"
  | Common key -> 
      let key = Buf.to_string key in
      let key = Digest.string key in
      let key = Util.hex_of_string key in
      sprintf "{Key:Shared:%s(sig)}" key

(*      
let sign key buf ofs len =
  let key = match key with
  | NoKey -> failwith "sign:NoKey"
  | Common s -> s
  in
  let ctx = Md5.init key in
  Md5.update ctx (Buf.break buf) (int_of_len ofs) (int_of_len len);
  let sign = Md5.final ctx in
  Buf.of_string sign

let sign_hack key buf ofs len dst ofs = 
  let key = match key with
  | NoKey -> failwith "sign:NoKey"
  | Common s -> s
  in
  let ctx = Md5.init key in
  Md5.update ctx (Buf.break buf) (int_of_len ofs) (int_of_len len);
  Md5.final_hack ctx (Buf.break dst) (int_of_len ofs)
*)

(* Make a short-lived nonce: e.g., t + 5 seconds
 *)
let make_nonce t = Time.add (Time.of_int 5) t

(**************************************************************)
