(**************************************************************)
(*
 *  Ensemble, 1.10
 *  Copyright 2001 Cornell University, Hebrew University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
(* This module controls the master endpoint, which is responsible for *)
(* the entire computation *)

(* Version 0, by Sam Weber *)

open Ensemble
open Rules
open Msgs

(* The type of boards passed in.  This type is a function from x,y *)
(* coordinates to whether the cell is live or dead.  The master is *)
(* guaranteed not to attempt to evaluate any board beyond the bounds *)
(* established in the startmaster call *)

type board = int * int -> bool

(* The callback which is called when the value of a cell is computed *)
(* The parameters are, in order:
    -- the generation
    -- the cell coordinates
    -- the state of the cell
*)

val setCellValueFunc: (int->(int*int)->cell->unit)->unit

(* The callback which is called whenever the view changes.  The argument *)
(* is the number of endpoints in the new view *)

val setViewFunc: (int -> unit) -> unit

(* The function that is called when the computation finishes *)

val setExitFunc: (unit->unit)->unit

(* The function that initializes the module.  It must be called before *)
(* startMaster.  The arguments are:
  -- the master endpoint id
  -- a function that creates a new slave endpoint
  -- a Time.t, used to create an application interface
 and the return value is an application interface.
*)

val init: Endpt.id -> (unit -> unit) -> Time.t -> Appl_intf.Old.t

(* startMaster starts the computation                        *)
(*      startMaster xdim ydim board generations              *)
(* starts the computation with a xdim by ydim world, with    *)
(* initial configuration given by board, and computes        *)
(* "generations" generations.                                *)

val startMaster: int -> int -> board -> int -> unit
