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
(* MARSH.ML *)
(* Author: Mark Hayden, 12/96 *)
(**************************************************************)
open Trans
open Util
open Buf
(**************************************************************)
let name = Trace.file "MARSH"
(**************************************************************)

exception Error of string

let error s = raise (Error s)

(**************************************************************)

type item =
  | Int of int
  | Iovecl of Iovecl.t
  | String of int * Buf.t
  | Buf of Buf.t

type marsh = {
  mbuf : Mbuf.t ;
  mutable buf : item list
} 

let marsh_init mbuf = {
  mbuf = mbuf ;
  buf = []
} 

let add m v =
  m.buf <- v :: m.buf

let write_int m i =
  add m (Int i)

let write_len m i =
  write_int m (int_of_len i)

let write_bool m b =
  write_int m (if b then 1 else 0)

let write_buf m b =
  add m (Buf b)

let write_string m s =
  add m (String((String.length s),(Buf.pad_string s)))

let write_iovl_len m iovl =
  let debug = Refcnt.info2 name "write_iovl_len" "" in
  let iovl = Iovecl.take debug iovl in
  let len = Iovecl.len name iovl in
  add m (Int(int_of_len len)) ;
  add m (Iovecl iovl)

let write_iovl m iovl =
  let debug = Refcnt.info2 name "write_iovl_len" "" in
  let iovl = Iovecl.take debug iovl in
  add m (Iovecl iovl)

let write_list m f l =
  write_int m (List.length l) ;
  List.iter (fun it -> f it) l

let write_array m f a =
  write_int m (Array.length a) ;
  Array.iter (fun it -> f it) a

let write_option m f o =
  match o with
  | None -> write_bool m false
  | Some o -> 
      write_bool m true ;
      f o

let length = function
  | Int _ -> len4
  | Iovecl iovl -> Iovecl.len name iovl
  | String(_,buf) -> Buf.length buf +|| len4
  | Buf buf -> Buf.length buf +|| len4

let marsh_done msh =
  let l = List.rev msh.buf in
  let len = List.fold_left (fun len buf -> len +|| length buf) len0 l in
  let fill dbuf dofs =
    let test = 
      List.fold_left (fun pos it ->
	let len =
	  match it with
	  | Int i ->
	      Buf.write_net_int dbuf pos i ;
	      len4
	  | String(actlen,buf) -> 
	      let len = Buf.length buf in
	      Buf.write_net_int dbuf pos actlen ;
	      Buf.blit name buf len0 dbuf (pos +|| len4) (Buf.length buf) ;
	      len +|| len4
	  | Buf buf -> 
	      let len = Buf.length buf in
	      Buf.write_net_len dbuf pos len ;
	      Buf.blit name buf len0 dbuf (pos +|| len4) (Buf.length buf) ;
	      len +|| len4
	  | Iovecl iovl -> 
	      let len = Iovecl.len name iovl in
	      let test = Iovecl.flatten_buf name iovl dbuf pos len in
	      Iovecl.free name iovl ;
	      assert (test = len) ;
	      len
	in
	pos +|| len
      ) dofs l 
    in
    assert (test = dofs +|| len) ;
  in
  let iovl =
    if len <=|| Mbuf.max_len msh.mbuf then (
      fst (Mbuf.alloc_fun name msh.mbuf 
	     (fun buf ofs _ -> fill buf ofs ; len,()))
    ) else (
      let m = Buf.create len in
      fill m len0 ;
      Mbuf.allocl name msh.mbuf m len0 (Buf.length m)
    )
  in
  Iovecl.take name iovl

(**************************************************************)

type unmarsh = {
  mbuf : Mbuf.t ;
  iovl : Iovecl.t ;
  mutable pos : ofs ;
  len : len ;
  mutable loc : Iovecl.loc ;
} 

let unmarsh_init mbuf iovl = {
  mbuf = mbuf ;
  iovl = Iovecl.take name iovl ;
  pos = len0 ;
  len = Iovecl.len name iovl ;
  loc = Iovecl.loc0
} 

let unmarsh_done m =
  Iovecl.free name m.iovl

let unmarsh_done_all m =
  assert (m.pos == m.len) ;
  unmarsh_done m

let bounds_check m len =
  if m.pos +|| len >|| m.len then
    error "bounds_check"

let advance m len =
  m.pos <- m.pos +|| len

let get_iovl m len =
  bounds_check m len ;
  let ret,loc = Iovecl.sub_scan name m.loc m.iovl m.pos len in
  m.loc <- loc ;
  advance m len ;
  ret

let get_buf m len =
  let iovl = get_iovl m len in
  let iov = Iovecl.flatten name iovl in
  let ret = Iovec.read name iov (Buf.sub name) in
  Iovec.free name iov ;
  ret

let read_int m =
  bounds_check m len4 ;
  let ret = Iovecl.read_net_int name m.iovl m.pos in
  advance m len4 ;
  ret
       
let read_len m =
  bounds_check m len4 ;
  let ret = Iovecl.read_net_len name m.iovl m.pos in
  advance m len4 ;
  ret

let read_bool m =
  match read_int m with
  | 0 -> false
  | 1 -> true
  | _ -> error "read_bool:not a bool"

let read_string m =
  let len = read_int m in
  let tlen = Buf.ceil len in
  let buf = get_buf m tlen in
  let s = Buf.to_string buf in
  String.sub s 0 len

let read_buf m =
  let len = read_len m in
  get_buf m len

let read_iovl_len m =
  let len = read_len m in
  get_iovl m len

let read_iovl = get_iovl

let read_list m f =
  let len = read_int m in
  let rec loop len =
    if len = 0 then [] 
    else (f ()) :: (loop (pred len))
  in loop len

let read_option m f =
  if read_bool m then 
    Some (f ())
  else None

(**************************************************************)
