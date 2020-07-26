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
(* CONFIG_TRANS.ML *)
(* Author: Mark Hayden, 10/96 *)
(**************************************************************)
open Trans
open Buf
open Util
open Layer
open View
(**************************************************************)
let name = Trace.file "CONFIG_TRANS"
let failwith = Trace.make_failwith name
(**************************************************************)
let name_send = "CONFIG_TRANS(send)"
let name_cast = "CONFIG_TRANS(cast)"
let name_recv = "CONFIG_TRANS(recv)"
let name_mrge = "CONFIG_TRANS(mrge)"
let name_goss = "CONFIG_TRANS(goss)"
(**************************************************************)

let gossip_marsh mbuf =
  let marsh,unmarsh,_ = Mbuf.make_marsh name mbuf in
  let pack_gossip ev =
    let exchange = Event.getExtender
      (function Event.ExchangeGos(a) -> (Some (Some (a))) | _ -> None)
      None ev
    in

    let switch = Event.getExtender
      (function Event.SwitchGos(a,b,c) -> (Some (Some (a,b,c))) | _ -> None)
      None ev
    in

    let heal = Event.getExtender
      (function Event.HealGos(a,b,c,d,e) -> (Some (Some (a,b,c,d,e))) | _ -> None)
      None ev
    in

    let dbg_name = Event.getExtender
      (function Event.DbgName name -> (Some (Some name)) | _ -> None)
      None ev
    in

    match exchange,switch,heal,dbg_name with
    | None,None,None,None -> None
    | _ ->
	let msg = Marsh.marsh_init mbuf in
	Marsh.write_option msg (Marsh.write_string msg) exchange ;
	let iovl = marsh (switch,heal,dbg_name) in
	Marsh.write_iovl_len msg iovl ;
	let iovl = Marsh.marsh_done msg in
	Some iovl

  and unpack_gossip secure iovl =
    let exchange,switch,heal,dbg_name =
      try
	let msg = Marsh.unmarsh_init mbuf iovl in

	let exchange = 
	  Marsh.read_option msg (fun () -> Marsh.read_string msg)
	in

	(* Only read the other fields if things are secure.
	 *)
	let switch,heal,dbg_name = 
	  if secure then (
	    let iovl = Marsh.read_iovl_len msg in
	    unmarsh iovl
	  ) else (None,None,None)
	in

	Marsh.unmarsh_done msg ;
	(exchange,switch,heal,dbg_name)
      with Marsh.Error s -> 
	eprintf "CONFIG_TRANS:unpack_gossip:bad gossip format:%s (continuing)\n" s ;
	(None,None,None,None)
    in

    let exchange = option_map (fun (a)       -> Event.ExchangeGos(a)  ) exchange in
    let switch   = option_map (fun (a,b,c)   -> Event.SwitchGos(a,b,c)) switch in
    let heal     = option_map (fun (a,b,c,d,e) -> Event.HealGos(a,b,c,d,e)) heal in
    let dbg_name = option_map (fun (a)       -> Event.DbgName(a)      ) dbg_name in
    let fields = filter_nones [exchange;switch;heal;dbg_name] in
    match fields with
    | [] -> None
    | _ ->
	let ev = Event.create name Event.EGossipExt fields in
	Some ev

  in pack_gossip,unpack_gossip

(**************************************************************)

let f alarm ranking bot_nomsg ((ls,vs) as vf) up_hdlr =
  let mbuf = Alarm.mbuf alarm in
  let pack,unpack = Util.make_magic () in
  let pack_gossip,unpack_gossip = gossip_marsh mbuf in

  (* OR support for 
   *)
  let sec_sim = lazy (Param.bool vs.params "sec_sim") in

  let schedule = Alarm.alarm alarm
    (fun time -> up_hdlr (Event.timerTime name time) bot_nomsg)
  in

  let async_disable = 
    Async.add (Alarm.async alarm) ls.async (fun () ->
      up_hdlr (Event.create name Event.EAsync[
	(Event.Time (Alarm.gettime alarm))
      ]) bot_nomsg
    )
  in

  let router =
    Elink.get name (if vs.key = Security.NoKey then Elink.unsigned_f else Elink.signed_f) mbuf
