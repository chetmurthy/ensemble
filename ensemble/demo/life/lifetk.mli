(**************************************************************)
(*
 *  Ensemble, (Version 0.70p1)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
(* This module controls the Tk interface to the application, via a *)
(* number of callbacks *)

(* Version 0, by Sam Weber *)

open Rules
open Msgs

  (* The callback that is called with the parameters of this execution. *)
  (* The arguments are:
       - x dimension of board
       - y dimension of board
       - the board
       - the number of generations to compute
  *)
val setStartCallback: (int->int->(int*int->bool)->int->unit)->unit

   (* Callback that is called when a cell's value is computed.  Should be *)
   (* called with the generation, the cell coordinate, and its value *)
val newCellValue: int->cellCoordinate->cell->unit

   (* Callback that is called when the view changes.  The argument is the *)
   (* number of endpoints in the new view. *)

val viewCount: (int->unit)

   (* The callback that is called by this module to get the list of all *)
   (* the cells computed in the stated generation *)
val setComputedCellsCallback: (int-> (cellCoordinate*cell) list) -> unit

   (* The callback that is called by this module to get the number of *)
   (* cells computed in the stated generation *)
val setNumberCellsComputedCallback: (int->int)->unit

   (* called to initialize this module *)
val init: unit->unit

