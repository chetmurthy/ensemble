(**************************************************************)
(*
 *  Ensemble, (Version 1.00)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
(**************************************************************)
(* IOVEC.ML *)
(* Author: Mark Hayden, 5/96 *)
(**************************************************************)
open Trans
open Buf
open Util
(**************************************************************)
let name = Trace.file "IOVEC"
let failwith = Trace.make_failwith name
let log = Trace.log name
(**************************************************************)

type rbuf = Buf.t Refcnt.t

let heap = Refcnt.void

(**************************************************************)

type 'a u = 'a Buf.iovec = {
  rbuf : 'a ;
  ofs : ofs ;
  len : len
}

type t = rbuf u

let len debug iov = iov.len

(**************************************************************)

(* These are all taken from the Refcnt module.
 *)
let alloc = Refcnt.iovec_alloc
let alloc_noref = Refcnt.iovec_alloc_noref
let free  = Refcnt.iovec_free
let ref   = Refcnt.iovec_ref
let check = Refcnt.iovec_check
let copy  = Refcnt.iovec_copy
let take  = Refcnt.iovec_take

(**************************************************************)

let read debug iov f = 
  let debug = Refcnt.info2 name "read" debug in
  f (Refcnt.read debug iov.rbuf) iov.ofs iov.len

let read_net_int debug iov ofs = 
  assert (ofs >=|| len0 && iov.len >= ofs +|| len4) ;
  Buf.read_net_int (Refcnt.read debug iov.rbuf) (iov.ofs +|| ofs)

let read_net_len debug iov ofs = 
  assert (ofs >=|| len0 && iov.len >= ofs +|| len4) ;
  Buf.read_net_len (Refcnt.read debug iov.rbuf) (iov.ofs +|| ofs)

(**************************************************************)

let eq debug i0 i1 =
  if i0.len <> i1.len then
    false 
  else
    Buf.subeq 
      (Refcnt.read debug i0.rbuf) i0.ofs 
      (Refcnt.read debug i1.rbuf) i1.ofs
      i0.len

(**************************************************************)

let sub debug iov ofs len =
  assert (ofs >=|| len0) ;
  assert (len >=|| len0) ;
  assert (ofs +|| len <=|| iov.len) ;
  let debug = Refcnt.info2 name "sub" debug in
(*
  if ofs < len0 || len < len0 || ofs +|| len > iov.len then (
    eprintf "Iovec.sub:ofs=%d, len=%d, iov.len=%d (iov.ofs=%d)\n"
      (int_of_len ofs) (int_of_len len) (int_of_len iov.len) (int_of_len iov.ofs) ;
    failwith ("sub:relative offsets are out of range:"^debug) ;
  ) ;
*)
  alloc debug iov.rbuf (iov.ofs +|| ofs) len

(**************************************************************)

let sub_take debug iov ofs len =
  let ret = sub debug iov ofs len in
  free debug iov ;
  ret

(**************************************************************)

let empty = 
  let debug = Refcnt.info "empty" name in
  alloc debug (heap debug (Buf.empty ())) len0 len0

let empty debug = 
  let debug = Refcnt.info2 name "empty" debug in
  copy debug empty

(**************************************************************)

let create debug len =
  let buf = Buf.create len in
  let rbuf = heap debug buf in
  alloc_noref debug rbuf len0 len

let createf debug len fill =
  let buf = Buf.create len in
  fill buf len0 len ;
  let rbuf = heap debug buf in
  alloc_noref debug rbuf len0 len

(**************************************************************)

let to_string debug iov =
  read debug iov (fun buf ofs len -> 
    log (fun () -> sprintf "to_string:%s:len=%d" debug (int_of_len len)) ;
    Buf.to_string (Buf.sub name buf ofs len)
  )

(**************************************************************)

let of_substring debug buf ofs len =
  log (fun () -> sprintf "of_substring:%s:len=%d" debug (int_of_len len)) ;
  let buf = String.sub buf (int_of_len ofs) (int_of_len len) in
  let str = Buf.of_string debug buf in
  alloc_noref debug (heap debug str) len0 (Buf.length str)

let of_subbuf debug buf ofs len =
  log (fun () -> sprintf "of_substring:%s:len=%d" debug (int_of_len len)) ;
  let str = Buf.sub name buf ofs len in
  alloc_noref debug (heap debug str) len0 (Buf.length str)

(**************************************************************)

let of_string debug str =
  log (fun () -> sprintf "of_string:%s:len=%d" debug (String.length str)) ;
  let str = Buf.of_string debug str in
  alloc_noref debug (heap debug str) len0 (Buf.length str)

(**************************************************************)

let md5_update debug ctx iov =
  Buf.md5_update ctx (Refcnt.read debug iov.rbuf) iov.ofs iov.len

(**************************************************************)

let blit debug iov ofs1 buf ofs2 len =
  Buf.blit 
    debug
    (Refcnt.read debug iov.rbuf)	(* src buffer *)
    (iov.ofs +|| ofs1)          	(* src offset *)
    buf					(* dst buffer *)
    ofs2         			(* dst offset *)
    len         			(* length *)

(**************************************************************)

let chop debug iov =
  read debug iov (fun buf ofs len ->
    let buf = Buf.sub debug buf ofs len in
    alloc debug (heap debug buf) len0 len
  )

let shift debug iov =
  read debug iov (fun buf ofs len ->
    alloc (Refcnt.info2 name "shift" debug) 
      (heap debug buf) (ofs +|| len4) len
  )

(**************************************************************)
let break debug iov f = f iov.rbuf iov.ofs iov.len
let really_break = ident
(**************************************************************)
(* Not normally used.
 *)
let sendv = Refcnt.sendv
let sendtov = Refcnt.sendtov
let sendtosv = Refcnt.sendtosv
let sendtovs = Refcnt.sendtovs
let eth_sendtovs = Refcnt.eth_sendtovs
let iovecl_copy = Refcnt.iovecl_copy
let iovecl_take = Refcnt.iovecl_take
(**************************************************************)
(*
let unsafe_blit debug iov ofs1 buf ofs2 len =
  String.unsafe_blit 
    (Refcnt.read debug iov.rbuf)	(* src string *)
    (int_of_len (len_add iov.ofs ofs1))	(* src offset *)
    buf					(* dst string *)
    (int_of_len ofs2)			(* dst offset *)
    (int_of_len len)			(* length *)
*)
(**************************************************************)
(*
let make_marsh debug =
  let debug0 = Refcnt.info2 name "make_marsh(ma)" debug in
  let debug1 = Refcnt.info2 name "make_marsh(um)" debug in
  let debug = Refcnt.info2 name "make_marsh" debug in
  let (marsh,unmarsh) = Buf.make_marsh debug true in
  let marsh obj =
    let str = marsh obj in
    alloc_noref debug0 (heap debug str) len0 (Buf.length str)
  and unmarsh iov =
    read debug1 iov unmarsh
  in (marsh,unmarsh)
*)
(**************************************************************)
