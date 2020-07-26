(**************************************************************)
(*
 *  Ensemble, 1.10
 *  Copyright 2001 Cornell University, Hebrew University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
open Rules
open Msgs


let intlist2string l = List.fold_left (fun x y -> x^" "^y) "" (List.map string_of_int l)

let cell2string = function Live -> "live"
                   |  Dead -> "dead"
                   |  Bottom -> "bottom"

let msg2string = function (NumberOfGenerations i) -> "NumberOfGenerations "^
                                                   (string_of_int i)
                  |  (YourCoordinates (x,y)) -> "YourCoordinates ("^
                                                   (string_of_int x)^","^
                                                   (string_of_int y)^")"
                  |  (YourNeighbours rl) -> "YourNeighbours"^
                                             (intlist2string rl)
                  |  (InitValue c) -> "InitValue "^(cell2string c)
                  |  (NeighbourValue (i,c)) -> "NeighbourValue "^
                                             (string_of_int i)^" "^
                                             (cell2string c)
                  |  (MyValue  (g,(x,y),c)) -> "MyValue "^(string_of_int g)^" "^
                                                  (string_of_int x)^","^
                                                   (string_of_int y)^") "^
                                                   (cell2string c)
                  |  (Test s) -> "Test "^s

