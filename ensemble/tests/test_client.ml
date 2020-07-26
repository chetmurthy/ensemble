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


let run_test props = 
  let perf = perf ^ " -add_prop " ^ props ^ " " in
  (* Test that RPC-pattern of communication works *)
  rpc (fun i _ ->
    if i>=3 then Do_unit
    else 
      let s = sprintf "%s -prog rpc -r 10000 -s 100" perf in
      Do_command (s)
  ) 20 [To_coord;Time; Num 2];

  (* Test that throughput holds *)
  rpc (fun i _ ->
    if i>=4 then Do_unit
    else 
      let s = sprintf "%s -prog 1-n -r 10000 -s 4000 -n 4" perf in
      Do_command (s)
  ) 100 [To_coord;Time; Num 4];


  (* Test fragmentation *)
  rpc (fun i _ ->
    if i>=4 then Do_unit
    else 
      let s = sprintf "%s -prog 1-n -r 1000 -s 20000 -n 4" perf in
      Do_command (s)
  ) 100 [To_coord;Time; Num 4];

  (* Test with several groups *)
  rpc (fun i _ ->
    match i with
      | 0 | 1 -> 
	  Do_command(sprintf "%s -prog 1-n -r 4000 -s 2000 -n 2 -group G_1" perf)
      | 2 | 3 -> 
	  Do_command(sprintf "%s -prog rpc -r 10000 -s 500 -n 2 -group G_2" perf)
      | 4 | 5 -> 
	  Do_command(sprintf "%s -prog 1-n -r 1000 -s 10000 -n 2 -group G_3" perf)
      | _ -> Do_unit
  ) 120 [To_coord;Time; Num 6];

  (* Test with several groups *)
  rpc (fun i _ ->
    match i with
      | 0 | 1 -> 
	  Do_command(sprintf "%s -prog 1-n -r 4000 -s 2000 -n 4 -group G_1" perf)
      | 2 | 3 -> 
	  Do_command(sprintf "%s -prog rpc -r 10000 -s 500 -n 2 -group G_2" perf)
      | 4 | 5 -> 
	  Do_command(sprintf "%s -prog 1-n -r 1000 -s 10000 -n 4 -group G_3" perf)
      | 6 | 7 -> 
	  Do_command(
	    sprintf "%s -prog 1-n -r 4000 -s 2000 -n 4 -group G_1 -port 7000" perf)
      | 8 | 9 -> 
	  Do_command(
	    sprintf "%s -prog 1-n -r 1000 -s 10000 -n 4 -group G_3 -port 7000" perf)
      | _ -> Do_unit
  ) 150 [To_coord;Time; Num 12];

  ()


let run () = 
  connect machines;
  let results = rpc_uptime () in
  List.iter (fun (m,x) -> printf "%s: %1.2f\n" m x) results;

  run_test "Vsync";
  run_test "Vsync:Scale";
  run_test "Vsync:Total";
  run_test "Vsync:Total:Scale";

(*
  run_test "Vsync:Auth";
  run_test "Vsync:Scale:Auth"
  run_test "Vsync:Total:Auth";
  run_test "Vsync:Total:Scale:Auth"
*)
;;
