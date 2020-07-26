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
(* CHK_SECCHAN.ML *)
(* Author: Ohad Rodeh, 3/99 *)
(* Tests for the secchan/mngchan layers *)
(**************************************************************)
open Layer
open Trans
open Util
open View
open Event
(**************************************************************)
let name = Trace.filel "CHK_SECCHAN"
(**************************************************************)

type header = ChanList of rank list | NoHdr

type state = {
  nonce               : int ;
  ack                 : bool array ;
  mutable first_time  : bool;
  prog                : string ;
  mutable blocked     : bool ;
  mutable recv        : int ;
  chans               : rank list array
}

type msg = Out of int | In of int | String of string

let init s (ls,vs) = {
  nonce       = ls.rank ;
  ack         = Array.init ls.nmembers (function i -> i=ls.rank);
  first_time  = true ;
  prog        = Param.string vs.params "chk_secchan_prog" ;
  blocked     = false ;
  recv        = 0 ;
  chans       = if ls.rank = 0 then Array.create ls.nmembers [] else Array.create 0 []
}

let marshal, unmarshal = Buf.make_marsh "CHK_SECCHAN" true
let check_all a = array_for_all ident a 
let log ls = Trace.log2 name (string_of_int ls.rank)
let log1 ls = Trace.log2 (name^"1") (string_of_int ls.rank)
  
(**************************************************************)
module type TEST = sig
  val timer : state -> View.full -> (Event.t -> header -> unit) -> Time.t -> unit
  val handle_secure_msg : state -> View.full -> (Event.t -> header -> unit) ->  msg -> rank -> unit
end
  
module N_to_n : TEST = struct
  let send_all s (ls,vs) dnlm  = 
    if not s.blocked then (
      log ls (fun () -> sprintf "sending %d" s.nonce);
      let rnd = marshal (Out s.nonce) in
      for i=0 to (pred ls.nmembers) do 
	if ls.rank <> i then 
	  dnlm (create name ESecureMsg [Peer i; SecureMsg rnd]) NoHdr
      done;
    )

  let timer s (ls,vs) dnlm t = 
    if s.first_time && ls.nmembers > 1 then (
      s.first_time <- false ;
      send_all s (ls,vs) dnlm ;
    )
    
  (* Echo received messages 
   *)
  let handle_secure_msg s (ls,vs) dnlm m src = 
    match m with 
    | Out r -> 
	log1 ls (fun () -> sprintf "Got [%d] msg=%d" src r);
	let reply = marshal (In r) in
	dnlm (create name ESecureMsg [Peer src; SecureMsg reply]) NoHdr
    | In r -> 
	if r = s.nonce then (
	  log1 ls (fun () -> sprintf "Echo from %d -- OK" src);
	  s.ack.(src) <- true ;
	  if (check_all s.ack) then (
	    Array.fill s.ack 0 (Array.length s.ack) false;
	    s.ack.(0) <- true;
	    log ls (fun () -> "All OK");
	    send_all s (ls,vs) dnlm
	  )
	) else 
	  failwith (sprintf "Echo from %d [val=%d]" src r) 
    | _ -> failwith "N_n, bad message type"
end
  
module One_to_n : TEST = struct
  let send_all s (ls,vs) dnlm  = 
    assert(ls.rank=0);
    log ls (fun () -> sprintf "sending %d" s.nonce);
    let rnd = marshal (Out s.nonce) in
    for i=1 to (pred ls.nmembers) do 
      dnlm (create name ESecureMsg [Peer i; SecureMsg rnd]) NoHdr
    done;
    ()

  let timer s (ls,vs) dnlm t = 
    if s.first_time && ls.nmembers > 1 && ls.rank = 0 then (
      s.first_time <- false ;
      send_all s (ls,vs) dnlm
    )

  (* Echo received messages 
   *)
  let handle_secure_msg s (ls,vs) dnlm m src = 
    match m with 
    | Out r -> 
	log1 ls (fun () -> sprintf "Got [%d] msg=%d" src r);
	let reply = marshal (In r) in
	dnlm (create name ESecureMsg [Peer src; SecureMsg reply]) NoHdr
    | In r -> 
	if r = s.nonce then (
	  log1 ls (fun () -> sprintf "Echo from %d -- OK" src);
	  s.ack.(src) <- true ;
	  if (check_all s.ack) then (
	    Array.fill s.ack 0 (Array.length s.ack) false;
	    s.ack.(0) <- true;
	    log ls (fun () -> "All OK");
	    send_all s (ls,vs) dnlm
	  )
	) else 
	  failwith (sprintf "Echo from %d [val=%d]" src r) 
    | _ -> failwith "N_n, bad message type"
