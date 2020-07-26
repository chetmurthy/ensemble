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
(* MBUF.MLI *)
(* Author: Mark Hayden, 3/95 *)
(**************************************************************)
open Trans
open Buf
(**************************************************************)

type t

val mbuf_size : len

(* Create a new mbuf.
 *)
val create : 
  debug ->				(* name of mbuf *)
  len ->				(* size of segments *)
  len ->				(* max alloc amount *)
  t

(* Release free buffers.
 *)
val compact : t -> unit

(* Return string of info about the mbuf.
 *)
val info : t -> string

(* Return the total number of buffers in the mbuf.
 *)
val nbufs : t -> int

(* Get the maximum allocation size of an mbuf.
 *)
val max_len : t -> len

(**************************************************************)
(* Various functions for allocating from mbufs.
 *)

(* Allocate space and copy data into an mbuf.
 *)
val alloc : debug -> t -> Buf.t -> ofs -> len -> Iovec.t

(* Same, but also wrap it in a Iovecl.
 *)
val allocl : debug -> t -> Buf.t -> ofs -> len -> Iovecl.t

val alloc_recv : 
  debug -> t -> 'a ->
  (Buf.t -> ofs -> len -> len) ->	(* recv: get the message *)
  ('a -> Iovec.rbuf -> ofs -> len -> unit) -> (* alloced: buffer has been alloced *)
  (bool -> bool)			(* check for message *)

(* Similar to above, but passes up the rbuf intead of
 * allocating an iovec.  Also, calls udp_recv directly.
 *)
val alloc_udp_recv : 
  debug -> t -> 'a -> Hsys.socket ->
  ('a -> Iovec.rbuf -> ofs -> len -> unit) -> (* alloced: buffer has been alloced *)
  (unit -> unit)			(* check for message *)

val alloc_eth_recv : 
  debug -> t -> 'a -> Hsys.socket ->
  ('a -> Iovec.rbuf -> ofs -> len -> unit) -> (* alloced: buffer has been alloced *)
  (unit -> unit)			(* check for message *)

(* Allocate from an mbuf and allow the receive function
 * to return a value.
 *)
val alloc_fun : 
  debug -> t -> 
  (Buf.t -> ofs -> len -> len * 'a) -> 
  Iovecl.t * 'a

(* Allocate from an mbuf and allow the receive function to
 * return a value.  This version allows one to override the
 * maximum length of the Mbuf.  
 *)
val alloc_fun_len : 
  debug -> t -> len(*max_len*) ->
  (Buf.t -> ofs -> len -> len * 'a) -> 
  Iovecl.t * 'a

(**************************************************************)
(* Marshaller to iovecs and from strings.  When marshalling,
 * tries to allocate from the given mbuf.
 *)
val make_marsh :
(*  debug -> t -> (('a -> Iovecl.t) * )*)
  debug -> t -> (('a -> Iovecl.t) * (Iovecl.t -> 'a) * (Buf.t -> ofs -> len -> 'a))

(* Flatten an iovecl using the given mbuf.  If the resulting
 * iovec is small enough to be allocated with the mbuf, then
 * it is allocated there.  On the ML heap otherwise.
 *)
val flatten :
  debug -> t -> Iovecl.t -> Iovec.t

(**************************************************************)
val alloc_perftest : debug -> t -> len -> Iovec.t
(**************************************************************)
val pool : t -> Buf.t Pool.t
(**************************************************************)
