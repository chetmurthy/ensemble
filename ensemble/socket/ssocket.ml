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
(* SOCKET.ML *)
(* Authors: Robbert vanRenesse and Mark Hayden, 4/95 *)
(**************************************************************)
open Socksupp
(**************************************************************)

type buf = string
type ofs = int
type len = int

type 'a refcnt = { mutable count : int ; obj : 'a } 
type 'a iovec = { rbuf : 'a ; ofs : ofs ; len : len }

(**************************************************************)

let trace = 
  try 
    unit (Sys.getenv "SOCKET_TRACE") ;
    true 
  with Not_found -> 
    false

let debug_msg s = 
  if trace then (
    print_line ("SOCKET:trace:"^s)
  )

(**************************************************************)

let set_error_log = unit

(**************************************************************)

type timeval = {
  mutable sec10 : int ;
  mutable usec : int
} 

external gettimeofday : timeval -> unit 
  = "skt_gettimeofday" "noalloc"

(**************************************************************)

type socket = Unix.file_descr

(**************************************************************)

external start_input : unit -> Unix.file_descr 
  = "skt_start_input"

(* See documentation in stdin.c.
 *)
let stdin =
  let stdin = ref None in
  if is_unix then (
    fun () -> Unix.stdin 
  ) else (
    fun () ->
      match !stdin with
      | None ->
	  let s = start_input () in
	  stdin := Some s ;
	  s
      | Some s -> s
  )

(**************************************************************)

external heap : unit -> Obj.t array 
  = "skt_heap"
external addr_of_obj : Obj.t -> string 
  = "skt_addr_of_obj"
external minor_words : unit -> int 
  = "skt_minor_words" "noalloc"
external weak_check : 'a Weak.t -> int -> bool 
  = "skt_weak_check" "noalloc"
external frames : unit -> int array array 
  = "skt_frame_descriptors"

(**************************************************************)
(* READ: Depending on the system, call either read or recv.
 * This is only used for stdin (where on Nt it is a socket).
 *)
let read =
  if is_unix then 
    fun s b o l -> Unix.read s b o l
  else
    fun s b o l -> fst (Unix.recvfrom s b o l [])

(**************************************************************)

type sock_info = (socket array) * (bool array)
type socket_info = (socket array) * (bool array)
type select_info = socket_info * socket_info * socket_info * int

external select : select_info -> timeval -> int 
  = "skt_select" "noalloc"
external poll : select_info -> int 
  = "skt_poll" "noalloc"

(**************************************************************)

external static_string : len -> string 
  = "skt_static_string"
external static_string_free : string -> unit 
  = "skt_static_string_free"
external substring_eq : string -> ofs -> string -> ofs -> len -> bool 
  = "skt_substring_eq" "noalloc"

(**************************************************************)

(* HACK!  It's useful to be able to print these out as ints.
 *)
external int_of_file_descr : Unix.file_descr -> int
  = "skt_int_of_file_descr"

let int_of_socket s =
  int_of_file_descr s

(**************************************************************)
(* Optimized socket operations.
 * - unsafe
 * - no exceptions
 * - "noalloc" is enabled
 * - socket, flags, and address are preprocessed
 * - no interrupts accepted
 * - no retransmission attempts on interrupts
 *)

type sendto_info

external sendto_info : socket -> Unix.msg_flag list -> Unix.sockaddr array -> sendto_info
  = "skt_send_info"
external sendto : sendto_info -> buf -> ofs -> len -> unit
  = "skt_sendto" "noalloc"

(**************************************************************)

external sendv : sendto_info -> string refcnt iovec array -> int
  = "skt_sendv" "noalloc"
external sendtov : sendto_info -> string refcnt iovec array -> unit
  = "skt_sendtov" "noalloc"
external sendtosv : sendto_info -> string -> string refcnt iovec array -> unit
  = "skt_sendtosv" "noalloc"
external sendtovs : sendto_info -> string refcnt iovec array -> string -> unit
  = "skt_sendtovs" "noalloc"
external sendtosvs : sendto_info -> string -> string refcnt iovec array -> string -> unit
  = "skt_sendtosvs" "noalloc"

(**************************************************************)

type send_info = sendto_info

let send_info sock flag =
  sendto_info sock flag [||]

external sendp : send_info -> buf -> ofs -> len -> len
  = "skt_sendp" "noalloc"

(**************************************************************)

external has_ip_multicast : unit -> bool 
  = "skt_has_ip_multicast" 
external in_multicast : Unix.inet_addr -> bool 
  = "skt_in_multicast" 
external setsockopt_ttl : socket -> int -> unit 
  = "skt_setsockopt_ttl" 
external setsockopt_loop : socket -> bool -> unit 
  = "skt_setsockopt_loop" 
external setsockopt_join : socket -> Unix.inet_addr -> unit 
  = "skt_setsockopt_join" 
