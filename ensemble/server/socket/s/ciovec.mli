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
(* NATIOV.ML : Memory management functions. *)
(* Author: Ohad Rodeh 10/2002 *)
(* Rewrite:           12/2003 *)
(**************************************************************)
(* It is not clear whether this is really neccessary 
 * with the newer versions of OCAML.
 * 
 * PERF
 *)
external (=||) : int -> int -> bool = "%eq"
external (<>||) : int -> int -> bool = "%noteq"
external (>=||) : int -> int -> bool = "%geint"
external (<=||) : int -> int -> bool = "%leint"
external (>||) : int -> int -> bool = "%gtint"
external (<||) : int -> int -> bool = "%ltint"
external (+||) : int -> int -> int = "%addint"
external (-||) : int -> int -> int = "%subint"
external ( *||) : int -> int -> int = "%mulint"
(**************************************************************)

(* The type of a C memory-buffer. It is opaque.
 *)
type cbuf  
type buf = string
type ofs = int
type len = int

type base = {
  cbuf : cbuf;         (* Free this cbuf when the refcount reaches zero *)
  total_len : int;     (* The total length of the C-buffer *)
  id : int;            (* The identity of this chunk *)
  mutable count : int; (* A reference count *)
  pool : pool          (* Which pool does this chunk belong to *)
}
    
(* An iovector is an extent out of a C-buffer *)
and t = { 
  base : base ;  
  ofs : int ;
  len : int
}

and pool = {
  name : string;                    (* SEND/RECV *)
  size : int ;                      (* The total size of the pool *)
  free_chunks : base Queue.t;       (* The set of free chunks *)
  mutable chunk_array : base array; (* The whole set of chunks *)
  mutable chunk : base option;      (* The current chunk  *)
  mutable pos : int ;
  mutable allocated : int;          (* The total allocated space *)
  mutable pending : (len * (t -> unit)) Queue.t (* A list of pending allocation requests *)
}
    
type alloc_state = {
  mutable initialized : bool;
  mutable verbose : bool;
  mutable chunk_size : int ;             
  mutable min_alloc_size : int;
  mutable incr_step : int;               (* By how many chunks to increase a pool 
                                            when it dries up *)
  mutable maximum : int ;                (* The maximum allowed size of memory *)
  mutable send_pool : pool option;       (* A pool for sent-messages *)
  mutable recv_pool : pool option;       (* A pool for receiving messages *)
  mutable extra_pool : pool              (* A pool for all extra memory. *)
}


(**************************************************************)

(* initialize the memory-manager. 
 * [init verbose chunk_size max_mem_size send_pool_pcnt min_alloc_size incr_step]
 *)
val init : bool -> int -> int -> float -> int -> int -> unit

(* The pool of sent-messages *)
val get_send_pool : unit -> pool

(* The pool of recv-messages *)
val get_recv_pool : unit -> pool

val shutdown : unit -> unit

(* allocation, and copy. 
 *)
val string_of_t : t -> string 
val string_of_t_full : string -> len -> t -> unit
val t_of_string : pool -> string -> ofs -> len -> t
  
val len : t -> int
  
val empty : t 
  
(* This operation applies only to the Send pool 
*)
val alloc_async : pool -> len -> (t -> unit) -> unit

val alloc : pool -> len -> t
  
val satisfy_pending : unit -> unit
  
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
 *)
val flatten : t array -> t
  
(* For debugging. The number of references to the iovec.
 *)
val num_refs : t -> int
  
(* Marshal into a preallocated iovec. Raise's exception if
 * there is not enough space. Returns the marshaled iovec.
 *)
val marshal : pool -> 'a -> Marshal.extern_flags list -> t
  
(* Unmarshal directly from an iovec. Raises an exception if there
 * is a problem, and checks for out-of-bounds problems. 
 *)
val unmarshal : t -> 'a
  
(**************************************************************)
(* Increase pool size, it does not have sufficient memory *)
val grow_pool : pool -> unit

(**************************************************************)

(* statistics *)
val get_stats : unit -> string

(**************************************************************)
(* Internal to the Socket library
*)  
val check_pre_alloc : pool -> bool 
(* This operation always allocates from the Recv pool. *)
val advance_and_sub_alloc : pool -> len (*total_len*) -> ofs -> len -> t

val s : alloc_state
(**************************************************************)
