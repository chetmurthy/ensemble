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
(* PGP: interface to PGP *)
(* Authors: Zhen Xiao, Mark Hayden, 4/97 *)
(* Ohad: Added computation in the background  *)
(*       Fixed "pgp strange-character" syndrome *)
(*       Added support for different versions of PGP *)
(**************************************************************)
type principal   = string
type sender      = principal 
type receiver    = principal 
type cipher_text = Buf.t
type clear_text  = Buf.t

(* sign the clear_text with the sender's secret key and encrypt it
 * with receiver's public key into ASCII format. The sender's pass
 * phrase, "pass", is needed to sign the message.
 * 
 * This function uses temporary file "tin" to store "clear_text", 
 * and "tin.asc" to store the encrypted file. They would be overwritten
 * if already exist.
 *)

val encrypt : sender -> receiver -> clear_text -> cipher_text option
val bckgr_encrypt : sender -> receiver -> clear_text -> Alarm.t -> (cipher_text option -> unit) -> unit


(* decrypt the cipher_text with my secret key. My pass phrase, "pass"
 * is needed to decrypt the message. 
 *)

(* Open: Neither "sender" nor "receiver" is actually needed. First,
 * "sender" is not needed because it doesn't matter who sent the
 * cipher_text as long as decryption is concerned. Second, "receiver"
 * is not needed because the decryption is always done using the
 * user's pass phras.  
 * 
 * This function uses temporary file "tout.asc" to store "cipher_text",
 * and "tout" to store the decrypted file. They would be overwritten if 
 * already exist.
*)

val decrypt : sender -> receiver -> cipher_text -> clear_text option
val bckgr_encrypt : sender -> receiver -> cipher_text -> Alarm.t -> (clear_text option -> unit) -> unit 

