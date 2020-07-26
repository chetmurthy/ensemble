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
(* SOCKET.ML *)
(* Authors: Robbert vanRenesse and Mark Hayden, 4/95 *)
(**************************************************************)
let name = "SSOCKET"
let failwith s = failwith (name^":"^s)
(**************************************************************)
open Printf
open Socksupp
(**************************************************************)

type buf = string
type ofs = int
type len = int
type socket = Unix.file_descr
type timeval = Socksupp.timeval = {
  mutable sec10 : int ;
  mutable usec : int
} 

type win = Socksupp.win = 
    Win_3_11
  | Win_95_98
  | Win_NT_3_5
  | Win_NT_4
  | Win_2000

type os_t_v = Socksupp.os_t_v = 
    OS_Unix
  | OS_Win of win

exception Out_of_iovec_memory = Socksupp.Out_of_iovec_memory

let max_msg_size = Socksupp.max_msg_size
let is_unix = Socksupp.is_unix
(**************************************************************)

(* Debugging
*)
let verbose = ref false

let set_verbose flag =
  printf "Socket verbose\n"; Pervasives.flush Pervasives.stdout;
  verbose := flag

let is_unix = Socksupp.is_unix

(**************************************************************)
(* Include the native iovector support code
 *)
module Iov = Ciovec
open Iov

type mcast_send_recv = Socksupp.mcast_send_recv = 
  | Recv_only
  | Send_only
  | Both

(* Include common code for all platforms
 *)
let heap = Common_impl.heap
let addr_of_obj = Common_impl.addr_of_obj
let minor_words = Common_impl.minor_words
let frames = Common_impl.frames
  
(* MD5 hash functions. We need to have it work on Iovecs as
 * well as regular strings. 
 *)
type md5_ctx = Common_impl.md5_ctx
    
let md5_init = Common_impl.md5_init
let md5_init_full = Common_impl.md5_init_full
let md5_final = Common_impl.md5_final
let md5_update_iov = Common_impl.md5_update_iov
let md5_update = Common_impl.md5_update
  
  
(* Including platform dependent stuff
 *)
let gettimeofday = Comm_impl.gettimeofday
  
let socket_mcast = Comm_impl.socket_mcast
let socket = Comm_impl.socket
let connect = Comm_impl.connect
let bind = Comm_impl.bind 
let close = Comm_impl.close 
let listen = Comm_impl.listen 
let accept = Comm_impl.accept 
  
let stdin = Comm_impl.stdin
let read  = Comm_impl.read 
  
let int_of_socket = Comm_impl.int_of_socket
  
type sock_info = Comm_impl.sock_info
type select_info = Comm_impl.select_info
    
let select_info = Comm_impl.select_info
let select  = Comm_impl.select 
let poll  = Comm_impl.poll 
  
let substring_eq  = Comm_impl.substring_eq
  
let recvfrom  = Comm_impl.recvfrom 

type sendto_info = Comm_impl.sendto_info
let sendto_info  = Comm_impl.sendto_info 
  
let udp_send = Comm_impl.udp_send
let udp_mu_sendsv = Comm_impl.udp_mu_sendsv

let udp_mu_recv_packet  = Comm_impl.udp_mu_recv_packet 
  
let tcp_send  = Comm_impl.tcp_send
let tcp_sendv  = Comm_impl.tcp_sendv
let tcp_sendsv  = Comm_impl.tcp_sendsv
let tcp_sends2v  = Comm_impl.tcp_sends2v
let tcp_recv = Comm_impl.tcp_recv
let tcp_recv_iov = Comm_impl.tcp_recv_iov
let tcp_recv_packet  = Comm_impl.tcp_recv_packet 
  
let has_ip_multicast  = Comm_impl.has_ip_multicast 
let in_multicast  = Comm_impl.in_multicast 
let setsockopt_ttl = Comm_impl.setsockopt_ttl 
let setsockopt_loop = Comm_impl.setsockopt_loop 
let setsockopt_join = Comm_impl.setsockopt_join 
let setsockopt_leave = Comm_impl.setsockopt_leave 
  
let setsockopt_sendbuf = Comm_impl.setsockopt_sendbuf 
let setsockopt_recvbuf = Comm_impl.setsockopt_recvbuf 
let setsockopt_nonblock = Comm_impl.setsockopt_nonblock 
let setsockopt_bsdcompat = Comm_impl.setsockopt_bsdcompat 
let setsockopt_reuse = Comm_impl.setsockopt_reuse 
  
let os_type_and_version = Comm_impl.os_type_and_version



