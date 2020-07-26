(**************************************************************)
(*
 *  Ensemble, 2_00
 *  Copyright 2004 Cornell University, Hebrew University
 *           IBM Israel Science and Technology
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
#load "str.cma"
#load "unix.cma"
#load "auxl.cmo"
#load "coord.cmo";;

open Str
open Unix
open Auxl
open Coord
open Printf;;


let base = 
  try Sys.getenv "ENS_ABSROOT"
  with Not_found ->
    printf "You must set the ENS_ABSROOT environment variable for this 
      program to work\n";
    exit 1

let perf = base ^ "/bin/i386-linux/c_perf"

(*toggle_verbose ();; *)

let machines = ["hfs-build3"; "hfs-build4"];;

let _ = 
  connect machines;
  let results = rpc_uptime () in
  List.iter (fun (m,x) -> printf "%s: %1.2f\n" m x) results;

  rpc (fun i _ ->
    if i>=2 then Do_unit
    else 
      let s = sprintf "%s -modes DEERING -prog 1-n -num_msgs 10000 -s 1000 -n 2" perf in
      Do_command (s)
  ) 10 [To_coord;Time];
  ()
;;
