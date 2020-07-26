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
(* REFCNT.MLI : manage our own pools of objects *)
(* Author: Mark Hayden, 3/95 *)
(**************************************************************)
open Trans
open Buf
(**************************************************************)

(* Info is called to combine information
 * about operations on refcount objects.
 *)
val info : string -> string -> string
val info2 : string -> string -> string -> string

(* Base handle to refcnted object.
 *)
type 'a root

(* Handles to refcnt'd objects.
 *)
type 'a t

(* Reference count updates.
 *)
val copy : debug -> 'a t -> 'a t
(*val ref : debug -> 'a t -> unit*)
val free : debug -> 'a t -> unit
val check : debug -> 'a t -> unit
val take : debug -> 'a t -> 'a t

(* Access the wrapped object.
 *)
val read : debug -> 'a t -> 'a

(* The void handle.  This will be disregarded
 * by this module.
 *)
val void : debug -> 'a -> 'a t

val count : debug -> 'a root -> int

val create : debug -> 'a -> 'a root * 'a t

val to_string : 'a root -> string

(**************************************************************)
(* These should not normally be used. *)
type iovec = Buf.t t Buf.iovec
val iovec_alloc : debug -> Buf.t t -> ofs -> len -> iovec
val iovec_alloc_noref : debug -> Buf.t t -> ofs -> len -> iovec
val iovec_copy	: debug -> iovec -> iovec
val iovec_free	: debug -> iovec -> unit
val iovec_check	: debug -> iovec -> unit
val iovec_take	: debug -> iovec -> iovec
val iovec_ref	: debug -> iovec -> unit
val iovecl_copy : debug -> iovec Arrayf.t -> iovec Arrayf.t
val iovecl_take : debug -> iovec Arrayf.t -> iovec Arrayf.t
val sendv : Hsys.send_info -> iovec Arrayf.t -> int
val sendtov : Hsys.sendto_info -> iovec Arrayf.t -> unit
val sendtosv : Hsys.sendto_info -> Buf.t -> iovec Arrayf.t -> unit
val sendtovs : Hsys.sendto_info -> iovec Arrayf.t -> Buf.t -> unit
val eth_sendtovs : Hsys.eth_sendto_info -> iovec Arrayf.t -> Buf.t -> unit
(**************************************************************)
