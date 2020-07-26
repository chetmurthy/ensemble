open Str
open Unix
open Auxl
open Coord
open Printf


(*toggle_verbose ();; *)

(*
and rh = ["rh-01";"rh-02";"rh-03";"rh-04";"rh-05";"rh-07";"rh-09";"rh-12";"rh-13";"rh-15";"rh-16";"rh-18"]
and pr = ["pr-01";"pr-05";"pr-07";"pr-08";"pr-09";"pr-11";"pr-13"(*;"pr-16"*);"pr-18";"pr-19";"pr-20"]
and apollo= [(*"apollo-1";*)"apollo-2"(*;"apollo-3";"apollo-4"*)] 
and pomela = [(*"pomela1";*)"pomela2"(*;"pomela3"*);"pomela4"] 
and other = ["halva";"inferno-01"(*;"hamster"*);"limon2"; "tapuz1"]
and par = ["par1";"par2";"par3";"par4";"par5";"par6";"par7";"par8";
           "par9";"par10";"par11";"par12";"par13";"par14";"par15";"par16"]
*)

let machines = [(*"hfstore2";*) "hfstore3"];;

let _ = 
  connect machines;
  let results = rpc_uptime () in
  List.iter (fun (m,x) -> printf "%s: %1.2f\n" m x) results;
  ()


