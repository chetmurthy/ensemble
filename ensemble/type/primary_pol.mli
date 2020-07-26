(**************************************************************)
(*
 *  Ensemble, (Version 1.00)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
(**************************************************************)
(* PRIMARY_POL.ML *)
(* Author: Mark Hayden, Zhen Xiao, 5/97 *)
(**************************************************************)

type t = 
  | Quorum of int
  | Resource of Endpt.id list
  | 
