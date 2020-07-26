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
(* USOCKET *)
(* Author: Mark Hayden, 4/97 *)
(**************************************************************)
let name = "USOCKET"
let failwith s = failwith (name^":"^s)
(**************************************************************)
open Printf
open Socksupp
(**************************************************************)

(* Handler defaults to nothing.
 *)
let error_log = ref (fun _ -> ())

let set_error_log f = error_log := f

let log f = !error_log f

(**************************************************************)

let linux_warning =
  let warned = ref false in
  fun () ->
    if not !warned then (
      warned := true ;
      print_line "USOCKET:warning:working around a Linux error" ;
      print_line "USOCKET:see ensemble/BUGS for more information" ;
    )

(**************************************************************)

(* Wrapper for system calls so that they will ignore a group
 * of errors that we don't care about.
 *)
let unix_wrap debug f =
  try f () with Unix.Unix_error(err,s1,s2) as exc ->
    match err with 
    | Unix.ECONNREFUSED 
    | Unix.ECONNRESET 
    | Unix.EHOSTDOWN			(* This was reported on SGI *)
    | Unix.ENOENT			(* This was reported on Solaris *)
    | Unix.ENETUNREACH
    | Unix.EHOSTUNREACH			(* FreeBSD *)
    | Unix.EPIPE 
    | Unix.EINTR			(* Should this be here? *)

    | Unix.EAGAIN -> 
	log (fun () -> "SOCKSUPP:warning:"^debug^":"^(Unix.error_message err)^":"^s1^":"^s2) ;
	0
    | _ ->
	print_line ("SOCKSUPP:"^debug^":"^(Unix.error_message err)) ;
	raise exc

(**************************************************************)

type socket = Unix.file_descr
type buf = string
type ofs = int
type len = int

type sendto_info = Unix.file_descr * Unix.msg_flag list * (Unix.sockaddr array)
type send_info = Unix.file_descr * Unix.msg_flag list

(**************************************************************)

let flatten il = 
  let n = Array.length il in
  let total = Pervasives.ref 0 in
  for i = 0 to pred n do
    let (_,_,len) = il.(i) in
    total := !total + len
  done ;

  let dbuf = String.create !total in
  let dofs = ref 0 in
  for i = 0 to pred n do
    let (buf,ofs,len) = il.(i) in
    String.blit buf ofs dbuf !dofs len ;
    dofs := !dofs + len
  done ;
  dbuf

(**************************************************************)
(* These are no-ops in the windows Unix library.
 *)

let setsockopt_nonblock s b =
  if b then 
    Unix.set_nonblock s 
  else 
    Unix.clear_nonblock s

(**************************************************************)

let send s b o l = Unix.send s b o l []
let recv s b o l = Unix.recv s b o l []
let stdin () = Unix.stdin
let socket_of_fd s = s
let read = Unix.read
let static_string = String.create
let static_string_free _ = ()
let sendto_info s f a = (s,f,a)
let send_info s f = (s,f)
let has_ip_multicast () = false
let in_multicast _ = failwith "in_multicast"
let setsockopt_ttl _ _ = failwith "setsockopt_multicast"
let setsockopt_loop _ _ = failwith "setsockopt_loop"
let setsockopt_join _ _ = failwith "setsockopt_join"
let setsockopt_leave _ _ = failwith "setsockopt_leave"
let setsockopt_sendbuf _ _ = failwith "setsockopt_sendbuf"
let setsockopt_recvbuf _ _ = failwith "setsockopt_recvbuf"
let setsockopt_bsdcompat _ _ = failwith "setsockopt_bsdcompat"
external int_of_file_descr : Unix.file_descr -> int = "%identity"
let int_of_socket = int_of_file_descr
let fd_of_socket s = s
let socket_of_fd s = s

(**************************************************************)

type timeval = {
  mutable sec10 : int ;
  mutable usec : int
} 

let gettimeofday tv =
  let time = Unix.gettimeofday () in
  let usec,sec10 = modf (time /. 10.) in
  let usec = usec *. 1.0E7 in
  tv.sec10 <- truncate sec10 ;
  tv.usec <- truncate usec ;
  if tv.usec < 0 || tv.usec >= 10000000 then
    failwith "gettimeofday:bad usec value"

(**************************************************************)
(* From util.ml *)
let word_len = 4
let mask1 = pred word_len
let mask2 = lnot mask1
let ceil_word i = (i + mask1) land mask2
(**************************************************************)

type recv_info = Unix.file_descr
let recv_info s = s

let udp_recv s b o l = 
  unix_wrap "udp_recv" (fun () ->
    let ret = Unix.recv s b o l [] in
    if ret >= l then (
      eprintf "USOCKET:udp_recv:warning:got packet that is maximum size (probably truncated), dropping (len=%d)\n" ret ;
      flush stderr ;
      0
    ) else if ret <> ceil_word ret then (
      eprintf "USOCKET:udp_recv:warning:got packet that is not 4-byte aligned, dropping (len=%d)\n" ret ;
      flush stderr ;
      0
    ) else ret
  )

let eth_recv s b o l = 
  unix_wrap "eth_recv" (fun () ->
    let ret = Unix.recv s b (o+2) l [] in
    if ret >= l then (
      eprintf "USOCKET:udp_recv:warning:got packet that is maximum size (probably truncated), dropping (len=%d)\n" ret ;
      flush stderr ;
      0
    ) else if ret + 2 <> ceil_word ret then (
      eprintf "USOCKET:udp_recv:warning:got packet that is not 4-byte aligned, dropping (len=%d)\n" ret ;
      flush stderr ;
      0
    ) else ret + 2
  )

(**************************************************************)

(* These functions are modified to repeat calls that return
 * ECONNREFUSED.  See ensemble/BUGS for more information.
 *)