(*
    Elink.get name Elink.scale_f mbuf
*)
  in

  let (gossip_gossip,gossip_disable) =
    if ls.am_coord then (
      let receive _ _ secure =
	let handler _ _ iov =
	  match unpack_gossip secure iov with
	  | None -> ()			(* No fields *)
	  | Some ev ->
	      up_hdlr ev bot_nomsg
	in handler
      in

      let trans = Transport.f alarm ranking vf Stack_id.Gossip router receive in

      let gossip = Transport.gossip trans in
      let disable () = Transport.disable trans in
      (gossip,disable)
    ) else (
      let gossip _ _ _ = failwith "non-coord gossipping" ; () in
      (gossip,ident)
    )
  in

  let (primary_cast,primary_send,primary_merge,primary_disable) =
    let receive kind rank secure =
      if secure then (
	let ut = match kind with
	| Conn.Send  -> Event.ESend
	| Conn.Cast  -> Event.ECast
	| Conn.Other -> Event.EMergeRequest
	in
	let debug = addinfo (Event.string_of_type ut) name in
	let handler msg seqno iov =
	  let msg = match msg with
	  | None -> Local_seqno seqno	(*MEM:alloc*)
	  | Some d -> unpack d
	  in
	  up_hdlr (Event.bodyCore debug ut rank iov) msg
	in handler
      ) else (
	fun _ _ _ ->
	  Route.drop (fun () -> "CONFIG_TRANS:insecure message being dropped")
      )
    in

    let trans = Transport.f alarm ranking vf Stack_id.Primary router receive in

    let merge = Transport.merge trans in
    let cast = Transport.cast trans in
    let send = Transport.send trans in
    let disable () = Transport.disable trans in
    (cast,send,merge,disable)
  in
  let sends = Array.create ls.nmembers None in
  
  let dn ev msg = match Event.getType ev with
  | Event.ECastUnrel
  | Event.ECast -> (
      (* Note: we do not free the event because
       * the cast operation will take the iov reference.
       *)
      let iov = Event.getIov ev in
      match msg with
      | Local_seqno seqno -> 
	  primary_cast None seqno iov
      | _ ->
	  primary_cast (Some (pack(msg))) (-1) iov 
    )
  | Event.ESendUnrel
  | Event.ESend -> (
      (* Compute the send function if not done already.
       * Note: we do not free the event because
       * the send operation will take the iov reference.
       *)
      let send =
      	let rank = Event.getPeer ev in
	match sends.(rank) with
      	| Some send -> send
      	| None ->
	    let send = primary_send rank in
	    sends.(rank) <- Some(send) ;
	    send
      in

      let iov = Event.getIov ev in
      match msg with
      | Local_seqno seqno -> 
	  send None seqno iov
      | _ ->
	  send (Some (pack(msg))) (-1) iov 
    )
  | Event.EMergeRequest
  | Event.EMergeGranted
  | Event.EMergeDenied ->
      (* Note: we do not free the event because
       * the merge operation will take the iov reference.
       *)
      let contact,view_id = Event.getContact ev in
      let iov = Event.getIov ev in
      primary_merge view_id contact (Some(pack msg)) (-1) iov ;
  | Event.EExit -> 
      primary_disable () ;
      gossip_disable () ;
      async_disable ()
  | Event.ETimer -> 
      Alarm.schedule schedule (Event.getAlarm ev)
  | Event.EGossipExt ->
      begin
	match pack_gossip ev with
	| None -> ()
	| Some iov ->
	    let iov = Iovecl.take name iov in
	    gossip_gossip None (-1) iov
      end ;
      Event.free name ev

  | Event.EPrivateEnc -> 
      let dst_addr,clear_text = Event.getPrivateEnc ev in
      Auth.bckgr_ticket (Lazy.force sec_sim) ls.addr dst_addr clear_text alarm 
  	(function cipher_text -> 
	  up_hdlr (Event.create name Event.EPrivateEncrypted [
	    Event.PrivateEncrypted cipher_text]
	  ) msg)

  | Event.EPrivateDec -> 
      let dst_addr,cipher_text = Event.getPrivateDec ev in
      Auth.bckgr_check (Lazy.force sec_sim) ls.addr dst_addr cipher_text alarm
	(function clear_text -> 
	  up_hdlr (Event.create name Event.EPrivateDecrypted [
	    Event.PrivateDecrypted clear_text
	  ]) msg) 

  | _ -> failwith "sanity:bad dn"
  in

  dn

(**************************************************************)
