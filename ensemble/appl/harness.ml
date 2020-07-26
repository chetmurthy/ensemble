(**************************************************************)
(*
 *  Ensemble, (Version 0.70p1)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)


let 

let manager upcall =
  let time_per_test = Arge.get Arge.time_per_test () in
  
  Trace.add_log "ARGEU" (fun info dbg -> eprintf "setenv %s" dbg) ;
  
    

  

  Trace.log (

let trace name =
  let name = String.uppercase name in
  let f info dbg =
    if info = "" then 
      eprintf "%s\n" (String.concat ":" [name;dbg])
    else 
      eprintf "%s\n" (String.concat ":" [name;info;dbg])
  in
  Trace.add_log name f
