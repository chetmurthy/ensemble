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

open Util
open Trans

(**************************************************************)
let name = Trace.filel "MSECCHAN"
let log  = Trace.log2 name ""
(**************************************************************)

type status = 
  | Closed
  | SemiOpen
  | OpenBlocked
  | Open
  | SemiShut
  | ShutBlocked

let string_of_status = function
  | Closed  -> "Closed"
  | SemiOpen -> "SemiOpen"
  | OpenBlocked -> "Open_blocked"
  | Open    -> "Open"
  | SemiShut -> "SemiShut"
  | ShutBlocked -> "ShutBlocked"


let common a b = 
  let a = Lset.inject a
  and b = Lset.inject b in
  Lset.project (Lset.intersecta a b)

let rand_time2 a b i = 
  assert (i>0);
  Time.add (Time.add a b) (Time.of_int (Random.int i))


(**************************************************************)
(* Hashtables with a size counter.
*)

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
  
module Hashtbls : HS = struct
  type ('a, 'b) t = {
    h            :  ('a, 'b) Hashtbl.t ;
    mutable size : int 
  }

  let create n = {h = Hashtbl.create n; size = 0}

  let clear hs = Hashtbl.clear hs.h

  let add hs key data = 
    hs.size <- hs.size +1; 
    Hashtbl.add hs.h key data 

  let find  hs key =  
    Hashtbl.find hs.h key 

  let find_all  hs key =  
    Hashtbl.find_all hs.h key 

  let mem hs  key =  
    Hashtbl.mem hs.h key

  (* Reduce size only if the key exists 
   *)
  let remove hs key =
    if Hashtbl.mem hs.h key then (
      Hashtbl.remove hs.h key ;
      hs.size <- hs.size - 1 
    ) else ()
    
  let iter f hs = 
    Hashtbl.iter f hs.h

  let size hs = hs.size
    
  let to_list hs = Util.hashtbl_to_list hs.h

end


(**************************************************************)
(* Test code 
*)

open Hashtbls
open Printf
(*
let _  = 
  let h = create 5 in
  add h 1 "A" ;
  add h 2 "B" ;
  add h 3 "C" ;
  add h 4 "D" ;
  printf "size = %d (should be 4)\n" (size h); flush stdout ;
  remove h 1 ;
  remove h 2 ;
  printf "size = %d (should be 2)\n" (size h); flush stdout ;
  add h 3 "C2" ;
  add h 4 "D2" ;
  printf "size = %d (should be 4)\n" (size h); flush stdout ;
  remove h 3 ;
  remove h 4 ;
  printf "size = %d (should be 2)\n" (size h); flush stdout ;
  iter (fun key data -> printf "%d,%s " key data) h;
  printf "\n"; flush stdout ;

  (* Removing non-existent members, size should remain the same 
  *)
  remove h 6;
  remove h 7;
  printf "size = %d (should be 2)\n" (size h); flush stdout ;
  
  exit 0
*)
(**************************************************************)


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
  val freeze : ('time, 'key, 'msg, 'crpt) s -> (rank -> 'endpt) -> 
    (rank, ('time, 'key, 'msg, 'crpt) t) Hashtbls.t -> 
      ('endpt * 'time * 'time * 'key * status) list

  (* Insert the list of channels into a preallocated hashtbl.
   * Return the inchan set and outchan set
   *)
  val unfreeze : ('time, 'key, 'msg, 'crpt) s -> ('endpt -> rank ) -> 
    ('endpt * 'time * 'time * 'key * status) list -> 
      (rank, ('time, 'key, 'msg, 'crpt) t) Hashtbls.t -> unit


  (* Find the channel that has been least recently used
   *)
  val find_lru : ('time, 'key, 'msg, 'crpt) s -> 
    (rank, ('time, 'key, 'msg, 'crpt) t) Hashtbls.t -> 
      (rank *  ('time, 'key, 'msg, 'crpt) t) option

end

module Channel : CH = struct
  type ('time, 'key, 'msg, 'crpt) s = {
    zero_time        : 'time ;
    zero_key         : 'key ;
    time_ge          : 'time -> 'time -> bool ;
    encrypt          : 'key -> 'msg -> 'crpt ;
    decrypt          : 'key -> 'crpt -> 'msg 
  }

  type ('time, 'key, 'msg, 'crpt) t = {
    mutable end_time : 'time ;
    mutable last_use : 'time ;
    mutable key      : 'key ;
    msgs             : 'msg Queue.t;
    mutable status   : status ;
  }	
      
  let create_s zero_time zero_key time_ge encrypt decrypt = {
    zero_time        = zero_time ;
    zero_key         = zero_key ;
    time_ge          = time_ge ;
    encrypt          = encrypt ;
    decrypt          = decrypt 
  }

  let create s key status =  {
    end_time   = s.zero_time ;
    last_use   = s.zero_time ;
    key        = key ;
    msgs       = Queue.create ();
    status     = status 
  } 

  let send s t time data = 
    t.last_use <- time ;
    s.encrypt t.key data 

  let recv s t time data = 
    t.last_use <- time ;
    s.decrypt t.key data 

  let string_of_t t = 
    sprintf "#msgs=%d, status=%s" (Queue.length t.msgs) (string_of_status t.status)


  let freeze s re channels =
    let l = Hashtbls.to_list channels in
    List.map (fun (rank,ch) -> 
      Queue.clear ch.msgs ;
      let e = re rank in
      e,ch.end_time,ch.last_use,ch.key,ch.status
    ) l

  let unfreeze s er l h = 
    List.iter (fun (e,end_time,last_use,key,status) -> 
      let rank = er e in
      Hashtbls.add h rank ({
	end_time = end_time ;
	last_use = last_use ;
	key=key; 
	msgs=Queue.create (); 
	status=status 
      })
    ) l
      
  let getStatus t = t.status
  let setStatus t status = t.status <- status
  let getKey t = t.key
  let setKey t key = t.key <- key
  let getTime t = t.end_time
  let setTime t end_time = t.end_time <- end_time
  let getMsgs t = t.msgs

  (* Return the LRU channel. There are three cases:
   * 1. It is being opened. 
   *     Finish the open sequence and then close. 
   * 2. It is open.
   *    Initiate the close sequence. 
   * 3. It is being closed.
   *    Wait until it is fully closed.     
   *)
  let find_lru s hs =
    let min = ref None in
    Hashtbls.iter (fun rank ch -> 
	match !min with 
	  | None -> min := Some (rank,ch)
	  | Some (r',ch') -> 
	    if s.time_ge ch'.last_use ch.last_use then  min:=Some(rank,ch)
    ) hs;
    match !min with 
      | None -> None
      | Some(r,ch) -> 
	  match ch.status with 
	    | Closed 
	    | SemiOpen
	    | OpenBlocked -> None
	    | Open -> Some(r,ch)
	    | SemiShut 
	    | ShutBlocked -> None

end

(**************************************************************)
  
  
  
