(**************************************************************)
(*
 *  Ensemble, 1_42
 *  Copyright 2003 Cornell University, Hebrew University
 *           IBM Israel Science and Technology
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
(**************************************************************)
(* BYPASS: Optimized bypass router *)
(* Author: Mark Hayden, 3/97 *)
(**************************************************************)

val f : unit -> (Trans.rank -> Trans.seqno -> Iovecl.t -> unit) Route.t
