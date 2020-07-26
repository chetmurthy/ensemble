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
(* ROUTE.MLI *)
(* Author: Mark Hayden, 12/95 *)
(**************************************************************)
open Trans
open Buf
(**************************************************************)

type message =
  | Signed of (bool -> Obj.t option -> int -> Iovecl.t -> unit)
  | Unsigned of (Obj.t option -> int -> Iovecl.t -> unit)
  | Bypass of (int -> Iovecl.t -> unit)
  | Raw of (Iovecl.t -> unit)
  | Scale of (rank -> Obj.t option -> int -> Iovecl.t -> unit)

(**************************************************************)

type handlers
val handlers : unit -> handlers

(* The central delivery functions of Ensemble.  All incoming
 * messages go through here.  These functions all take over
 * the reference to the object.
 *)
val deliver      : handlers -> Iovec.rbuf -> ofs -> len -> unit
val deliver_iov  : handlers -> Iovec.t -> unit
val deliver_iovl : handlers -> Mbuf.t -> Iovecl.t -> unit

(**************************************************************)

type xmits =
  ((Buf.t -> ofs -> len -> unit) * 
   (Iovecl.t -> unit) *
   (Iovecl.t -> Buf.t -> unit))

(* Type of routers.
 *)
type 'msg t

val debug : 'msg t -> debug
val secure : 'msg t -> bool
val blast : 'msg t -> xmits -> Security.key -> Conn.id -> 'msg
val install : 'msg t -> handlers -> Conn.key -> Conn.recv_info Arrayf.t -> 
    Security.key -> (Conn.kind -> rank -> bool -> 'msg) -> unit
val remove : 'msg t -> handlers -> Conn.key -> Conn.recv_info Arrayf.t -> unit
val scaled : 'msg t -> bool

(**************************************************************)

(* Security enforcement.
 *)
val set_secure : unit -> unit

val security_check : 'a t -> unit

(**************************************************************)

type id =
  | SignedId
  | UnsignedId
  | BypassId
  | RawId
  | ScaleId

val id_of_message : message -> id

(**************************************************************)

(* Create a router.
 *)
val create :
  debug ->
  bool -> (* secure? *)
  bool -> (* scaled? *)
  ((bool -> 'msg) -> message) ->
  (Conn.id -> Buf.t) ->			(* packer *)
  ((Conn.id * Buf.t(*digest*) * Security.key * message) Arrayf.t -> 
   (Iovec.rbuf -> ofs -> len -> unit) Arrayf.t) -> (* merge *)
  (xmits -> Security.key -> Buf.t(*digest*) -> Conn.id -> 'msg) ->  (* blast *)
  'msg t

(**************************************************************)

(* Logging functions.  Called from various places.
 *)
val drop : (unit -> string) -> unit (* For tracing message drops: ROUTED *)
val info : (unit -> string) -> unit (* For tracing connection ids: ROUTEI *)

(**************************************************************)
(* Helper functions for the various routers.
 *)
val merge1 : ('a -> unit) Arrayf.t -> 'a -> unit
val merge2 : ('a -> 'b -> unit) Arrayf.t -> 'a -> 'b -> unit
val merge3 : ('a -> 'b -> 'c -> unit) Arrayf.t -> 'a -> 'b -> 'c -> unit
val merge4 : ('a -> 'b -> 'c -> 'd -> unit) Arrayf.t -> 'a -> 'b -> 'c -> 'd -> unit

(* See comments in code.
 *)
val group : ('a * 'b) Arrayf.t -> ('a * 'b Arrayf.t) Arrayf.t
val merge1iov : (Iovecl.t -> unit) Arrayf.t -> Iovecl.t -> unit
val merge2iov : ('a -> Iovecl.t -> unit) Arrayf.t -> 'a -> Iovecl.t -> unit
val merge2iovr : (Iovecl.t -> 'a -> unit) Arrayf.t -> Iovecl.t -> 'a -> unit
val merge3iov : ('a -> 'b -> Iovecl.t -> unit) Arrayf.t -> 'a -> 'b -> Iovecl.t -> unit
val merge4iov : ('a -> 'b -> 'c -> Iovecl.t -> unit) Arrayf.t -> 'a -> 'b -> 'c -> Iovecl.t -> unit

(**************************************************************)

val pack_of_conn : Conn.id -> Buf.t

(**************************************************************)
