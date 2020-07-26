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
(* STACK_ID.ML *)
(* Author: Mark Hayden, 3/96 *)
(**************************************************************)
let name = Trace.file "STACK_ID"
let failwith = Trace.make_failwith name
(**************************************************************)

type t =
  | Primary
  | Bypass
  | Gossip
  | Unreliable

let mapping = [|
  "Primary", Primary ;
  "Gossip", Gossip ;
  "Unreliable", Unreliable ;
  "Bypass", Bypass
|] 

let id_of_string s = Util.id_of_string name mapping s
let string_of_id i = Util.string_of_id name mapping i
