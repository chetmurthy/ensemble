(**************************************************************)
(*
 *  Ensemble, 1.10
 *  Copyright 2001 Cornell University, Hebrew University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
open Ensemble
open Trans
open Appl_intf
open Rules

type cellCoordinate = int*int (* the co-oridinates of a life cell *)

type msg = 
  NumberOfGenerations of int   (* the number of generations we will compute *)
                               (* broadcast, master to slaves *)
 |YourCoordinates of cellCoordinate (* the coordinates of the cell *)
                                    (* pt2pt, master to slave *)
 |YourNeighbours of rank list   (* the neighbours of the cell *)
                               (* pt2pt, master to slave *)
 |InitValue of cell            (* a cell's initial val *)
                               (* pt2pt, master to slave *)
 |NeighbourValue of int*cell  (* the val of the cell in the stated *)
                               (* generation, sent to its neighbours *)
                               (* pt2pt, slave to slave *)
 |MyValue of (int*cellCoordinate*cell) (* the val of the cell in the *)
                                       (* stated generation, sent to master *)
                                       (* pt2pt, slave to master *)
 |Test of string               (* a val for testing *)

