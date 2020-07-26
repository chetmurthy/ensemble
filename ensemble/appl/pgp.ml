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
open Util
(**************************************************************)
let name = Trace.file "PGP"
let failwith s = Trace.make_failwith name s
let log = Trace.log name
let log1 = Trace.log (name^"1")
let log2 = Trace.log (name^"2")
(**************************************************************)
(* General Support for background computation. Should be somewhere
 * else.
 *)

(* Things are lazy here so as not to disturb the non-secure stack with
 * computation of environment variables that may not be set.
*)

let home = 
  try Unix.getenv "HOME" 
  with Not_found -> failwith "Environment variable HOME does not exist"

let path = 
  try Unix.getenv "PATH" 
  with Not_found -> failwith "Environment variable PATH does not exist"

let pgppass =  lazy (Arge.check name Arge.pgp_pass)
let version = ref (*"5.0"*) "2.6"

type comm = 
  | Error of string
  | Reply of string
      
      
let env_array = lazy (
  let pgppass = Lazy.force pgppass in
  [|"PGPPASS="^pgppass;("HOME="^home);("PATH="^path)|]  
)

let decrypt_cmd sender receiver = 
  match !version with 
    | "2.6" -> "pgp -f " ^ receiver ^" -u "^ sender 
    | "5.0" -> "pgpv -f +batch" 
    | _ -> failwith "non-supported PGP version"

let encrypt_cmd sender receiver =
  match !version with 
    | "2.6" -> "pgp -feas +batch "^receiver^" -u "^ sender 
    | "5.0" -> "pgpe -fast +batchmode=1 -r "^receiver^" -u "^ sender 
    | _ -> failwith "non-supported PGP version"


let read_sock debug alarm sock f =
  log2 (fun () -> "read_sock");
  let l = ref [] in
  let read () =
    let buf = String.create 10000 in
    try 
      let len = Hsys.read sock buf 0 (String.length buf) in
      log2 (fun () -> sprintf "%s:len=%d" debug len);
      if len = 0 then (
	Alarm.rmv_sock_recv alarm sock ;
	Hsys.close sock ;
	f (String.concat "" (List.rev !l))
      ) ;
      l := (String.sub buf 0 len) :: !l
    with End_of_file -> 
      f (String.concat "" (List.rev !l))
  in
  Alarm.add_sock_recv alarm name sock (Hsys.Handler0 read)

let select_process alarm notify cmd input =
  log2 (fun () -> sprintf "%s %s" cmd input);
  let (pid,in_read,err_read) = Hsys.background_process cmd (Lazy.force env_array) input in
  let counter = ref 0 in
  let kill_proc () = 
    incr counter;
    if !counter = 2 then ignore (Unix.waitpid [] pid);
  in    
  read_sock "get_error" alarm  err_read (fun s -> 
    kill_proc ();
    log2 (fun () -> "get_error");
    notify (Error s) ;
  ) ;
  read_sock "get_reply" alarm in_read (fun s -> 
    kill_proc ();
    log2 (fun () -> "get_reply");
    notify (Reply s)
  )

(**************************************************************)
type principal   = string
type sender      = principal 
type receiver    = principal 
type cipher_text = Buf.t
type clear_text  = Buf.t

let flatten_error s =
  string_map (fun c ->
    if c = '\n' then '|' else c
  ) s

(* sign the clear_text with the sender's secret key and encrypt it
 * with receiver's public key into ASCII format. The sender's pass
 * phrase, "pass", is needed to sign the message.
 * 
 *)
let encrypt sender receiver clear_text = 
  let clear_text = Buf.to_string clear_text in
  let clear_text = (hex_of_string clear_text) in 
  let command = encrypt_cmd sender receiver in
  log1 (fun () -> command);
  let (exit0,cipher,error) = Hsys.open_process command (Lazy.force env_array) clear_text in
  if exit0 then (
    log (fun () -> "encrypt succeeded") ;
    Some(Buf.pad_string cipher)
  ) else (
    log (fun () -> sprintf "encrypt failed") ;
    log (fun () -> sprintf "pgp info=%s" (flatten_error error)) ;
    None
  )


