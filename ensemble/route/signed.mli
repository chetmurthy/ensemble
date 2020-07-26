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
(* SIGNED router *)
(* Author: Mark Hayden, 3/97 *)
(**************************************************************)

val f : Mbuf.t -> (Obj.t option -> int -> Iovecl.t -> unit) Route.t
