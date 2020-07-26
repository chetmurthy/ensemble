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
(* RNG.ML *)
(* Author: Ohad Rodeh, 10/98 *)
(**************************************************************)
external seed : string -> unit
  = "rngml_Seed"
external rnd : unit -> int
  = "rngml_rnd"




