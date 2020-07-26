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
(* MBUF.ML *)
(* Author: Mark Hayden, 3/95 *)
(**************************************************************)
open Util
open Trans
open Buf
(**************************************************************)
let name = Trace.file "MBUF"
let failwith = Trace.make_failwith name
let log = Trace.log name
(**************************************************************)

let mbuf_size = len_of_int (64 * 1024)  (* 64K *)
let mbuf_count = ref 1			(* # bufs allocated *)

let _ =
  Trace.install_root (fun () ->
    [sprintf "MBUF:#mbufs=%d" (!mbuf_count)]
  )

(**************************************************************)

type t = {
  mutable ofs : ofs ;
  max_len : len ;
  mutable rbuf : Iovec.rbuf ;
  hi : ofs ;
  pool : Buf.t Pool.t ;
  free_buf : Buf.t Queuee.t ;
  debug : string 
}

let max_len m = m.max_len
let pool m = m.pool

(**************************************************************)

(* This is the number of free buffers we expect to have after
 * calling Gc.full_major ().  If we do not get that many back,
 * then allocate at least that many.
 *)
let free_const = 6

let buffer_policy live free =
  if live = 0 && free = 0 then (
    (* We must not be using the special buffer management system.
     *)
    1
  ) else (
    let add = 0 in
(* I think this is bad...
    let add = max add (live - free) in
*)
    let add = int_max add (free_const - free) in
    let add = int_min add free_const in
    log (fun () -> sprintf "live=%d, free=%d, adding=%d" live free add) ;
    add
  )

(* String create, tries to create a string on the heap.
 * BUG: this code should be linked to the call to finalize
 *)
let alloc len =
  try
    Buf.static len
  with Failure _ ->
    Buf.create len

(*
let free o =
  try 
    Hsys.static_string_free o
  with Failure _ -> ()
*)

let allocer free_buf len live free =
  let add = buffer_policy live free in
  let add = Array.create add () in
  let add =
    Array.map (fun () -> 
      match Queuee.takeopt free_buf with
      |	Some a -> a
      |	None -> alloc len
    ) add 
  in
  let add = Array.to_list add in
  add

(**************************************************************)

let nbufs m =
  Pool.nbufs m.pool + Queuee.length m.free_buf

(**************************************************************)

(* Note: 'rec' is used to avoid inlining.
 *)
let rec refresh m =
  incr mbuf_count ;
  let rbuf = m.rbuf in
  m.rbuf <- Pool.alloc name m.pool ;
  m.ofs <- len0 ;
  Refcnt.free name rbuf

let advance m len =
  let ofs = m.ofs +|| len in
  m.ofs <- ofs ;
  if ofs >|| m.hi then  (
    refresh m
  )

(**************************************************************)

let create debug len max_len =
  let free_buf = Queuee.create () in
  let free buf =
    Queuee.add buf free_buf
  in
  assert (len > max_len) ;
  let pool = 
    Pool.create
      debug
      (fun () -> alloc len) 
      free
      (allocer free_buf len) 
  in

  { rbuf = Pool.alloc debug pool ;
    ofs = len0 ;
    hi = len -|| max_len ;
    max_len = max_len ;
    free_buf = free_buf ;
    debug = debug ;
    pool = pool
  }

let compact m =
  Pool.compact m.pool

let info m =
  sprintf "{Mbuf:#free_buf=%d;pool=%s}"
    (Queuee.length m.free_buf)
    (Pool.info m.pool)

(**************************************************************)

let alloc debug m buf ofs len =
  assert (ofs >=|| len0 && ofs +|| len <=|| Buf.length buf) ;
  if len >|| m.max_len then (
    Iovec.of_subbuf debug buf ofs len
  ) else (
    let m_buf = Refcnt.read debug m.rbuf in
    Buf.blit debug buf ofs m_buf m.ofs len ;
    let ret = Iovec.alloc debug m.rbuf m.ofs len in
    advance m len ;
    ret
  )

let allocl debug m buf ofs len =
  Iovecl.of_iovec debug (alloc debug m buf ofs len)

(**************************************************************)

let alloc_recv debug m handlers recv hdlr =
  let max_len = m.max_len in
  let aur_check gm =
    let ofs  = m.ofs in
    let rbuf = m.rbuf in
    let buf  = Refcnt.read debug rbuf in
    let len  = recv buf ofs max_len in
    if len >|| len0 then (
      let new_rbuf = Refcnt.copy debug rbuf in
      advance m len ;
      hdlr handlers new_rbuf ofs len ;
      true
    ) else gm
  in aur_check

(**************************************************************)

let alloc_udp_recv debug m handlers sock hdlr =
  let recv_info = Hsys.recv_info sock in
  let max_len = m.max_len in
  
  let hdlr = arity3 hdlr in

  (* Critical path.
   *)
  let aur_check () =
    (* Call the receive function.
     *)
    (*eprintf "MBUF:sock=%d\n" (Hsys.int_of_socket sock) ;*)
    let ofs  = m.ofs in
    let rbuf = m.rbuf in
    let len  = Buf.udp_recv recv_info (Refcnt.read debug rbuf) ofs max_len in

    if len >|| len0 then (
      let new_rbuf = Refcnt.copy debug rbuf in
      advance m len ;
      hdlr handlers new_rbuf ofs len
    )
  in aur_check

(**************************************************************)

let alloc_eth_recv debug m handlers sock hdlr =
  let recv_info = Hsys.recv_info sock in
  let max_len = m.max_len in
  
  let hdlr = arity3 hdlr in

  (* Critical path.
   *)
  let aur_check () =
    (* Call the receive function.
     *)
    let ofs  = m.ofs in
    let rbuf = m.rbuf in
    let len  = Buf.eth_recv recv_info (Refcnt.read debug rbuf) ofs max_len in

    if len >|| len16 then (
      let new_rbuf = Refcnt.copy debug rbuf in
      advance m len ;
      hdlr handlers new_rbuf (ofs +|| len16) (len -|| len16)
    )
  in aur_check

(**************************************************************)

let flatten debug m il =
  let debug = Refcnt.info2 name "flatten" debug in
  let non_empty = Iovecl.count_nonempty debug il in
  match non_empty with
  | 0 ->
      Iovecl.free debug il ; 
      Iovec.empty debug
  | 1 -> 
      Iovecl.flatten debug il
  | _ ->
      let len = Iovecl.len debug il in
      if len >=|| m.max_len then (
	Iovecl.flatten debug il
      ) else (
	ignore (Iovecl.flatten_buf debug il (Refcnt.read debug m.rbuf) m.ofs len) ;
	Iovecl.free debug il ;
	let iov = Iovec.alloc debug m.rbuf m.ofs len in
	advance m len ;
	iov
      )

(**************************************************************)

let make_marsh debug m =
  let debug = Refcnt.info2 name "make_marsh" debug in
  let debugma = Refcnt.info2 name "make_marsh(ma)" debug in
  let debugum = Refcnt.info2 name "make_marsh(um)" debug in
  let (marsh,unmarsh_buf) = Buf.make_marsh_buf debug true in
  let (marsh_bad,_) = Buf.make_marsh debug true in
  let unmarsh iovl = 
    let iov = flatten debugum m iovl in
    let ret = Iovec.read debugum iov unmarsh_buf in
    Iovec.free debugum iov ;
    ret
  in
  let marsh obj =
    let len =
      marsh obj (Refcnt.read debugma m.rbuf) m.ofs m.max_len
    in

    if len >=|| len0 then (
      let ret = Iovecl.alloc debugma m.rbuf m.ofs len in
      advance m len ;
      ret
    ) else (
      let str = marsh_bad obj in
      Iovecl.alloc debugma (Iovec.heap debugma str) len0 (Buf.length str)
    )      
  in (marsh,unmarsh,unmarsh_buf)

(**************************************************************)
(**************************************************************)
(* This is taken from cdda/mllib/cdmbuf.ml by Jason Hickey.
 *)

(* The read function is given a pointer into the current mbuf
 * (which it can read up to the max alloc amount).  The returned
 * length is used to update the pointer into the mbuf, and the "other"
 * value is returned directly.
 *)
let alloc_fun debug m fill =
  let debug = Refcnt.info2 name "alloc_fun" debug in

  (* Call the receive function.
   *)
  let len,other =
    let buf = Refcnt.read debug m.rbuf in
    fill buf m.ofs m.max_len
  in
  
  (* Special case zero length iovec.
   *)
  let iovl =
    if len =|| len0 then (
      Iovecl.empty
    ) else (
      let iov = Iovecl.alloc debug m.rbuf m.ofs len in
      advance m len ;
      iov
    )
  in iovl,other

(**************************************************************)
(* Same as above, but can override the Mbuf's allocation size.
 *)

let alloc_fun_len debug m max_len recv =
  let buf_len = Buf.length (Refcnt.read debug m.rbuf) in
  assert (max_len <=|| buf_len) ;

  (* Check the remaining space.
   *)
  if m.ofs +|| max_len >|| buf_len then
    refresh m ;

  (* Call the receive function.
   *)
  let len, other =
    recv (Refcnt.read debug m.rbuf) m.ofs (max m.max_len max_len)
  in
  
  (* Special case for zero length iovec.
   *)
  let iovl =
    if len =|| len0 then
      Iovecl.empty
    else (
      let iov = Iovecl.alloc debug m.rbuf m.ofs len in
      advance m len ;
      iov
    )
  in iovl,other

(**************************************************************)
(**************************************************************)

(* This is used for performance tests.
 *)
let alloc_perftest debug m len =
  let iov = Iovec.alloc debug m.rbuf m.ofs len in
  advance m len ;
  iov

(**************************************************************)
(**************************************************************)
