(**************************************************************)
(*
 *  Ensemble, 1.10
 *  Copyright 2001 Cornell University, Hebrew University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
(**************************************************************)
(* HANDLE.ML: application interface *)
(* Author: Mark Hayden, 10/97 *)
(**************************************************************)
open Trans
open Util
open View
(**************************************************************)
let name = Trace.file "HANDLE"
let failwith = Trace.make_failwith name
let log = Trace.log name
(**************************************************************)

module Old = struct
  open Appl_handle open Old

let f i =
  let view = ref (Arrayf.of_array [||]) in
  let handles = ref (Arrayf.of_array [||]) in

  let handle_of_rank rank =
    if rank < 0 then
      failwith "negative rank" ;
    if rank >= Arrayf.length !handles then
      failwith "rank too large" ;
    Arrayf.get !handles rank
  in

  let rank_of_endpt endpt =
    try
      Arrayf.index endpt !view
    with Not_found ->
      eprintf "HANDLE:got invalid endpt\n" ;
      (-1)
  in

  let rank_of_handle handle =
    let rank = handle.rank in
    if rank >= 0 
    && rank < Arrayf.length !view
    && Arrayf.get !view rank == handle.endpt then (
      rank
    ) else (
      let endpt = handle.endpt in
      try
        let rank = Arrayf.index endpt !view in
        handle.rank <- rank ;
	handle.endpt <- Arrayf.get !view rank ;
	rank
      with Not_found ->
        eprintf "HANDLE:got invalid endpt\n" ;
        (-1)
    )
  in

  let action_map = function
    | Cast m -> Appl_intf.Cast(m)
    | Send(handles,m) -> 
	let dests = Array.map rank_of_handle handles in
	if array_mem (-1) dests then
	  Appl_intf.Send([|-1|],m)
	else
	  Appl_intf.Send(dests,m)
    | Control o -> Appl_intf.Control o
  in

  let action_array_map actions = 
    let actions = Array.map action_map actions in
    let actions =
      array_filter (function
      	| Appl_intf.Send(dests,_) when dests = [|-1|] -> false
      	| _ -> true
      ) actions
    in
    actions
  in    

  let ta = action_array_map in

  let block_view ((_,vs) as vf) =
    view := vs.View.view ;
    handles := Arrayf.map (handle () "HANDLE:handler") vs.View.view ;
    let merge = i.block_view vf in
    List.map (fun (endpt,merge_msg) -> ((rank_of_endpt endpt),merge_msg)) merge
  in

  (* Just in case ...
   *)
  let unblock_view ((_,vs) as vf) m =
    view := vs.View.view ;
    handles := Arrayf.map (handle () "HANDLE:handler") vs.View.view ;
    i.unblock_view vf m
  in
  
  let interface = {
    Appl_intf.Old.recv_cast = (fun o m -> ta (i.recv_cast (handle_of_rank o) m)) ;
    Appl_intf.Old.recv_send = (fun o m -> ta (i.recv_send (handle_of_rank o) m)) ;
    Appl_intf.Old.heartbeat = (fun t -> ta (i.heartbeat t)) ;
    Appl_intf.Old.heartbeat_rate = i.heartbeat_rate ;
    Appl_intf.Old.block = (fun () -> ta (i.block ())) ;
    Appl_intf.Old.block_recv_cast = (fun o m -> i.block_recv_cast (handle_of_rank o) m) ;
    Appl_intf.Old.block_recv_send = (fun o m -> i.block_recv_send (handle_of_rank o) m) ;
    Appl_intf.Old.block_view = block_view ;
    Appl_intf.Old.block_install_view = (fun v s -> i.block_install_view v s) ;
    Appl_intf.Old.unblock_view = (fun vs m -> ta (i.unblock_view vs m)) ;
    Appl_intf.Old.exit = i.exit
  } in
  
  (),interface

end

module New = struct
  open Appl_handle open New

let f i =
  let install ((ls,vs) as vf) =
    let view = vs.view in
    let nmembers = ls.nmembers in
    let handles = Arrayf.map (handle_hack name) view in

    let handle_of_rank rank =
      if rank < 0 then
	failwith "negative rank" ;
      if rank >= ls.nmembers then
	failwith "rank too large" ;
      Arrayf.get handles rank
    in

    let rank_of_handle handle =
      let rank = handle.rank in
      if rank >= 0 
      && rank < nmembers 
      && Arrayf.get view rank == handle.endpt 
      then (
	rank
      ) else (
	let endpt = handle.endpt in
	try
	  let rank = Arrayf.index endpt view in
	  handle.endpt <- Arrayf.get view rank ;
	  handle.rank <- rank ;
	  rank
	with Not_found ->
	  eprintf "HANDLE:got invalid endpt\n" ;
	  (-1)
      )
    in

    let map a =
      Array.map (function
	| Cast m -> Appl_intf.Cast m
	| Send(handles,m) -> 
	    let dests = Array.map rank_of_handle handles in
	    if array_mem (-1) dests then
	      Appl_intf.Send([|-1|],m)
	    else
	      Appl_intf.Send(dests,m)
	| Control o -> Appl_intf.Control o
      ) a
    in
    let actions,handlers = i.install vf handles in
    let actions = map actions in

    let receive o b cs =
      let o = handle_of_rank o in
      let handler = handlers.receive o b cs in
      let handler m =
      	map (handler m)
      in handler
    in
    
    let block () =
      map (handlers.block ())
    in

    let heartbeat t =
      map (handlers.heartbeat t)
    in

    let handlers = { 
      Appl_intf.New.flow_block = (fun _ -> ());
      Appl_intf.New.heartbeat = heartbeat ;
      Appl_intf.New.receive = receive ;
      Appl_intf.New.block = block ;
      Appl_intf.New.disable = handlers.disable
    } in
    
    actions,handlers
  in 
  
  (),{ Appl_intf.New.heartbeat_rate = i.heartbeat_rate ;
    Appl_intf.New.install = install ;
    Appl_intf.New.exit = i.exit }

end

let old_f = Old.f
let new_f = New.f

let _ = 
  Elink.put Elink.appl_handle_old old_f ;
  Elink.put Elink.appl_handle_new new_f