end

module Ping : TEST = struct
  let hello = marshal (String "hello world")

  let timer s (ls,vs) dnlm t = 
    if s.first_time && ls.nmembers > 1 then (
      s.first_time <- false;
      match ls.rank with 
	| 0 -> dnlm (create name ESecureMsg [Peer 1; SecureMsg hello]) NoHdr
	| _ -> ()
    )

  let handle_secure_msg s (ls,vs) dnlm m src = 
    if m <> (String "hello world") then failwith "bad message";
    match src,ls.rank with 
      | 1,0 -> dnlm (create name ESecureMsg [Peer 1; SecureMsg hello]) NoHdr
      | 0,1 -> dnlm (create name ESecureMsg [Peer 0; SecureMsg hello]) NoHdr
      | _ -> failwith "Ping, bad message destination"
end

(**************************************************************)
  
  
let hdlrs s ((ls,vs) as vf) {up_out=up;upnm_out=upnm;dn_out=dn;dnlm_out=dnlm;dnnm_out=dnnm} =
  let log = Trace.log2 name ls.name in
  let log2 = Trace.log2 (name^"2") ls.name in
  let failwith m = failwith ("("^name^":"^m^")") in
  let endpt_of_rank r = Endpt.string_of_id_short (Arrayf.get vs.view r) in
  let timer = match s.prog with 
    | "ping" -> Ping.timer
    | "n_n"  -> N_to_n.timer
    | "1_n"  -> One_to_n.timer
    | _ -> failwith "program not supported"
  and handle_secure_msg = match s.prog with
    | "ping" -> Ping.handle_secure_msg
    | "n_n"  -> N_to_n.handle_secure_msg
    | "1_n"  -> One_to_n.handle_secure_msg
    | _ -> failwith "program not supported"
  in

  let check_recv_all () = 
    if s.recv = ls.nmembers then (
      log2 (fun () -> "received all");
      let result = ref true in
      Array.iteri (fun i l -> 
	if not (List.for_all (fun r -> List.mem i s.chans.(r)) l) then
	  result := false
      ) s.chans;
     if not !result then (
	eprintf "%s\n" (string_of_array (fun l -> string_of_list endpt_of_rank l ) s.chans);
	flush stdout;
	failwith "Non-symmetric channels"
      )
    )
  in
      
  let up_hdlr ev abv hdr = match getType ev,hdr with
    | _ -> up ev abv
	  
  and uplm_hdlr ev hdr = 
    match getType ev,hdr with
      (* Echo received messages *)
    | ESecureMsg,NoHdr -> 
	if not s.blocked then (
	  let src = getPeer ev in
	  let m = getSecureMsg ev in
	  let m = unmarshal m Buf.len0 (Buf.length m) in
	  handle_secure_msg s (ls,vs) dnlm m src
	);
	free name ev

    | ESend, ChanList l -> 
	if not s.blocked then (
	  s.recv <- succ s.recv ;
	  let peer = getPeer ev in
	  s.chans.(peer) <- l ;
	  check_recv_all ()
	);
	free name ev

    | _ -> failwith unknown_local
		
  and upnm_hdlr ev = match getType ev with
    | ETimer -> 
	timer s (ls,vs) dnlm (getTime ev) ;
	upnm ev	

    | ESecChannelList -> 
	(* log2 (fun () -> "ESecChannelList");*)
	if not s.blocked then (
	  let l = getSecChannelList ev in
	  if ls.rank = 0 then (
	    s.recv <- succ s.recv ;
	    s.chans.(0) <- l
	  ) else
	    dnlm (sendPeer name 0) (ChanList l);
	);
	free name ev

    | _ -> upnm ev
	  
  and dn_hdlr ev abv = dn ev abv NoHdr
	  
  and dnnm_hdlr ev = match getType ev with
    | EBlock -> 
	s.blocked <- true;
	dnnm ev

    | _ -> dnnm ev

in {up_in=up_hdlr;uplm_in=uplm_hdlr;upnm_in=upnm_hdlr;dn_in=dn_hdlr;dnnm_in=dnnm_hdlr}

let l args vf = Layer.hdr init hdlrs None NoOpt args vf

let _ = 
  Param.default "chk_secchan_prog" (Param.String "ping") ;
  Elink.layer_install name l

(**************************************************************)




