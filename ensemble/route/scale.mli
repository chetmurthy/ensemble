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
(* SCALE: Slow, 16-byte MD5'd connection IDs. *)
(* Author: Mark Hayden, 3/97 *)
(**************************************************************)

val f : Mbuf.t -> (Trans.rank -> Obj.t option -> int -> Iovecl.t -> unit) Route.t
