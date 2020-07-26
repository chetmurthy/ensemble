(**************************************************************)
(* IOVEC.MLI *)
(* Author: Mark Hayden, 3/95 *)
(* Unless otherwise mentioned, these functions do not free
 * the reference counts of their arguments and iovecs
 * returned have all been correctly reference counted. *)
(**************************************************************)
open Trans
open Buf
(**************************************************************)

(* Type of Iovecs.  They are opaque.
 *)
type t

(**************************************************************)
(* Constructors. *)

(* Create an empty iovec.
 *)
val empty : debug -> t

(* Create a new iovec as part of another iovec.  Offset is
 * the relative offset in the buffer.  Length is not affected.
 *)
val sub : debug -> t -> ofs -> len -> t

(* Same as above, but also frees the input iovecl.
 *)
val sub_take : debug -> t -> ofs -> len -> t

(* Make a copy of an Iovec.  When optimized, this just
 * increments the reference count and returns the input
 * argument.  When debugging, this makes a copy of the
 * Iovec.  
 *)
val copy : debug -> t -> t

(**************************************************************)
(* Manipulators. *)

(* Release an Iovec.  This is basically the same for
 * optimized and unoptimized versions.  
 *)
val free : debug -> t -> unit

(* Check the reference counts of an iovec.  When optimized,
 * this is a no-op.  The actual check is made while
 * debugging.  
 *)
val check : debug -> t -> unit

(* Take the reference count of an Iovec.  When optimized, this
 * just returns its argument.  When debugging, this makes a
 * copy of the iovec and then frees the original.
 *)
val take : debug -> t -> t

(**************************************************************)
(* Accessors. *)

(* Open for reading.  The callback should not modify the
 * buffer or let the buffer/offset escape.
 *)
val read : debug -> t -> (Buf.t -> ofs -> len -> 'a) -> 'a

(* Read 4 bytes of an iovec as a 32-bit integer in 
 * network byte order.
 *)
val read_net_int : debug -> t -> ofs -> int
val read_net_len : debug -> t -> ofs -> len

(* Length of an iovec.
 *)
val len	: debug -> t -> len

(* Check if the contents are equal.
 *)
val eq : debug -> t -> t -> bool

(* Calculate an MD5 checksum over the Iovec.
 *)
val md5_update : debug -> Hsys.md5_ctx -> t -> unit

(* Write contents to a buffer.
 *)
val blit : debug -> t -> ofs -> Buf.t -> ofs -> len -> unit

(**************************************************************)
(* All of these do allocation on the ML heap.
 *)

val create : debug -> len -> t
val createf : debug -> len -> (Buf.t -> ofs -> len -> unit) -> t
val of_subbuf : debug -> Buf.t -> ofs -> len -> t
val of_string : debug -> string -> t
val of_substring : debug -> string -> ofs -> len -> t

(**************************************************************)
(* For debugging purposes.
 *)
val to_string : debug -> t -> string	(* allocates *)
val chop : debug -> t -> t
val shift : debug -> t -> t

(**************************************************************)
(**************************************************************)
(* These are not normally used directly.
 *)

(* Iovecs use reference-counted string buffers.
 *)
type rbuf = Buf.t Refcnt.t

(* Wrap a normal ML string as an rbuf.
 *)
val heap : debug -> Buf.t -> rbuf

(* Allocate an iovec.  The reference count is incremented.
 *)
val alloc : debug -> rbuf -> ofs -> len -> t

(* Allocate an iovec.  The reference count is not
 * incremented.  
 *)
val alloc_noref : debug -> rbuf -> ofs -> len -> t

(**************************************************************)
(* These should not normally be used. *)
val ref : debug -> t -> unit
val log : (unit -> string) -> unit	(* for Iovecl *)
val sendv : Hsys.send_info -> t Arrayf.t -> int
val sendtov : Hsys.sendto_info -> t Arrayf.t -> unit
val sendtosv : Hsys.sendto_info -> Buf.t -> t Arrayf.t -> unit
val sendtovs : Hsys.sendto_info -> t Arrayf.t -> Buf.t -> unit
val iovecl_copy : debug -> t Arrayf.t -> t Arrayf.t
val iovecl_take : debug -> t Arrayf.t -> t Arrayf.t
(**************************************************************)
(* These should really not normally be used. *)
type 'a u = { rbuf : 'a ; ofs : ofs ; len : len }
val really_break : t -> rbuf u
val break : debug -> t -> (Buf.t Refcnt.t -> ofs -> len -> 'a) -> 'a
(**************************************************************)
(* Old code.
 *)

(* Marshallers for iovecs.  Allocation is done on the ML heap.
 *)
(*
val make_marsh  : debug -> (('a -> t) * (t -> 'a))

val unsafe_blit : debug -> t -> ofs -> string -> ofs -> len -> unit

*)
(**************************************************************)
