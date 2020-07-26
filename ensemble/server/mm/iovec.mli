(**************************************************************)
(*
 *  Ensemble, 2_00
 *  Copyright 2004 Cornell University, Hebrew University
 *           IBM Israel Science and Technology
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
(**************************************************************)
(* IOVEC.MLI *)
(* Author: Mark Hayden, 3/95 *)
(* Rewritten by Ohad Rodeh 9/2001 *)
(* This file wraps the Socket.Iovec raw interface in a more 
 * type-safe manner, using offsets and length types. 
 *)
(**************************************************************)
open Trans
open Buf
(**************************************************************)
(* The type of a C memory-buffer. It is opaque.
 *)
type t = Socket.Iov.t
type pool = Socket.Iov.pool
    
(* initialize the memory-manager. 
 * [init verbose chunk_size max_mem_size send_pool_pcnt min_alloc_size incr_step]
 *)
val init : bool -> int -> int -> float -> int -> int -> unit
  
(* Release all the memory used, assuming none is allocated *)
val shutdown : unit -> unit
  
(* The pool of sent-messages *)
val get_send_pool : unit -> pool
  
(* The pool of recv-messages *)
val get_recv_pool : unit -> pool
  
(* allocation, and copy. 
*)
val buf_of : t -> Buf.t
val buf_of_full : Buf.t -> len -> t -> unit
val of_buf : pool -> Buf.t -> ofs -> len -> t

val empty : t

(* Length of an iovec
*)  
val len : t -> len

val alloc_async : pool -> len -> (t -> unit) -> unit

(* May throw an Out_of_iovec_memory exception, if the
 * user has no more free memory to hand out.
 *)
val alloc : pool -> len -> t
  
val sub : t -> ofs -> len -> t
  
(* Decrement the refount, and free the cbuf if the count
 * reaches zero. 
 *)
val free : t -> unit 
  
(* Increment the refount, do not really copy. 
 *)
val copy : t -> t 

(* Flatten an iovec array into a single iovec.  Copying only
 * occurs if the array has more than 1 non-empty iovec.
 *
 * Throws an Out_of_iovec_memory exception, if 
 * user memory has run out.
 *)
val flatten : t array -> t

(**************************************************************)  
(* For debugging. Return the number of references to the iovec.
*)
val num_refs : t -> int

(* Return the number of iovecs currrently held, and the total length.
 *)
val debug : unit -> int * int

(* Marshal directly into an iovec.
 *
 * Unmarshal directly from an iovec. Raises an exception if there
 * is a problem, and checks for out-of-bounds problems. 
 *)
val marshal : pool -> 'a -> Marshal.extern_flags list -> t
val unmarshal : t-> 'a

(**************************************************************)
val get_stats : unit -> string
(**************************************************************)
  
  
