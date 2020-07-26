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
(*
type socket = Wrap of Unix.file_descr	(* Not exported *)
let socket_of_fd x = Wrap x
let fd_of_socket (Wrap x) = x
*)

type socket
external socket_of_fd : Unix.file_descr -> socket 
  = "skt_socket_of_fd"
external fd_of_socket : socket -> Unix.file_descr 
  = "skt_fd_of_socket"

(**************************************************************)

external start_input : unit -> Unix.file_descr 
  = "skt_start_input"

(* See documentation in stdin.c.
 *)
let stdin =
  let stdin = ref None in
  if is_unix then (
    fun () -> socket_of_fd Unix.stdin 
  ) else (
    fun () ->
      match !stdin with
      | None ->
	  let s = socket_of_fd (start_input ()) in
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
    fun s b o l -> Unix.read (fd_of_socket s) b o l
  else
    fun s b o l -> fst (Unix.recvfrom (fd_of_socket s) b o l [])

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
  let fd = fd_of_socket s in
  int_of_file_descr fd

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
external setsock_multicast : socket -> bool -> unit 
  = "skt_setsock_multicast" 
external setsock_join : socket -> Unix.inet_addr -> unit 
  = "skt_setsock_join" 
external setsock_leave : socket -> Unix.inet_addr -> unit 
  = "skt_setsock_leave" 
external setsock_sendbuf : socket -> int -> unit
  = "skt_setsock_sendbuf"
external setsock_recvbuf : socket -> int -> unit
  = "skt_setsock_recvbuf"
external setsock_nonblock : socket -> bool -> unit
  = "skt_setsock_nonblock"
external setsock_bsdcompat : socket -> bool -> unit
  = "skt_setsock_bsdcompat"

(**************************************************************)

type md5_ctx = string

external md5_ctx_length : unit -> int
  = "skt_md5_context_length" "noalloc"
external md5_init : md5_ctx -> unit
  = "skt_md5_init" "noalloc"
external md5_update : md5_ctx -> buf -> ofs -> len -> unit
  = "skt_md5_update" "noalloc"
external md5_final : md5_ctx -> Digest.t -> unit
  = "skt_md5_final" "noalloc"

let md5_init () =
  let ret = String.create (md5_ctx_length ()) in
  md5_init ret ;
  ret

let md5_final ctx =
  let dig = String.create 16 in
  md5_final ctx dig ;
  dig

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

type process_handle

let process_socket () =
  let fd = Unix.socket Unix.PF_INET Unix.SOCK_DGRAM 0 in
  let sock = socket_of_fd fd in
  let host = Unix.gethostname() in
  let addr =  
     try
        let h = Unix.gethostbyname host in
           h.Unix.h_addr_list.(0)
     with
        Not_found ->
           print_line ("SOCKET: host "^host^" not found: defaulting to localhost") ;
           Unix.inet_addr_of_string "127.0.0.1"
  in
  Unix.bind fd (Unix.ADDR_INET(addr, 0));
  sock

external spawn_process : string -> string array -> socket option -> process_handle option
  = "skt_spawn_process"

external wait_process : socket -> (process_handle * Unix.process_status)
  = "skt_wait_process"

external terminate_process : process_handle -> unit
  = "skt_terminate_process"

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