let sendto (s,f,a) b o l = 
  for i = 0 to pred (Array.length a) do
    try
      unit (Unix.sendto s b o l f a.(i))
    with e ->
      match e with 
      | Unix.Unix_error(Unix.ECONNREFUSED,_,_) ->
	  linux_warning () ;
	  unit (unix_wrap "sendto(2nd)" (fun () -> Unix.sendto s b o l f a.(i)))
      | _ -> 
	  unit (unix_wrap "sendto(1st)" (fun () -> raise e))
  done

(**************************************************************)

let sendp (s,f) buf ofs len = Unix.send s buf ofs len f

(**************************************************************)

type 'a refcnt = { mutable count : int ; obj : 'a } 
type 'a iovec = { rbuf : 'a ; ofs : ofs ; len : len }

let mapper {rbuf={obj=obj};ofs=ofs;len=len} = (obj,ofs,len)

let wrap_string s = [|(s,0,(String.length s))|]

let sendv info iov = 
  let iov = Array.map mapper iov in
  let s = flatten iov in
  sendp info s 0 (String.length s)

let internal_sendtov info iov = 
  let s = flatten iov in
  sendto info s 0 (String.length s)

let sendtosv info s iov =
  let iov = Array.map mapper iov in
  let iov = Array.append (wrap_string s) iov in
  internal_sendtov info iov

let sendtovs info iov s =
  let iov = Array.map mapper iov in
  let iov = Array.append iov (wrap_string s) in
  internal_sendtov info iov

let sendtov info iov =
  let iov = Array.map mapper iov in
  internal_sendtov info iov

(**************************************************************)

let rec substring_eq_help s1 o1 s2 o2 l i =
  if i >= l then true 
  else if s1.[i+o1] = s2.[i+o2] then
    substring_eq_help s1 o1 s2 o2 l (succ i)
  else false

let substring_eq s1 o1 s2 o2 l =
  let l1 = String.length s1 in
  let l2 = String.length s2 in
  if l < 0 then failwith "substring_eq:negative length" ;
  if o1 < 0 || o2 < 0 || o1 + l > l1 || o2 + l > l2 then
    failwith "substring_eq:range out-of-bounds" ;
  substring_eq_help s1 o1 s2 o2 l 0

(**************************************************************)

type sock_info = (Unix.file_descr array) * (bool array)
type fd_info = sock_info * (Unix.file_descr list)
type select_info = fd_info * fd_info * fd_info

let sihelp (socks,ret) =
  ((socks,ret),(Array.to_list socks))

let select_info a b c = 
  let a = sihelp a in
  let b = sihelp b in
  let c = sihelp c in
  (a,b,c)

let select_help (socks,ret) out =
  for i = 0 to pred (Array.length socks) do
    (* We use memq here so that on Nt the equality will
     * not fail when in hits the Abstract tag.
     *)
    ret.(i) <- List.memq socks.(i) out
  done

let select (a,b,c) timeout =
  let timeout =
    ((float timeout.sec10) *. 10.) +. ((float timeout.usec) /. 1.0E6)
  in
  let a',b',c' =
    let rec loop a b c d =
      try Unix.select a b c d with
      | Unix.Unix_error(Unix.EINTR,_,_) -> 
	  eprintf "USOCKET:select:ignoring EINTR error\n" ;
	  loop a b c d
      | Unix.Unix_error(err,s1,s2) ->
      	  eprintf "USOCKET:select:%s\n" (Unix.error_message err) ;
          failwith "error calling select"
    in loop (snd a) (snd b) (snd c) timeout 
  in
  select_help (fst a) a' ;
  select_help (fst b) b' ;
  select_help (fst c) c' ;
  List.length a' + List.length b' + List.length c'

let time_zero = {sec10=0;usec=0}
let poll si = select si time_zero

(**************************************************************)

let weak_check w i =
  match Weak.get w i with
  | Some _ -> true
  | None -> false

(**************************************************************)

type md5_ctx = string list ref

let md5_init () = ref []

let md5_init_full init_key = ref [init_key]

let md5_update ctx buf ofs len =
  ctx := (String.sub buf ofs len) :: !ctx
(*
let hex_of_string s =
  let n = String.length s in
  let h = String.create (2 * n) in
  for i = 0 to pred n do
    let c = s.[i] in
    let c = Char.code c in
    let c = sprintf "%02X" c in
    String.blit c 0 h (2 * i) 2
  done ;
  h
*)
let md5_final ctx =
  let ctx = List.rev !ctx in
  let s = String.concat "" ctx in
(*
  eprintf "MD5_FINAL:%s\n" (hex_of_string s) ;
  eprintf "MD5_FINAL:%d\n" (String.length s) ;
*)
  Digest.string s

(**************************************************************)
(* These are not supported at all.
 *)

let terminate_process _ = failwith "terminate_proces"
let heap _ = failwith "heap"
let frames _ = failwith "frames"
let addr_of_obj _ = failwith "addr_of_obj"
let minor_words () = (-1)


(**************************************************************)
type win = 
    Win_3_11
  | Win_95_98
  | Win_NT_3_5
  | Win_NT_4
  | Win_2000

type os_t_v = 
    OS_Unix
  | OS_Win of win

let os_type_and_version () = 
  failwith "fcuntion os_type_and_version not supported (under usocket). You need the optimzed socket library."
(**************************************************************)

type eth
type eth_sendto_info
let eth_supported () = false
let eth_init _ = failwith "eth_init"
let eth_sendto_info _ _ _ = failwith "eth_sendto_info"
let eth_sendtovs _ = failwith "eth_sendtovs"
let eth_to_bin_string _ = failwith "eth_to_bin_string"
let eth_of_bin_string _ = failwith "eth_of_bin_string"

(**************************************************************)
