(**************************************************************)
(*
 *  Ensemble, 1.10
 *  Copyright 2001 Cornell University, Hebrew University
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
