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
(* BYPASS: Optimized bypass router *)
(* Author: Mark Hayden, 3/97 *)
(**************************************************************)

val f : Mbuf.t -> (int -> Iovecl.t -> unit) Route.t
