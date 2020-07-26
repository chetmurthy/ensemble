(**************************************************************)
(*
 *  Ensemble, (Version 0.70p1)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
(**************************************************************)
(* ELONG.ML *)
(* Author: Mark Hayden, 12/96 *)
(**************************************************************)
open Mkutil
open Printf

let run () =
  let argv = Sys.argv in
  let nfiles = int_of_string argv.(1) in
  printf "nfiles=%d\n" nfiles ;
  
  let append = ref "" in
  for i = 0 to pred nfiles do
    let f = i + 2 in
    let file = argv.(f) in
    let ch = open_in_bin file in
    let lines = read_lines ch in
    close_in ch ;
    let s = String.concat " " lines in
    append := !append ^ " " ^ s
  done ;
  
  let com = Array.sub argv (nfiles + 2) (Array.length argv - nfiles - 2)  in
  let com = Array.to_list com in
  let com = String.concat " " com in
  let com = com ^ " " ^ !append in
  printf "executing: %s\n" com ;
  flush stdout ;

  let ret = Sys.command com in
  printf "exit value=%d\n" ret ;
  flush stdout

let _ = run ()
