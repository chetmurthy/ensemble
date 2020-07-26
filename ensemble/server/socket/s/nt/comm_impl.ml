(**************************************************************)
(*
 *  Ensemble, 2_00
 *  Copyright 2004 Cornell University, Hebrew University
 *           IBM Israel Science and Technology
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
(**************************************************************)
(* COMM_IMPL.ML *)
(* Authors: Robbert vanRenesse and Mark Hayden, 4/95 *)
(* Ohad Rodeh :                                       *)
(*         C-Memory mangement support          9/2001 *)
(*         Winsock2 support                   11/2001 *)
(**************************************************************)
let name = "SSOCKET"
let failwith s = failwith (name^":"^s)
(**************************************************************)
open Printf
open Socksupp

(**************************************************************)

external gettimeofday : timeval -> unit 
  = "skt_gettimeofday" "noalloc"

(**************************************************************)

external start_input : unit -> Unix.file_descr 
  = "skt_start_input"

(* See documentation in stdin.c.
 *)
let stdin =
  let stdin = ref None in
  fun () ->
    (*failwith "stdin not supported --- just for debugging";*)
    match !stdin with
      | None ->
	  let s = start_input () in
	  stdin := Some s ;
	  s
      | Some s -> s

(**************************************************************)

type sock_info = (socket array) * (bool array)
type socket_info = (socket array) * (bool array)
type select_info = socket_info * socket_info * socket_info * int

external select : select_info -> timeval -> int 
  = "skt_select" "noalloc"
external poll : select_info -> int 
  = "skt_poll" "noalloc"

(**************************************************************)

external substring_eq : string -> ofs -> string -> ofs -> len -> bool 
  = "skt_substring_eq" "noalloc"

(**************************************************************)

(* HACK!  It's useful to be able to print these out as ints.
 *)
external int_of_file_descr : Unix.file_descr -> int
  = "skt_int_of_file_descr"


let int_of_socket s =
  int_of_file_descr s

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
external socket_mcast : 
  Unix.socket_domain -> Unix.socket_type -> int -> Unix.file_descr
    = "skt_socket_mcast"

external socket : 
  Unix.socket_domain -> Unix.socket_type -> int -> Unix.file_descr
  = "skt_socket"

external connect : Unix.file_descr -> Unix.sockaddr -> unit
  = "skt_connect"

external bind : Unix.file_descr -> Unix.sockaddr -> unit
  = "skt_bind"

external close : Unix.file_descr -> unit
  = "skt_close"

external listen : Unix.file_descr -> int -> unit
  = "skt_listen"

external accept : Unix.file_descr -> Unix.file_descr * Unix.sockaddr 
  = "skt_accept"

(**************************************************************)
(* We are re-implementing recvfrom instead of using the Caml standard
 * library because we're using winsock2.
 *)
external recvfrom : socket -> buf -> ofs -> len -> len * Unix.sockaddr
  = "skt_recvfrom" 

(* On win32, read from the socket representing stdin.
 *)
external read : socket -> buf -> ofs -> len -> len 
  = "skt_recvfrom2" 

(**************************************************************)
type digest = string (* A 16-byte string *)
(**************************************************************)

(* Optimized socket operations.
 * - unsafe
 * - no exceptions
 * - "noalloc" is enabled
 * - socket, flags, and address are preprocessed
 * - no interrupts accepted
 * - no retransmission attempts on interrupts
 *)

(* Pre-processed information on a socket.
*)
type sendto_info

type ctx 

external create_ctx : unit -> ctx 
  = "skt_Val_create_ctx"

external sendto_info : 
  Unix.file_descr -> Unix.sockaddr array -> sendto_info
    = "skt_Val_create_sendto_info"

external udp_send : sendto_info -> buf -> ofs -> len -> unit
  = "skt_udp_send" "noalloc"

(* These two functions are used to send UDP packets. 
 * They add a header describing the size of the ML/Iovec size 
 * of the data. 
 * The format is: [ml_len] [usr_len] [ml header] [iovec data]
 * 
 * Corresponding code exists in udp_recv_packet. 
 *)
external udp_mu_sendsv : sendto_info -> buf -> ofs -> len -> Ciovec.t array -> unit
  = "skt_udp_mu_sendsv" "noalloc"

external udp_mu_recv_packet_into_str : socket -> string -> int
  = "skt_udp_mu_recv_packet_into_str" "noalloc"

type ret_len = {
  mutable ml_hdr_len : int;
  mutable iov_len : int
}

external udp_mu_recv_packet : socket -> ret_len -> string -> Ciovec.cbuf -> int -> unit
  = "skt_udp_mu_recv_packet" "noalloc"
    
let len_s = { ml_hdr_len = 0; iov_len = 0}

open Ciovec
let udp_mu_recv_packet pool sock ml_prealloc_buf= 
  if Ciovec.check_pre_alloc pool then (
  (* check that there is enough memory. If so, then use the end of the current 
   * chunk to receive data. 
   *)
    let chunk = some_of pool.Ciovec.chunk in 
    udp_mu_recv_packet 
      sock 
      len_s                 (* Return structure, saves an allocation *)
      ml_prealloc_buf       (* preallocated ML buffer *)
      chunk.Ciovec.cbuf     (* iovec *)
      pool.Ciovec.pos ; (* Where to start writing in the iovec *)
    let iov =
      if len_s.iov_len >|| 0 then 
        Ciovec.advance_and_sub_alloc pool
          (8 +|| len_s.ml_hdr_len +|| len_s.iov_len) 
          (8 +|| len_s.ml_hdr_len) len_s.iov_len
      else 
        Ciovec.empty
    in
    len_s.ml_hdr_len, iov
  ) else (
    (* Unoptimized path. 
     * 
     * There is no more iovec-space left, receive the message into an ML 
     * string, and then process it. Pass the message on only if is solely an 
     * ML-message. Do not accept any iovec data. 
     *)

    (* Increase the size of the recv pool, so there will be sufficient space 
    *)
    grow_pool (get_recv_pool ());

(*    print_string 
       "warning: Ensemble has run out of iovec memory, and is using the ML-heap\n";
    flush stdout;*)
    udp_mu_recv_packet_into_str sock ml_prealloc_buf, Ciovec.empty
  )

(**************************************************************)
(* Operations for sending messages through TCP.
 * 1) Exceptions are thrown
 * 2) nothing is allocated
 * 3) The length sent is returned
 *)
    
