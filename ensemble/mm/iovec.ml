(**************************************************************)
(* IOVEC.MLI *)
(* Author: Mark Hayden, 3/95 *)
(* Rewritten by Ohad Rodeh 9/2001 *)
(* This file wraps the Socket.Iovec raw interface in a more 
 * type-safe manner, using offsets and length types. 
 *)
(**************************************************************)
let name = "IOVEC"
let failwith s = failwith (name^":"^s)
let log = Trace.log name
(**************************************************************)
open Trans
open Buf
open Printf
(**************************************************************)

(* optmized version
*)
module Opt = struct
  type t = Socket.Basic_iov.t
      
  (* A raw iovec, no ref-counting.
   *)
  type raw = Socket.Basic_iov.raw
  let of_raw = Socket.Basic_iov.t_of_raw
  let raw_of = Socket.Basic_iov.raw_of_t

  (* allocation, and copy. 
   *)
  let buf_of t = Buf.of_string (Socket.Basic_iov.string_of_t t)
  let buf_of_full buf ofs t = 
    Socket.Basic_iov.string_of_t_full (Buf.string_of buf) (int_of_len ofs) t

  let of_buf buf ofs len = 
    Socket.Basic_iov.t_of_string (Buf.string_of buf) (int_of_len ofs) (int_of_len len)
    
  let empty = Socket.Basic_iov.empty
    
  let len t = len_of_int (Socket.Basic_iov.len t)
    
  let alloc ilen = 
    if ilen =|| len0 then 
      empty 
    else 
      let iov = Socket.Basic_iov.alloc (int_of_len ilen) in
      iov
    
  let sub t ofs len' =
    assert (ofs +|| len' <=|| len t);
    Socket.Basic_iov.sub t (int_of_len ofs) (int_of_len len')
      
  (* Decrement the refount, and free the cbuf if the count
   * reaches zero. 
   *)
  let free = Socket.Basic_iov.free
    
  (* Increment the refount, do not really copy. 
   *)
  let copy = Socket.Basic_iov.copy
    
  let really_copy = Socket.Basic_iov.really_copy

  (* Flatten an iovec array into a single iovec.  Copying only
   * occurs if the array has more than 1 non-empty iovec.
   * In the case of a singlton array, the ref-count is incremented. 
   *
   * [flatten iov ilen] 
   * [ilen] is the length of the iovl.
   *)
  let flatten = Socket.Basic_iov.flatten

  let flatten_w_copy = Socket.Basic_iov.flatten_w_copy 

  let num_refs t = Socket.Basic_iov.num_refs t

  let debug () = (-1,-1)

  let marshal a flags = Socket.Basic_iov.marshal a flags

  let unmarshal t = Socket.Basic_iov.unmarshal t

  let sendtov = Socket.sendtov
  let sendtosv = Socket.sendtosv 
  let udp_recv_packet s = 
    let str,iov = Socket.udp_recv_packet s in
    Buf.of_string str,iov

  let recv_iov = Socket.recv_iov
  let tcp_recv_packet = Socket.tcp_recv_packet
  let sendv_p = Socket.sendv_p
  let sendsv_p = Socket.sendsv_p
  let sends2v_p = Socket.sends2v_p
  let md5_update_iov = Socket.md5_update_iov 

end 

(**************************************************************)
    
(* Debugging version. Keep track of all iovec's in a hash table.
 * This is Ami's idea.
*)
module Debug = struct
  let h : ((int,  Socket.Basic_iov.t) Hashtbl.t) = Hashtbl.create 1001 

  let key = ref 1
  let incr_key () = key := succ !key; !key

  (* Log an iovec in the hash table.
   *)
  let log_iov iov = 
    let key = incr_key () in
    Hashtbl.add h key iov;
    (key,iov)

  type key = int
  type t = key * Socket.Basic_iov.t  (* [key] is the key in the hashtable *)
      
  type raw = Socket.Basic_iov.raw
  let of_raw r = 
    let t = Socket.Basic_iov.t_of_raw r in
    log_iov t

  let raw_of (_,t) = Socket.Basic_iov.raw_of_t t

  (* allocation, and copy. 
   *)
  let buf_of (key,t) = Buf.of_string (Socket.Basic_iov.string_of_t t)
  let buf_of_full buf ofs (key,t) = 
    Socket.Basic_iov.string_of_t_full (Buf.string_of buf) (int_of_len ofs) t

  let of_buf buf ofs len = 
    let iov = 
      Socket.Basic_iov.t_of_string (Buf.string_of buf) (int_of_len ofs) (int_of_len len) in
    log_iov iov
    
  let empty = (0,Socket.Basic_iov.empty)
    
  let len (key,t) = len_of_int (Socket.Basic_iov.len t)
    
  let alloc ilen = 
    if ilen =|| len0 then 
      empty 
    else
      let iov = Socket.Basic_iov.alloc (int_of_len ilen) in
      log_iov iov
    
  let sub (key,t) ofs len' =
    assert (ofs +|| len' <=|| len (key,t));
    log (fun () -> "sub");
    let t' = Socket.Basic_iov.sub t (int_of_len ofs) (int_of_len len') in
    (key,t')
      
  (* Decrement the refount, and free the cbuf if the count
   * reaches zero. 
   *)
  let free (key,t) = 
    log (fun () -> "free(");
    Socket.Basic_iov.free t;
    if Socket.Basic_iov.num_refs t = 0 then (
	Hashtbl.remove h key ;
      );
    log (fun () -> ")");
    ()

  (* Increment the refount, do not really copy. 
   *)
  let copy (key,t) = 
    log (fun () -> "copy");
    (key,Socket.Basic_iov.copy t)

  let really_copy (_,t) = 
    log (fun () -> "really_copy");
    log_iov (Socket.Basic_iov.really_copy t)
    
  (* Flatten an iovec array into a single iovec.  Copying only
   * occurs if the array has more than 1 non-empty iovec.
   * In the case of a singlton array, the ref-count is incremented. 
   *
   * [flatten iov len] 
   * [len] is the length of the iovl.
   *)
  let flatten ta = 
    log (fun () -> "flatten");
    match ta with
	[||] ->	raise (Invalid_argument "An empty iovecl to flatten")
      | [|(key,t)|] -> 
	  copy (key,t)
      | _ -> 
	  let ta' = Array.map (fun (_,t) -> t) ta in
	  let new_iov = Socket.Basic_iov.flatten ta' in
	  log_iov new_iov

  let flatten_w_copy ta = 
    log (fun () -> "flatten");
    match ta with
	[||] ->	raise (Invalid_argument "An empty iovecl to flatten")
      | [|i|] -> 
	  really_copy i
      | _ -> 
	  let ta' = Array.map (fun (_,t) -> t) ta in
	  let new_iov = Socket.Basic_iov.flatten ta' in
	  log_iov new_iov
	    

  let num_refs (key,t) = Socket.Basic_iov.num_refs t

  let debug () = 
    let sum = Hashtbl.fold (fun _ iov (num,sum_len) -> 
      let len = Socket.Basic_iov.len iov in 
      if len>0 then 
	(succ num, sum_len+len)
      else
	(num,sum_len)
    ) h (0,0) in
    sum

  let marshal obj flags = 
    let iov = Socket.Basic_iov.marshal obj flags in
    log_iov iov

  let unmarshal (key,t) = Socket.Basic_iov.unmarshal t 

  let sendtov info iovec_a = 
    let iovec_a = Array.map (fun (_,t) -> t) iovec_a in
    Socket.sendtov info iovec_a 

  let sendtosv info buf ofs len iovec_a = 
    let iovec_a = Array.map (fun (_,t) -> t) iovec_a in
    Socket.sendtosv info buf ofs len iovec_a 

  let udp_recv_packet sock = 
    let buf, iov = Socket.udp_recv_packet sock in
    Buf.of_string buf, log_iov iov

  let recv_iov socket (key,iov) ofs len = 
    Socket.recv_iov socket iov ofs len

  let tcp_recv_packet sock buf ofs len (key,iov) = 
    Socket.tcp_recv_packet sock buf ofs len iov 

  let sendv_p sock iovec_a = 
    let iovec_a = Array.map (fun (_,t) -> t) iovec_a in
    Socket.sendv_p sock iovec_a

  let sendsv_p sock buf ofs len iovec_a = 
    let iovec_a = Array.map (fun (_,t) -> t) iovec_a in
    Socket.sendsv_p sock buf ofs len iovec_a
    
  let sends2v_p sock buf1 buf2 ofs len iovec_a = 
    let iovec_a = Array.map (fun (_,t) -> t) iovec_a in
    Socket.sends2v_p sock buf1 buf2 ofs len iovec_a

  let md5_update_iov ctx (key,iov) = 
    Socket.md5_update_iov ctx iov

end

(**************************************************************)
(* Choose if you want to use the debugging version, or the 
 * optimized one.
*)
module M = Opt (*Debug*)
open M

type raw = M.raw
let of_raw = M.of_raw
let raw_of = M.raw_of

type t = M.t
    
let buf_of = M.buf_of
let buf_of_full = M.buf_of_full
let of_buf = M.of_buf
let empty = M.empty
let len = M.len
let alloc = M.alloc
let sub = M.sub
let free = M.free
let copy = M.copy
let really_copy = M.really_copy
let flatten = M.flatten
let flatten_w_copy = M.flatten_w_copy
let num_refs = M.num_refs
let debug = M.debug
let marshal = M.marshal
let unmarshal = M.unmarshal

module Priv = struct
  let md5_update_iov = M.md5_update_iov
  let sendtov = M.sendtov
  let sendtosv = M.sendtosv 
  let udp_recv_packet = M.udp_recv_packet
  let recv_iov = M.recv_iov
  let tcp_recv_packet = M.tcp_recv_packet
  let sendv_p = M.sendv_p
  let sendsv_p = M.sendsv_p
  let sends2v_p = M.sends2v_p
end
(**************************************************************)
  