external setsockopt_leave : socket -> Unix.inet_addr -> unit 
  = "skt_setsockopt_leave" 
external setsockopt_sendbuf : socket -> int -> unit
  = "skt_setsockopt_sendbuf"
external setsockopt_recvbuf : socket -> int -> unit
  = "skt_setsockopt_recvbuf"
external setsockopt_nonblock : socket -> bool -> unit
  = "skt_setsockopt_nonblock"
external setsockopt_bsdcompat : socket -> bool -> unit
  = "skt_setsockopt_bsdcompat"

(**************************************************************)

type md5_ctx = string

external md5_ctx_length : unit -> int
  = "skt_md5_context_length" "noalloc"
external md5_init : md5_ctx -> unit
  = "skt_md5_init" "noalloc"
external md5_init_full : md5_ctx -> string -> unit
  = "skt_md5_init_full" "noalloc"
external md5_update : md5_ctx -> buf -> ofs -> len -> unit
  = "skt_md5_update" "noalloc"
external md5_final : md5_ctx -> Digest.t -> unit
  = "skt_md5_final" "noalloc"

let md5_init () =
  let ret = String.create (md5_ctx_length ()) in
  md5_init ret ;
  ret

let md5_init_full init_key =
  if String.length init_key <> 16 then 
    raise (Invalid_argument "md5_init_full: initial key value is not of length 16");
  let ret = String.create (md5_ctx_length ()) in
  md5_init_full ret init_key;
  ret


let md5_final ctx =
  let dig = String.create 16 in
  md5_final ctx dig ;
  dig

(*
let _ = 
  let x = "1234567812345678" in
  let msg = "abcdefghabcdefgh" in
  let ctx1 = md5_init_full x in
  md5_update ctx1 msg 0 16 ;
  let digest1 = md5_final ctx1 in

  let ctx2 = md5_init_full x in
  md5_update ctx2 msg 0 16 ;
  let digest2 = md5_final ctx2 in
  if digest2 <> digest1 then (
    print_string "Serious error in MD5\n";
  );
  exit 0
*)



(**************************************************************)
(* PUSH_INT/POP_INT: read and write 4-byte integers to
 * strings in network byte order 
 *)
(*
external push_nint : buf -> ofs -> int -> unit 
  = "skt_push_nint" "noalloc"
external pop_nint : buf -> ofs -> int
  = "skt_pop_nint" "noalloc"

(* INT_OF_SUBSTRING: read a 4-byte integer in host
 * byte order.
 *)
external int_of_substring : buf -> ofs -> int
  = "skt_int_of_substring" "noalloc"
*)
(**************************************************************)

type recv_info = socket

let recv_info s = s

external udp_recv : socket -> buf -> ofs -> len -> len 
  = "skt_udp_recv"
external recv : socket -> buf -> ofs -> len -> len 
  = "skt_recv"
external send : socket -> buf -> ofs -> len -> len 
  = "skt_send"

(**************************************************************)

let sihelp (socks,ret) =
  let max = ref 0 in
  Array.iter (fun sock ->
    let sock = int_of_socket sock in
    if sock > !max then max := sock
  ) socks ;
  ((socks,ret),!max)

let select_info a b c =
  let (a,am) = sihelp a in
  let (b,bm) = sihelp b in
  let (c,cm) = sihelp c in
  let max = succ (max am (max bm cm)) in
  (a,b,c,max)

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

external win_version : unit -> string = "win_version"

let os_type_and_version () = 
  let v = ref None in
  match !v with 
      Some x -> x
    | None -> 
	let ver = 
	  if is_unix then OS_Unix
	  else (
	    let version = 
	      match win_version () with
		  "NT3.5" -> Win_NT_3_5
		| "NT4.0" -> Win_NT_4
		| "2000" -> Win_2000
		| "95/98" -> Win_95_98
		| "3.11" -> Win_3_11
		| _ -> failwith "Sanity: win_version returned bad value"
	    in
	    OS_Win version
	  ) in
	v := Some ver;
	ver

(**************************************************************)
type eth = string

type eth_sendto_info

external eth_supported : unit -> bool
  = "ens_eth_supported"
external eth_init : string(*interface*) -> string(*address*) -> socket
  = "ens_eth_init"
external eth_sendto_info : socket -> string(*interface*) -> int(*flags*) -> eth(*src*) -> eth array(*dests*) -> eth_sendto_info
  = "ens_eth_sendto_info"
external eth_sendtovs : eth_sendto_info -> string refcnt iovec array -> string -> unit 
  = "ens_eth_sendtovs"
external eth_recv : socket -> buf -> ofs -> len -> len 
  = "ens_eth_recv"

let eth_to_bin_string = String.copy
let eth_of_bin_string = String.copy

let eth_init interface =
  let addr = String.create 6 in
  let sock = eth_init interface addr in
  (addr, sock)

(**************************************************************)

let _ = debug_msg "socket_done"

(**************************************************************)
