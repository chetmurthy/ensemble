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
(* UNSIGNED: 16-byte MD5'd connection IDs. *)
(* Author: Mark Hayden, 3/97 *)
(* Rewritten by Ohad Rodeh 10/2001 *)
(**************************************************************)

val f : unit -> 
  (Trans.rank -> Obj.t option -> Trans.seqno -> Iovecl.t -> unit) Route.t
