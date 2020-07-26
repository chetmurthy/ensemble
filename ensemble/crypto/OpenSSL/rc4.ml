(**************************************************************)
(* RC4.ML *)
(* Author: Ohad Rodeh, 4/2000 *)
(**************************************************************)
open Ensemble
open Trans
open Util
open Shared
open Buf
(**************************************************************)
let name = Trace.file "RC4"
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
    
external rc4ml_context_length : unit -> int
  = "rc4ml_context_length"
    
external rc4ml_set_key : string -> len -> ctx -> unit
  = "rc4ml_set_key"
    
external rc4ml_encrypt : ctx -> src -> ofs -> dst -> ofs -> len -> unit 
  = "rc4ml_encrypt_bytecode" "rc4ml_encrypt_native" 
    
external rc4ml_encrypt_iov : ctx -> Iovec.raw -> unit
  = "rc4ml_encrypt_iov"


let key_len = 8
    
let init key encrypt = 
  if String.length key < key_len then 
    invalid_arg (sprintf "init:key length < %d" key_len);
  let key = String.sub key 0 key_len in
  let ctx_length = rc4ml_context_length () in
  let ctx = String.create ctx_length in
  rc4ml_set_key key 8 ctx;
  if encrypt then 
    Cipher.Encrypt (ctx, "")
  else 
    Cipher.Decrypt (ctx, "")

let check name buf ofs len =
  if ofs < 0 or len < 0 or ofs + len > String.length buf then
    invalid_arg ("RC4:"^name^":bad string offsets")
      
let update ctx_fl sbuf sofs dbuf dofs len =
  let sbuf = Buf.string_of sbuf
  and sofs = Buf.int_of_len sofs
  and dbuf = Buf.string_of dbuf
  and dofs = Buf.int_of_len dofs
  and len =  Buf.int_of_len len in
  check name dbuf dofs len ;
  check name sbuf sofs len ;
  if (len mod 8) <> 0 then
    invalid_arg(
      sprintf "RC4:update:buffer length not mult of 8 (len=%d)" len) ;
  let ctx = match ctx_fl with
    | Cipher.Encrypt (c,_) -> c
    | Cipher.Decrypt (c,_) -> c
  in

  let _ = rc4ml_encrypt ctx sbuf sofs dbuf dofs len in 
  ()

let update_iov ctx_fl iov = 
  let ctx = match ctx_fl with
    | Cipher.Encrypt (c,_) -> c
    | Cipher.Decrypt (c,_) -> c
  in
  log (fun () -> sprintf "encrypt_iov, len=%d" (int_of_len (Iovec.len iov)));
  rc4ml_encrypt_iov ctx (Iovec.raw_of iov);
  ()

open Security
    
let _ =
  let key_ok _ = true in
    
  let init cipher encrypt =
    let key = Security.buf_of_cipher cipher in
    let key = Buf.string_of key in
    init key encrypt
  in
  
  let update = update in

  let update_iov = update_iov in
  
  log (fun () -> "installing");
  Cipher.install "OpenSSL/RC4" key_ok init update update_iov
