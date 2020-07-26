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
(*let perf = "java Perf.class "*)

(*toggle_verbose ();; *)

let machines = ["hfs-build3"; "hfs-build4"];;
(*let machines = ["hfs-build3"];;*)

let run () = 
  connect machines;
  let results = rpc_uptime () in
  List.iter (fun (m,x) -> printf "%s: %1.2f\n" m x) results;
  
  (* Test that RPC-pattern of communication works *)
  rpc (fun i _ ->
    if i>=3 then Do_unit
    else 
      let s = sprintf "%s -prog 1-n -r 100000 -s 100 -add_prop Total" perf in
      Do_command (s)
  ) 20 [To_coord;Time; Num 2];
  
  ()  
;;