(* The same -- in the background
 *)
let bckgr_encrypt sender receiver clear_text alarm rep_fun =
  let clear_text = Buf.to_string clear_text in
  let clear_text = (hex_of_string clear_text) in 
  let command = encrypt_cmd sender receiver in
  log1 (fun () -> command);
  select_process alarm (function
    | Error e -> 
	log2 (fun () -> sprintf "PGP Error = <%s>" (flatten_error e))
    | Reply cipher -> 
	if cipher="" then (
	  log (fun () -> "[bckground] encrypt failed") ;
	  rep_fun None
	) else (
	  log (fun () -> "[background] encrypt succeded");
	  rep_fun (Some(Buf.pad_string cipher))
	)
  ) command clear_text
  

(* decrypt the cipher_text with my secret key. My pass phrase, "pass"
 * is needed to decrypt the message. 
 *)

(* Open: Neither "sender" nor "receiver" is actually needed. First,
 * "sender" is not needed because it doesn't matter who sent the
 * cipher_text as long as decryption is concerned. Second, "receiver"
 * is not needed because the decryption is always done using the
 * user's pass phrase.  
*)

let decrypt sender receiver cipher_text = 
  let cipher_text = Buf.to_string cipher_text in
  let command = decrypt_cmd sender receiver in
  log1 (fun () -> command);
  let (exit0,clear,error) = Hsys.open_process command (Lazy.force env_array) cipher_text in
  if exit0 then (
    log (fun () -> "decrypt succeeded") ;
    let clear = hex_to_string clear in
    Some(Buf.pad_string clear)
  ) else (
    log (fun () -> "decrypt failed") ;
    log (fun () -> sprintf "pgp info=%s" (flatten_error error)) ;
    None
  )


(* The same -- in the background
 *)
let bckgr_decrypt sender receiver cipher_text alarm rep_fun =
  let cipher_text = Buf.to_string cipher_text in
  let command = decrypt_cmd sender receiver in
  log1 (fun () -> command);
  select_process alarm (function
    | Error e -> 
	log2 (fun () -> sprintf "PGP Error = <%s>" (flatten_error e))
    | Reply clear -> 
	if clear="" then (
	  log (fun () -> "[bckground] decrypt failed") ;
	  rep_fun None
	) else (
	  log (fun () -> "[background] decrypt succeded");
	  log1 (fun () -> sprintf "before hex_to_String %s" clear);
	  let clear = hex_to_string clear in
	  rep_fun (Some(Buf.pad_string clear))
	)
  ) command cipher_text


let _ =
  let princ id nm =
    if id <> Addr.Pgp then 
      failwith sanity ;
    Addr.PgpA(nm)
  in

  let seal id src dst clear =
    let src = Addr.project src id in
    let dst = Addr.project dst id in
    match src,dst with
    | Addr.PgpA(src),Addr.PgpA(dst) ->
	encrypt src dst clear
    | _,_ -> None
  in

  let bckgr_seal id src dst clear alarm rep_fun = 
    let src = Addr.project src id in
    let dst = Addr.project dst id in
    match src,dst with
    | Addr.PgpA(src),Addr.PgpA(dst) ->
	bckgr_encrypt src dst clear alarm rep_fun 
    | _,_ -> rep_fun None
  in

  let unseal id src dst cipher =
    let src = Addr.project src id in
    let dst = Addr.project dst id in
    match src,dst with
    | Addr.PgpA(src),Addr.PgpA(dst) ->
	decrypt src dst cipher
    | _,_ -> None
  in

  let bckgr_unseal id src dst cipher alarm rep_fun = 
    let src = Addr.project src id in
    let dst = Addr.project dst id in
    match src,dst with
    | Addr.PgpA(src),Addr.PgpA(dst) ->
	bckgr_decrypt src dst cipher alarm rep_fun 
    | _,_ -> rep_fun None
  in

  let auth =
    Auth.create
      name
      princ
      seal
      bckgr_seal
      unseal
      bckgr_unseal
  in
  
  Auth.install Addr.Pgp auth

(**************************************************************)
