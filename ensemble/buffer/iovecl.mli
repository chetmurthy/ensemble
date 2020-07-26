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
(* IOVECL.MLI: operations on arrays of Iovec's. *)
(* Author: Mark Hayden, 3/95 *)
(* Unless otherwise mentioned, these functions do not free
 * the reference counts of their arguments and iovecs
 * returned have all been correctly reference counted. *)
(**************************************************************)
open Trans
open Buf
(**************************************************************)

(* Type of Iovec arrays.
 *)
type t 

(**************************************************************)

(* Refcounting operations: these apply appropriate iovec
 * refcount operation to all member iovecs.  See Iovec.mli
 *)
val free : debug -> t -> unit
val copy : debug -> t -> t
val take : debug -> t -> t
val check : debug -> t -> unit

(**************************************************************)

(* Calculate total length of an array of iovecs.
 *)
val len : debug -> t -> len

(* Check if the contents are equal.
 *)
(*val eq : debug -> t -> t -> bool*)

(* Flatten an iovec array into a single iovec.  Copying only
 * occurs if the array has more than 1 non-empty iovec.
 *)
val flatten : debug -> t -> Iovec.t (* allocates *)

(* Fragment iovec array into an array of iovec arrays of
 * some maximum size.  No copying occurs.  The resulting
 * iovec arrays are at most the specified length.
 *)
val fragment : debug -> len -> t -> t Arrayf.t

(* Remove any empty iovecs from the array.
 * Refcounts are not affected.
 *)
val clean : debug -> t -> t

(* Read 4 bytes of iovec as a 32-bit integer in *
 * network-byte-order.  
 *)
val read_net_int : debug -> t -> ofs -> int
val read_net_len : debug -> t -> ofs -> len

(* Make a marshaller for arrays of iovecs.  The unmarsh
 * function takes the ref count.
 *)
val make_marsh : debug -> (('a -> t) * (t -> 'a))

(* Print information about an array of iovecs.  For debugging
 *)
(*val print : debug -> t -> unit*)

(* Flatten an iovec array into a string buffer.
 *)
val flatten_buf : debug -> t -> Buf.t -> ofs -> len -> len

(* An empty iovec array.
 *)
val empty : t
val is_empty : t -> bool

(* Wrap a normal iovec.  Takes the reference count.
 *)
val of_iovec : debug -> Iovec.t -> t

(* Use an array of iovecs.  Takes the reference count.
 *)
val of_iovec_array : Iovec.t Arrayf.t -> t

(* Append two iovec arrays.  Takes the reference count.
 *)
val append : debug -> t -> t -> t

(* Catenate a list of iovec arrays.  Takes the reference count.
 *)
val concat : debug -> t list -> t
val concata : debug -> t Arrayf.t -> t

(* Prepend a single iovec to an iovec array.  Does not
 * affect refcounts.  
 *)
val prependi : debug -> Iovec.t -> t -> t
val appendi : debug -> t -> Iovec.t -> t

(* Get a subset of an iovecl.  The ofs is relative
 * to the iovecl.  The returned object is properly
 * reference counted.
 *)
val sub : debug -> t -> ofs -> len -> t

(* Same as above, but also frees the input iovecl.
 *)
val sub_take : debug -> t -> ofs -> len -> t

(* This is used for reading Iovecls from left to right.
 * The loc objects prevent the sub operation from O(n^2)
 * behavior when repeatedly sub'ing an Iovecl.  loc0 is
 * then beginning of the iovecl.
 *)
type loc
val loc0 : loc
val sub_scan : debug -> loc -> t -> ofs -> len -> t * loc

val md5_update : debug -> Hsys.md5_ctx -> t -> unit

(* Check if iovecl has only one Iovec.  If it does,
 * Get_singleton will extract it.  Takes the reference
 * count.  get_singleton fails if there is more than one
 * iovec.  
 *)
val is_singleton : debug -> t -> bool
val get_singleton : debug -> t -> Iovec.t
val count_nonempty : debug -> t -> int

(* Allocate an iovec.  The reference count is incremented.
 *)
val alloc : debug -> Iovec.rbuf -> ofs -> len -> t

(* Allocate an iovec.  The reference count is not
 * incremented.  
 *)
val alloc_noref : debug -> Iovec.rbuf -> ofs -> len -> t

(**************************************************************)
(* These should not normally be used. *)
val ref : debug -> t -> unit
val sendv : Hsys.send_info -> t -> int
val sendtov : Hsys.sendto_info -> t -> unit
val sendtosv : Hsys.sendto_info -> Buf.t -> t -> unit
val sendtovs : Hsys.sendto_info -> t -> Buf.t -> unit
val eth_sendtovs : Hsys.eth_sendto_info -> t -> Buf.t -> unit
(**************************************************************)
