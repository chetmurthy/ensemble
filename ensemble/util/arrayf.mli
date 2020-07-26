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
(* ARRAYF.MLI : functional arrays *)
(* Author: Mark Hayden, 4/95 *)
(**************************************************************)
(* These have the same behavior as functions in Array or Util *)
(**************************************************************)

type 'a t

val append : 'a t -> 'a t -> 'a t
val bool_to_string : bool t -> string
val combine : 'a t -> 'b t -> ('a * 'b) t
val concat : 'a t list -> 'a t
val copy : 'a t -> 'a t
val create : int -> 'a -> 'a t
val doubleton : 'a -> 'a -> 'a t
val empty : 'a t
val filter : ('a -> bool) -> 'a t -> 'a t
val filter_nones : 'a option t -> 'a t
val flatten : 'a t t -> 'a t
val for_all : ('a -> bool) -> 'a t -> bool
val for_all2 : ('a -> 'b -> bool) -> 'a t -> 'b t -> bool
val fset : 'a t -> int -> 'a -> 'a t
val get : 'a t -> int -> 'a
val gossip : bool t -> int -> int t
val index : 'a -> 'a t -> int
val init : int -> (int -> 'a) -> 'a t
val int_to_string : int t -> string
val max : 'a t -> 'a
val is_empty : 'a t -> bool
val iter : ('a -> unit) -> 'a t -> unit
val iteri : (int -> 'a -> unit) -> 'a t -> unit
val length : 'a t -> int
val map : ('a -> 'b) -> 'a t -> 'b t
val mapi : (int -> 'a -> 'b) -> 'a t -> 'b t
val map2 : ('a -> 'b -> 'c) -> 'a t -> 'b t -> 'c t
val mem : 'a -> 'a t -> bool
val min_false : bool t -> int
val of_array : 'a array -> 'a t
val of_arraye : 'a Arraye.t -> 'a t
val of_list : 'a list -> 'a t
val of_ranks : int -> Trans.rank list -> bool t
val prependi : 'a -> 'a t -> 'a t
val singleton : 'a -> 'a t
val split : ('a * 'b) t -> ('a t * 'b t)
val sub : 'a t -> int -> int -> 'a t
val super : bool t -> bool t -> bool
val to_array : 'a t -> 'a array
val to_arraye : 'a t -> 'a Arraye.t
val to_list : 'a t -> 'a list
val to_ranks : bool t -> Trans.rank list
val to_string : ('a -> string) -> 'a t -> string
val choose : 'a t -> int -> 'a list
val fold : ('a -> 'a -> 'a) -> 'a t -> 'a
val fold_left : ('a -> 'b -> 'a) -> 'a -> 'b t -> 'a
val fold_right : ('b -> 'a -> 'a) -> 'b t -> 'a -> 'a
(*val ordered : ('a -> 'a -> bool) -> 'a t -> bool*)
(*val sort : ('a -> 'a -> bool) -> 'a t -> 'a t*)
val ordered : ('a -> 'a -> int) -> 'a t -> bool
val sort : ('a -> 'a -> int) -> 'a t -> 'a t
val exists : (int -> 'a -> bool) -> 'a t -> bool

(**************************************************************)
(* Hack *)
val sendv : Hsys.send_info -> Hsys.buf Hsys.refcnt Hsys.iovec t -> int
val sendtov : Hsys.sendto_info -> Hsys.buf Hsys.refcnt Hsys.iovec t -> unit
val sendtosv : Hsys.sendto_info -> Hsys.buf -> Hsys.buf Hsys.refcnt Hsys.iovec t -> unit
val sendtovs : Hsys.sendto_info -> Hsys.buf Hsys.refcnt Hsys.iovec t -> Hsys.buf -> unit
val eth_sendtovs : Hsys.eth_sendto_info -> Hsys.buf Hsys.refcnt Hsys.iovec t -> Hsys.buf -> unit
(**************************************************************)
