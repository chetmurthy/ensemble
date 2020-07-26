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
(* BUF.ML *)
(* Author: Mark Hayden, 8/98 *)
(**************************************************************)
open Trans
(**************************************************************)

(* Type of lengths and offsets.  These are required to be
 * multiples of 4, in order to support word based operations
 * on 32-bit platforms.  We will probably switch this to be
 * multiples of 8, in order to support 64-bit architectures.
 *)
type len (*= int*) (* should be opaque *)
type ofs = len

external int_of_len : len -> int = "%identity"
external (=||) : len -> len -> bool = "%eq"
external (<>||) : len -> len -> bool = "%noteq"
external (>=||) : len -> len -> bool = "%geint"
external (<=||) : len -> len -> bool = "%leint"
external (>||) : len -> len -> bool = "%gtint"
external (<||) : len -> len -> bool = "%ltint"
external (+||) : len -> len -> len = "%addint"
external (-||) : len -> len -> len = "%subint"
external ( *||) : len -> int -> len = "%mulint"

val len_mul4 : len -> len

(* Returns true if the integer is properly
 * aligned.
 *)
val is_len : int -> bool

(* Fails when integer is not properly aligned.  Use ceil to
 * round it up, or check first with is_len.
 *)
val len_of_int : int -> len

(* Round up/down to the next legal length value.
 *)
val ceil : int -> len
val floor : int -> len

val len0 : len
val len4 : len
val len8 : len
val len12 : len
val len16 : len

val md5len : len
val md5len_plus_4 : len
val md5len_plus_8 : len
val md5len_plus_12 : len

(**************************************************************)

(* Buffer objects are guaranteed to be word-aligned.  The
 * type is kept abstract.
 *)
type t

type 'a iovec = { rbuf : 'a ; ofs : ofs ; len : len }

val blit : debug -> t -> ofs -> t -> ofs -> len -> unit
val blit_str : debug -> string -> int -> t -> ofs -> len -> unit
val check : debug -> t -> ofs -> len -> unit
val concat : t list -> t
val copy : t -> t
val append : t -> t -> t
val create : len -> t
val digest_sub : t -> ofs -> len -> t
val digest_substring : string -> int(*ofs*) -> int(*len*) -> t
val empty : unit -> t
val eth_recv :  Hsys.recv_info -> t -> ofs -> len -> len
val int_of_substring : t -> ofs -> int
val int16_of_substring : t -> ofs -> int
val length : t -> len
val md5_update : Hsys.md5_ctx -> t -> ofs -> len -> unit
val md5_final : Hsys.md5_ctx -> t
val of_string : debug -> string -> t
val pad_string : string -> t
val read_net_int : t -> ofs -> int
val read_net_len : t -> ofs -> len
val write_net_int : t -> ofs -> int -> unit
val write_net_len : t -> ofs -> len -> unit
val recv_hack : Hsys.socket -> t -> int -> int -> int
val sendto : Hsys.sendto_info -> t -> ofs -> len -> unit
val sendtosv : Hsys.sendto_info -> t -> t Hsys.refcnt iovec Arrayf.t -> unit
val sendtovs : Hsys.sendto_info -> t Hsys.refcnt iovec Arrayf.t -> t -> unit
val sendtov : Hsys.sendto_info -> t Hsys.refcnt iovec Arrayf.t -> unit
val eth_sendtovs : Hsys.eth_sendto_info -> t Hsys.refcnt iovec Arrayf.t -> t -> unit
val sendv : Hsys.send_info -> t Hsys.refcnt iovec Arrayf.t -> int
val static : len -> t
val sub : debug -> t -> ofs -> len -> t
val subeq : t -> ofs -> t -> ofs -> len -> bool
val subeq8 : t -> ofs -> t -> bool
val subeq16 : t -> ofs -> t -> bool
val to_hex : t -> string
val to_string : t -> string
val udp_recv :  Hsys.recv_info -> t -> ofs -> len -> len

(**************************************************************)

(* Make matched marshallers to/from buffers, with offsets.
 * The second argument is true if you want exceptions to be
 * caught.
 *)
val make_marsh_buf : debug -> bool ->
  (('a -> t -> ofs -> len -> len) * 
   (t -> ofs -> len -> 'a))

(* Make matched marshallers to/from buffers.
 *)
val make_marsh : debug -> bool ->
  (('a -> t) * (t -> ofs -> len -> 'a))

(**************************************************************)
(* This should not normally be used. *)
val break : t -> string
(**************************************************************)