external tcp_send : socket -> buf -> ofs -> len -> len
  = "skt_tcp_send" "noalloc"

external tcp_sendv : socket -> Ciovec.t array -> len
  = "skt_tcp_sendv" "noalloc"

external tcp_sendsv : socket -> buf -> ofs -> len -> Ciovec.t array -> len
  = "skt_tcp_sendsv" "noalloc"

external tcp_sends2v : socket-> buf -> buf -> ofs -> len -> Ciovec.t array -> len
  = "skt_tcp_sends2v_bytecode" "skt_tcp_sends2v_native" "noalloc"

external tcp_recv : socket -> string -> ofs -> len -> len
  = "skt_tcp_recv" "noalloc"

external tcp_recv_iov : socket -> Ciovec.t -> ofs -> len -> len
  = "skt_tcp_recv_iov" "noalloc"

external tcp_recv_packet : socket -> string -> ofs -> len -> Ciovec.t -> len
  = "skt_tcp_recv_packet" "noalloc"

(**************************************************************)

external has_ip_multicast : unit -> bool 
  = "skt_has_ip_multicast" 
external in_multicast : Unix.inet_addr -> bool 
  = "skt_in_multicast" 
external setsockopt_ttl : socket -> int -> unit 
  = "skt_setsockopt_ttl" 
external setsockopt_loop : socket -> bool -> unit 
  = "skt_setsockopt_loop" 
external setsockopt_join : socket -> Unix.inet_addr -> mcast_send_recv -> unit 
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
external setsockopt_reuse : socket -> bool -> unit
  = "skt_setsockopt_reuse"
(**************************************************************)
external win_version : unit -> string = "win_version"

let os_type_and_version () = 
  let v = ref None in
  match !v with 
      Some x -> x
    | None -> 
	let ver = 
	  if is_unix then 
	    failwith "Sanity: using win32 socket library on a non-win32 platform"
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

