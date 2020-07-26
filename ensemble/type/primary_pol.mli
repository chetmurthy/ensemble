(**************************************************************)
(* PRIMARY_POL.ML *)
(* Author: Mark Hayden, Zhen Xiao, 5/97 *)
(**************************************************************)

type t = 
  | Quorum of int
  | Resource of Endpt.id list
  | 
