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
(* NETSIM.ML *)
(* Author: Mark Hayden, 4/95 *)
(**************************************************************)
open Util
open Trans
open Buf
(**************************************************************)
let name = Trace.file "NETSIM"
let failwith s = Trace.make_failwith name s
(**************************************************************)
(*
let _ =
  Trace.install_root (fun () ->
    eprintf "  NETSIM:alarm:priq:size=%d\n" (Priq.size alarms) ;
(*
    eprintf "    priq:min=%s\n" (Time.to_string (Priq.min alarms)) ;
    List.iter (fun (time,_) ->
      eprintf "      time=%s\n" (Time.to_string time)
    ) (Priq.to_list alarms)
*)
  )
*)
(**************************************************************)

module Priq = Priq.Make ( Time.Ord )

let alarm ((unique,sched,async,handlers,mbuf) as gorp) =
  let alarms = 
    let table = Priq.create (fun _ -> failwith "priq:sanity") in
    Trace.install_root (fun () ->
      [sprintf "NETSIM:alarms:priq size=%d" (Priq.size table)]
    ) ;
    table
  in
  let time = ref (Time.of_int 1) in
  let count = ref 0 in

  let gettime () = !time in

  let check () =
(*
    eprintf "NETSIM:checking:size=%d:time=%s:min=%s\n" 
      (Priq.size alarms) 
      (Time.to_string !time)
      (Time.to_string (Priq.min alarms)) ;
*)
    Priq.get alarms (fun _ callback ->
      incr count ;
      if !verbose && (!count mod 1000) =| 0 then (
        eprintf "NETSIM:events scheduled=%d, time=%s\n"
      	  !count (Time.to_string !time)
      ) ;
      callback !time
    ) !time
  in
  let min () = Priq.min alarms in

  let alarm callback =
    let disable () = () in
    let schedule time =
      Priq.add alarms time callback
    in Alarm.c_alarm disable schedule
  in

  let small = Time.of_string "0.00001" in
  let block () =
    let newtime =
      let next = Priq.min alarms in
      if Priq.size alarms =| 0 || next < !time then
      	!time
      else
        next
    in
    
    (* Set the time, plus a little.
     *)
    time := Time.add newtime small
  in

  let poll_f = ref None in
  let alm_poll b = 
    match !poll_f with
    | Some f -> f b
    | None -> b
  in

  let add_sock_recv _ = failwith "add_sock_recv"
  and rmv_sock_recv _ = failwith "rmv_sock_recv"
  and add_sock_xmit _ = failwith "add_sock_xmit"
  and rmv_sock_xmit _ = failwith "rmv_sock_xmit"
  and add_poll n p = poll_f := Alarm.alm_add_poll n p
  and rmv_poll n = poll_f := Alarm.alm_rmv_poll n
  and poll _ _ = alm_poll false
  in Alarm.create
    name
    gettime
    alarm
    check
    min
    add_sock_recv
    rmv_sock_recv 
    add_sock_xmit
    rmv_sock_xmit
    block
    add_poll
    rmv_poll
    poll
    gorp

(**************************************************************)

let domain alarm =
  let hundredth = Time.of_string "0.01" in
  let mbuf = Alarm.mbuf alarm in
  let msgs = Priq.create Iovecl.empty in
  let ready = Queuee.create () in
  let gettime () = Alarm.gettime alarm in
  let handlers = Alarm.handlers alarm in
  let deliver _ msg = Queuee.add msg ready in

  let poll gm =
    ignore (Priq.get msgs deliver (gettime ())) ;
    match Queuee.takeopt ready with
    | None -> gm
    | Some iovl ->
	Route.deliver_iovl handlers mbuf iovl ;
	true
  in

  let addr _ = Addr.NetsimA
  and enable _ _ _ _ =
    Alarm.add_poll alarm name poll ;
    let disable () = 
      Alarm.rmv_poll alarm name    
    and xmit = function
    | Domain.Pt2pt(a) when a = Arrayf.empty -> None
    | _ ->
	let enqueue iovl =
	  let time = Time.add (gettime ()) hundredth in
	  Priq.add msgs time iovl
	in
	let x buf ofs len =
	  let iov = Mbuf.allocl name mbuf buf ofs len in
	  enqueue iov
	and xv iov =
	  enqueue iov
	and xvs iov s =
	  let iov = Iovecl.take name iov in
	  let slen = Buf.length s in
	  let iovs = Mbuf.alloc name mbuf s len0 slen in
	  let iov = Iovecl.appendi name iov iovs in
	  enqueue iov
	in
	Some(x,xv,xvs)
    in
    Domain.handle disable xmit
  in

  Domain.create name addr enable

(**************************************************************)

let _ =
  Elink.put Elink.netsim_domain domain ;
  Elink.put Elink.netsim_alarm alarm

(**************************************************************)
