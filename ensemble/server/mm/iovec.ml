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
let name = "IOVEC"
let failwith s = failwith (name^":"^s)
let log = Trace.log name
(**************************************************************)
open Trans
open Buf
open Printf
(**************************************************************)

type t = Socket.Iov.t
type pool = Socket.Iov.pool
    
let init = Socket.Iov.init

let shutdown = Socket.Iov.shutdown

let get_send_pool = Socket.Iov.get_send_pool

let get_recv_pool = Socket.Iov.get_recv_pool

let num_refs t = Socket.Iov.num_refs t
  
(* allocation, and copy. 
 *)
let buf_of t = 
  Buf.of_string (Socket.Iov.string_of_t t)

let buf_of_full buf ofs t = 
  Socket.Iov.string_of_t_full (Buf.string_of buf) (int_of_len ofs) t
    
let of_buf pool buf ofs len = 
  Socket.Iov.t_of_string pool (Buf.string_of buf) (int_of_len ofs) (int_of_len len)
    
let empty = Socket.Iov.empty
  
let len t = len_of_int (Socket.Iov.len t)
  
let alloc_async pool ilen cont_fun = 
  Socket.Iov.alloc_async pool (int_of_len ilen) cont_fun

let alloc pool ilen = 
  Socket.Iov.alloc pool (int_of_len ilen)
      
let sub t ofs len' =
  assert (ofs +|| len' <=|| len t);
  Socket.Iov.sub t (int_of_len ofs) (int_of_len len')
    
(* Decrement the refount, and free the cbuf if the count
 * reaches zero. 
 *)
let free = Socket.Iov.free
  
(* Increment the refount, do not really copy. 
 *)
let copy = Socket.Iov.copy
  
(* Flatten an iovec array into a single iovec.  Copying only
 * occurs if the array has more than 1 non-empty iovec.
 * In the case of a singlton array, the ref-count is incremented. 
 *
 * [flatten iov ilen] 
 * [ilen] is the length of the iovl.
 *)
let flatten = Socket.Iov.flatten
  
let debug () = (-1,-1)
  
let marshal pool a flags = Socket.Iov.marshal pool a flags
  
let unmarshal t = Socket.Iov.unmarshal t

let get_stats = Socket.Iov.get_stats
(**************************************************************)
  
