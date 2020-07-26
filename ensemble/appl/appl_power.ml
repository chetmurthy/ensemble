(**************************************************************)
(* APPL_POWER.ML *)
(* Author: Mark Hayden, 12/98 *)
(**************************************************************)
open Util
open View
open Appl_intf
(**************************************************************)
let name = Trace.file "APPL_POWER"
let failwith s = Trace.make_failwith name s
let log = Trace.log name
(**************************************************************)

open Old
let oldf mbuf i =
  let cast_ma,cast_um = Elink.get_powermarsh_f name "APPL_POWER:Old:cast" mbuf in
  let send_ma,send_um = Elink.get_powermarsh_f name "APPL_POWER:Old:send" mbuf in
  let merge_ma,merge_um = Iovecl.make_marsh "APPL_POWER:Old:merge" in
  let view_ma,view_um = Iovecl.make_marsh "APPL_POWER:Old:view" in
  let merge_ma1 = List.map (fun (rank,m) -> (rank,merge_ma m)) in
  let merge_um1 =
    List.map merge_um
  in

  let ta = action_array_map cast_ma send_ma in
  let recv_cast o m =
    let (_,iov) as m = cast_um m in
    let act = i.recv_cast o m in
    ta act
  in
  let recv_send o m =
    let (_,iov) as m = send_um m in
    let act = i.recv_send o m in
    ta act
  in
  let block_recv_cast o m = 
    let (_,iov) as m = cast_um m in
    i.block_recv_cast o m ;
  in
  let block_recv_send o m = 
    let (_,iov) as m = send_um m in
    i.block_recv_send o m ;
  in

  {
    recv_cast = recv_cast ;
    recv_send = recv_send ;
    heartbeat = (fun t -> ta (i.heartbeat t)) ;
    heartbeat_rate = i.heartbeat_rate ;
    block = (fun () -> ta (i.block ())) ;
    block_recv_cast = block_recv_cast ;
    block_recv_send = block_recv_send ;
    block_view = (fun v -> merge_ma1 (i.block_view v)) ;
    block_install_view = (fun v s -> view_ma (i.block_install_view v (merge_um1 s))) ;
    unblock_view = (fun vs m -> ta (i.unblock_view vs (view_um m))) ;
    exit = i.exit
  }

open New
let newf mbuf i =
  let debug = "APPL_POWER.New" in
  let powermarsh_f = Elink.get_powermarsh_f name in
  let ma,um = powermarsh_f debug mbuf in
  let ta = action_array_map ma ma in

  let install vf =
    let actions,handlers = i.install vf in
    let actions = ta actions in
    let receive o b cs =
      let receive = handlers.receive o b cs in
      fun m -> ta (receive (um m))
    in
    
    let block () =
      ta (handlers.block ())
    in

    let heartbeat t =
      ta (handlers.heartbeat t)
    in

    let handlers = { 
      flow_block =handlers.flow_block ;
      heartbeat = heartbeat ;
      receive = receive ;
      block = block ;
      disable = handlers.disable
    } in
    
    actions,handlers
  in 
  
  { heartbeat_rate = i.heartbeat_rate ;
    install = install ;
    exit = i.exit }

(**************************************************************)

let _ =
  Elink.put Elink.appl_power_oldf oldf ;
  Elink.put Elink.appl_power_newf newf

(**************************************************************)
