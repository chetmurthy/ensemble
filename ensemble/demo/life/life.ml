(**************************************************************)
(*
 *  Ensemble, (Version 1.00)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
open Ensemble
open Tk
open Master 
open Slave
open Rules
open Msgs
open Appl
open Transport
open Proto
open Arge
open Domain
open View

let run () = 
  Lifetk.init ();
  Arge.set_string Arge.alarm "Tk" ;

  Arge.parse [] (Arge.badarg "Life") "" ;

  (* Set up all the callbacks between parts of the application *)

  setExitFunc Collector.masterExit;
  setCellValueFunc Collector.masterCellValue;
  setViewFunc Collector.masterViewChange;
  Lifetk.setComputedCellsCallback Collector.cellsComputed;
  Lifetk.setNumberCellsComputedCallback Collector.numberCellsComputed;
  Lifetk.setStartCallback 
     (fun xdim ydim board gens ->
        Collector.start gens;
        Master.startMaster xdim ydim board gens);

  Collector.setCellValueCallback Lifetk.newCellValue;
  Collector.setMasterViewChangeFunc Lifetk.viewCount;
  Collector.start 5;
  
  let make_view_state () =
    Appl.default_info "life"
  in

  let ls,master_view_state = make_view_state () in
  let master_endpt = ls.endpt in

  (* the function to make a slave endpoint *)
  (* to run on multiple machines:
       rsh process & add command line argument 
   *)
  let makeslave () = 
    let view_state = make_view_state () in
    let interface = initSlave master_endpt (Time.of_int 1) in
    Appl.config interface view_state ;
    Elink.get "LIFE" Elink.htk_init (Elink.alarm_get_hack ())
  in

  let interface = init master_endpt makeslave (Time.of_int 1) in

  Appl.config interface (ls,master_view_state) ;

  (* actually start the application *)
  Elink.get "LIFE" Elink.htk_init (Elink.alarm_get_hack ()) ;
  Tk.mainLoop ()

(**************************************************************)
(* Run the application, with exception handlers to catch any
 * problems that might occur.
 *)
let _ = Printexc.catch run ()

(* Flush output and exit the process.
 *)
let _ = exit 0
