(**************************************************************)
(*
 *  Ensemble, (Version 0.70p1)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
open Rules
open Msgs

let genCounts = ref [||]

let computedCells = ref [||]

let cellValueCallback = ref (fun g xy c -> ())

let masterViewCallback = ref (fun v -> ())

let masterEndCallback = ref (fun () -> ())

let start g =
  genCounts := Array.create (g+1) 0;
  computedCells := Array.create (g+1) [];
  ()

let masterCellValue g xy c =
  !genCounts.(g)<- !genCounts.(g)+1;
  !computedCells.(g)<- (xy,c) :: !computedCells.(g);
  !cellValueCallback g xy c

let masterViewChange vc =
  !masterViewCallback vc

let masterExit () = !masterEndCallback ()

let setCellValueCallback cb = cellValueCallback := cb

let setMasterViewChangeFunc cb = masterViewCallback := cb

let setMasterEndFunc cb = masterEndCallback := cb

let numberCellsComputed g = !genCounts.(g)

let cellsComputed g = !computedCells.(g)

