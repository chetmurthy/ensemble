(**************************************************************)
(* APPL_OLD.ML *)
(* Author: Mark Hayden, 12/98 *)
(**************************************************************)
open Trans
open Util
open View
open Appl_intf open Old
(**************************************************************)
let name = Trace.file "APPL_OLD"
let failwith = Trace.make_failwith name
let log = Trace.log name
(**************************************************************)

let debug_msg_rank debug rank = eprintf "%s:%s(origin=%d)\n" name debug rank
let debug_msg debug = eprintf "%s:%s\n" name debug

let al al =
  Array.iter (function
    | Cast(_)       -> debug_msg "CAST"
    | Send(dests,_) -> debug_msg "SEND"
    | Send1(dest,_) -> debug_msg "SEND1"
    | Control o -> (
	match o with
	| Leave    -> debug_msg "LEAVE"
	| XferDone -> debug_msg "XFER_DONE"
	| Dump     -> debug_msg "DUMP"
	| Prompt   -> debug_msg "PROMPT"
	| Protocol p ->
	    let msg = sprintf "PROTOCOL:%s" (Proto.string_of_id p) in
	    debug_msg msg
	| _ -> ()
    )
  ) al ;
  al

(**************************************************************)

let iovl = ident

let debug debug intf =
  let recv_cast from msg =
    debug_msg_rank "RECV_CAST" from ;
    al (intf.recv_cast from msg)
  and recv_send from msg =
    debug_msg_rank "RECV_SEND" from ;
    al (intf.recv_send from msg)
  and block () =
    debug_msg "BLOCK" ;
    al (intf.block ())
  and heartbeat time =
    debug_msg (sprintf "HEARTBEAT(%s)" (Time.to_string time)) ;
    al (intf.heartbeat time)
  and block_recv_cast from msg =
    debug_msg_rank "BLOCK_RECV_CAST" from ;
    intf.block_recv_cast from msg
  and block_recv_send from msg =
    debug_msg_rank "BLOCK_RECV_SEND" from ;
    intf.block_recv_send from msg
  and block_view vf =
    debug_msg "BLOCK_VIEW" ;
    eprintf "APPL(BV):%s\n" (View.string_of_full vf) ;
    intf.block_view vf
  and block_install_view vf info =
    debug_msg "BLOCK_INSTALL_VIEW" ;
    intf.block_install_view vf info
  and unblock_view vf msg =
    debug_msg "UNBLOCK_VIEW" ;
(*
    eprintf "APPL:(view=%s)\n" (Endpt.string_of_id_list vs.View.view) ;
*)
    eprintf "APPL(UV):%s\n" (View.string_of_full vf) ;
    al (intf.unblock_view vf msg)
  and exit () =
    debug_msg "EXIT" ;
    intf.exit ()
  in {
    recv_cast           = recv_cast ;
    recv_send           = recv_send ;
    block               = block ;
    heartbeat           = heartbeat ;
    heartbeat_rate      = intf.heartbeat_rate ;
    block_recv_cast     = block_recv_cast ;
    block_recv_send     = block_recv_send ;
    block_view          = block_view ;
    block_install_view  = block_install_view ;
    unblock_view        = unblock_view ;
    exit                = exit
  }

(**************************************************************)

let full i =
  let cast_ma,cast_um   = Iovecl.make_marsh (Refcnt.info "full:cast" name) in
  let send_ma,send_um   = Iovecl.make_marsh (Refcnt.info "full:send" name) in
  let merge_ma,merge_um = Iovecl.make_marsh (Refcnt.info "full:merge" name) in
  let view_ma,view_um   = Iovecl.make_marsh (Refcnt.info "full:view" name) in
  let merge_ma1 = List.map (fun (rank,m) -> (rank,merge_ma m)) in
  let merge_um1 = List.map merge_um in

  let ta = action_array_map cast_ma send_ma in
  
  {
    recv_cast = (fun o m -> ta (i.recv_cast o (cast_um m))) ;
    recv_send = (fun o m -> ta (i.recv_send o (send_um m))) ;
    heartbeat = (fun t -> ta (i.heartbeat t)) ;
    heartbeat_rate = i.heartbeat_rate ;
    block = (fun () -> ta (i.block ())) ;
    block_recv_cast = (fun o m -> i.block_recv_cast o (cast_um m)) ;
    block_recv_send = (fun o m -> i.block_recv_send o (send_um m)) ;
    block_view = (fun v -> merge_ma1 (i.block_view v)) ;
    block_install_view = (fun v s -> view_ma (i.block_install_view v (merge_um1 s))) ;
    unblock_view = (fun vs m -> ta (i.unblock_view vs (view_um m))) ;
    exit = i.exit
  }

(**************************************************************)

let timed debug i =
  let time name f =
    let t0 = Time.gettimeofday () in
    let ret = f () in
    let t1 = Time.gettimeofday () in
    let diff = Time.sub t1 t0 in
    eprintf "APPL_OLD:TIMED:%s:%s:%s sec\n" debug name (Time.to_string diff) ;
    ret
  in
  
  { recv_cast = i.recv_cast ;
    recv_send = i.recv_send ;
    heartbeat = (fun t -> time "heartbeat" (fun () -> i.heartbeat t)) ;
    heartbeat_rate = i.heartbeat_rate ;
    block = i.block ;
    block_recv_cast = i.block_recv_cast ;
    block_recv_send = i.block_recv_send ;
    block_view = (fun v -> time "block_view" (fun () -> i.block_view v)) ;
    block_install_view = (fun v s -> time "block_install_view" (fun () -> i.block_install_view v s)) ;
    unblock_view = (fun v m -> time "unblock_view" (fun () -> i.unblock_view v m)) ;
    exit = i.exit
  }

(**************************************************************)

let iov mbuf i =
  let flatten iovl = Mbuf.flatten name mbuf iovl in
  let embed i = Iovecl.of_iovec name i in
  let ta = action_array_map embed embed in
  {
    recv_cast = (fun o m -> ta (i.recv_cast o (flatten m))) ;
    recv_send = (fun o m -> ta (i.recv_send o (flatten m))) ;
    heartbeat = (fun t -> ta (i.heartbeat t)) ;
    heartbeat_rate = i.heartbeat_rate ;
    block = (fun () -> ta (i.block ())) ;
    block_recv_cast = (fun o m -> i.block_recv_cast o (flatten m)) ;
    block_recv_send = (fun o m -> i.block_recv_send o (flatten m)) ;
    block_view = (fun v -> List.map (fun (a,b) -> (a,(embed b))) (i.block_view v)) ;
    block_install_view = (fun v s -> 
      let s = List.map flatten s in
      embed (i.block_install_view v s)) ;
    unblock_view = (fun vs m -> ta (i.unblock_view vs (flatten m))) ;
    exit = i.exit
  }

(**************************************************************)

let _ =
  Elink.put Elink.appl_old_full full ;
  Elink.put Elink.appl_old_debug debug ;
  Elink.put Elink.appl_old_timed timed ;
  Elink.put Elink.appl_old_iov iov

(**************************************************************)
