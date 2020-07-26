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
(* MSECCHAN: Utilities for SECCHAN layer *)
(* Author: Ohad Rodeh  7/99 *)
(**************************************************************)

type status = 
  | Closed
  | SemiOpen
  | OpenBlocked
  | Open
  | SemiShut
  | ShutBlocked

val string_of_status : status -> string

val common : 'a Arrayf.t -> 'a Arrayf.t -> 'a Arrayf.t

val rand_time2 : Time.t -> Time.t -> int -> Time.t


module type HS = sig
  type ('a, 'b) t

  val create : int -> ('a,'b) t
  val clear : ('a, 'b) t -> unit
  val add : ('a, 'b) t -> 'a -> 'b -> unit
  val find : ('a, 'b) t -> 'a -> 'b
  val find_all : ('a, 'b) t -> 'a -> 'b list
  val mem :  ('a, 'b) t -> 'a -> bool
  val remove : ('a, 'b) t -> 'a -> unit
  val iter : ('a -> 'b -> unit) -> ('a, 'b) t -> unit

  val size  : ('a,'b) t -> int
  val to_list : ('a,'b) t -> ('a * 'b) list
end

module Hashtbls : HS 


module type CH = sig
  type ('time, 'key, 'msg, 'crpt) s

  val create_s : 'time -> 'key -> ('time -> 'time -> bool) -> 
    ('key -> 'msg -> 'crpt) -> ('key -> 'crpt -> 'msg) -> 
      ('time, 'key, 'msg, 'crpt) s

  type ('time, 'key, 'msg, 'crpt) t

  val create : ('time, 'key, 'msg, 'crpt) s -> 'key -> status -> 
    ('time, 'key, 'msg, 'crpt) t

  val send   : ('time, 'key, 'msg, 'crpt) s -> ('time, 'key, 'msg, 'crpt) t -> 
    'time -> 'msg -> 'crpt

  val recv   : ('time, 'key, 'msg, 'crpt) s -> ('time, 'key, 'msg, 'crpt) t -> 
    'time -> 'crpt -> 'msg

  val string_of_t : ('time, 'key, 'msg, 'crpt) t -> string
  val getStatus : ('time, 'key, 'msg, 'crpt) t -> status
  val setStatus : ('time, 'key, 'msg, 'crpt) t -> status -> unit
  val getKey    : ('time, 'key, 'msg, 'crpt) t -> 'key
  val setKey    : ('time, 'key, 'msg, 'crpt) t -> 'key -> unit
  val getTime   : ('time, 'key, 'msg, 'crpt) t -> 'time
  val setTime   : ('time, 'key, 'msg, 'crpt) t -> 'time -> unit
  val getMsgs   : ('time, 'key, 'msg, 'crpt) t -> 'msg Queue.t

  (* Turn a hashtbls of channels into a list 
   *)
  val freeze : ('time, 'key, 'msg, 'crpt) s -> (Trans.rank -> 'endpt) -> 
    (Trans.rank, ('time, 'key, 'msg, 'crpt) t) Hashtbls.t -> 
      ('endpt * 'time * 'time * 'key * status) list

  (* Insert the list of channels into a preallocated hashtbl.
   * Return the inchan set and outchan set
   *)
  val unfreeze : ('time, 'key, 'msg, 'crpt) s -> ('endpt -> Trans.rank ) -> 
    ('endpt * 'time * 'time * 'key * status) list -> 
      (Trans.rank, ('time, 'key, 'msg, 'crpt) t) Hashtbls.t -> unit

  (* Find the channel that has been least recently used
   *)
  val find_lru : ('time, 'key, 'msg, 'crpt) s -> 
    (Trans.rank, ('time, 'key, 'msg, 'crpt) t) Hashtbls.t -> 
      (Trans.rank *  ('time, 'key, 'msg, 'crpt) t) option
end

module Channel : CH 


