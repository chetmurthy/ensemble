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
(* ISAAC.ML *)
(* Author: Ohad Rodeh, 11/98 *)
(**************************************************************)
open Ensemble
open Shared

external isaacml_Init : Buf.t -> Prng.context
  = "isaacml_Init"
external isaacml_Rand : Prng.context -> Buf.t -> unit
  = "isaacml_Rand"

let _ = 
  let rand ctx = 
    let s = Buf.create Buf.len4 in
    isaacml_Rand ctx s;
    s
  in

  Prng.install "ISAAC" isaacml_Init rand




