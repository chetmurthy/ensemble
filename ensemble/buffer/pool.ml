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
(* POOL.ML *)
(* Author: Mark Hayden, 10/97 *)
(**************************************************************)
open Util
(**************************************************************)
let name = Trace.file "POOL"
let failwith s = Trace.make_failwith name s
let log = Trace.log name
(**************************************************************)
(*
module Weak = struct
  type 'a t = 'a option array
  let create l = array_create name l None
  let set a i o = Array.set a i o
  let get a i = Array.get a i
end
*)
(**************************************************************)

(* If we use a Stack the resident set size should be small,
 * though with a Queue, things should be safer.
 *)
let _ = Queuee.create			(* for dependency *)
module Freelist = Queuee
(*
let fl_add = Freelist.push
let fl_take = Freelist.pop
let fl_length = Freelist.length
*)
let fl_add = Freelist.add
let fl_take = Freelist.takeopt
let fl_length = Freelist.length

(**************************************************************)

type nlive = int
type nfree = int

(**************************************************************)

type 'a t = {
  alloc : unit -> 'a ;
  free : 'a -> unit ;
  make : nlive -> nfree -> 'a list ;
  fl : 'a Freelist.t ;
  mutable alive : ('a Refcnt.root Weak.t * 'a) list ;
  mutable actually_use_counts : bool ;
  mutable force_major_gc : bool
}    

(**************************************************************)

let create name alloc free make = {
  alloc = alloc ;
  free = free ;
  make = make ;
  fl = Freelist.create () ;
  alive = [] ;
  actually_use_counts = false ;
  force_major_gc = true
}

(**************************************************************)
let actually_use_counts p b = p.actually_use_counts <- b
let force_major_gc p b = p.force_major_gc <- b
(**************************************************************)

let rec compact p =
  match fl_take p.fl with
  | None -> ()
  | Some i -> 
      p.free i ;
      compact p

(**************************************************************)

let nbufs p =
  (List.length p.alive) + (fl_length p.fl)

(**************************************************************)

let info p =
  sprintf "{Pool:alive=%d;free=%d}" 
    (List.length p.alive) (fl_length p.fl)

(**************************************************************)
(* Scan through live buffers looking for freed buffers to
 * add to the free list.  
 *)
let is_live p s =
  if not (Hsys.weak_check s 0) then (
    false 
  ) else if not p.actually_use_counts then (
    true
  ) else (
      match Weak.get s 0 with
      |	None -> false
      |	Some handle ->
	  Refcnt.count name handle > 0
  )

let clean p =
  let recovered = ref 0 in
  let total = ref 0 in
  p.alive <-
    List.fold_left (fun acc ((handle,obj) as item) ->
      incr total ;
      if is_live p handle then 
	item :: acc
      else (
	incr recovered ;
	fl_add obj p.fl ;
	acc 
      )
    ) [] p.alive ;
  log (fun () -> sprintf "recovered %d/%d buffers" !recovered !total)

(**************************************************************)

let use_gc p =
  (* If still empty, then:
   *)
  let nlive = List.length p.alive in
  log (fun () -> sprintf "Gc.full_major: total alive=%d" nlive) ;
  Gc.full_major () ;		(* Do a full GC *)
  clean p ;			(* And grab our buffers *)
(*  
  log (fun () -> sprintf "Gc:alive=%s"
    (string_of_list (fun (wr,_) -> string_of_option Refcnt.to_string (Weak.get wr 0)) p.alive)) ;
*)
  (* Figure out current state and call the policy function.
   *)
  let live = List.length p.alive in
  let free = Freelist.length p.fl in
  let l = p.make live free in
  log (fun () -> sprintf "alloced %d" (List.length l)) ;
  
  (* Ensure that there will be at least one buffer in
   * the free list.  
   *)
  if free = 0 && l = [] then 
    failwith "bad policy function" ;
  
  (* Add the new buffers and take one out.
   *)
  List.iter (fun o -> fl_add o p.fl) l ;

  match fl_take p.fl with
  | None -> failwith sanity
  | Some a -> a

(**************************************************************)

let alloc debug p =
  let obj =
  (* First check the free list.
   *)
    match fl_take p.fl with Some a -> a
    | None ->
      (* If empty, then collect any freed buffers.
       *)
      clean p ;
      match fl_take p.fl with Some a -> a
      |	None ->
	if p.force_major_gc then (
	  use_gc p
	) else (
	  p.alloc()
	)
  in
  let weak,first = 
    let weak = Weak.create 1 in
    (* This next step has to allocate an object.
     *)
    let (root,first) = Refcnt.create name obj in
    Weak.set weak 0 (Some root) ;
    (weak,first)
  in
  p.alive <- (weak,obj) :: p.alive ;
  first

let grow p n =
  for i = 1 to n do
    fl_add (p.alloc()) p.fl
  done

let debug p = 
  let l =
    List.map (fun (ww,_) ->
      match Weak.get ww 0 with
      |	Some h ->
	  let count = Refcnt.count name h in
	  if count > 0 then
	    Some(sprintf "count=%d" count)
	  else None
      |	None -> None
    ) p.alive
  in filter_nones l
  
(**************************************************************)
