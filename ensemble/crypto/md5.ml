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
(* MD5.ML *)
(* Author: Ohad Rodeh, 11/97 *)
(**************************************************************)
open Shared

external md5ml_context_length : unit ->  int
  = "md5ml_context_length"
external md5ml_Init : string -> string -> unit
  = "md5ml_Init"
external md5ml_Update : string -> string -> int -> int -> unit
  = "md5ml_Update"
external md5ml_Final : string -> string -> unit 
  = "md5ml_Final"

type ctx = string 
type digest = string

let ctx_length = md5ml_context_length () 
let digest_length = 16

let create_ctx () = String.create ctx_length 

let init s = 
  let len = String.length s in
  if (len < 16) then 
    invalid_arg ("MD5: bad length of initialization string " ^ 
    (string_of_int len));
  let ctx = String.create ctx_length in
  md5ml_Init ctx s;
  ctx

(* This version takes a preallocated string
*)
let init_hack ctx s = md5ml_Init ctx s

let check name buf ofs len =
  if ofs < 0 or len < 0 or ofs + len > String.length buf then
    invalid_arg ("MD5:"^name^":bad string offsets")

let update ctx buf ofs len =
  check "" buf ofs len ;
  (* if (len mod 8) <> 0 then
    invalid_arg("MD5:update:buffer length not mult of 8") ; *)
  md5ml_Update ctx buf ofs len;
  ()

let final ctx =
  let digest = String.create digest_length in
  md5ml_Final digest ctx;
  digest

let final_hack ctx dst ofs= 
  md5ml_Final dst ctx;
  ()
  
let _ = 
  Sign.install "MD5" init init_hack update final final_hack
  
  
  
