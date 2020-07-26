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
(* EXCHANGE.ML : key exchange protocol *)
(* Authors: Ohad Rodeh 4/98 *)
(* Based on code by Mark Hayden, with suggestions by Ron Minsky *)
(**************************************************************)
(* Improvments
 * -----------
 * 1. Why send the ticket as a gossip message, use point-to-point unreliable
 * comm.
 * 2. We need better PGP support that will authenticate better recieved messages. 
*)

open Buf
open Layer
open View
open Event
open Util
open Trans
open Shared

(**************************************************************)
let name = Trace.filel "EXCHANGE"
let failwith = Trace.make_failwith name
(**************************************************************)

(* Something that completely identifies this endpoint
 *)
type id = Trans.rank * Endpt.id * Trans.ltime * Addr.set 
  
(* The nonce is used to prevent replays. It is an increasing counter that 
 * is reset every view change. 
*)
type nonce = int

type header = 
  | NoHdr
  | Hdr_Ticket of Addr.set 


(* My id is used just to discard messages from myself. The ticket
 * includes the target_id and the nonce recieved from it. Currently, it
 * is sent as a multicast, though it would be better to sed as a
 * point-to-point unreliable message
 *)
type exch_msg = 
  | Id of id * nonce
  | Ticket of Addr.set (*target*) * Endpt.id * Addr.set (*source*) * Auth.ticket   
    
type bckgr = 
  | Idle
  | Computing
  | Accepted
      
let string_of_bckgr = function
  | Idle -> "Idle"
  | Computing -> "Computing" 
  | Accepted -> "Accepted"
	
type state = {
  policy             : (Endpt.id * Addr.set -> bool) option ;
  mutable key_sug    : Security.key ;
  mutable blocked    : bool;
  mutable bckgr      : bckgr ;
  mutable nonce      : int ;
  mutable last_time  : Time.t 
}
	       
let endpt_of_id = function r,e,lt,addr -> e
let addr_of_id = function r,e,lt,addr -> addr

let dump = ignore2
	     
let check_policy s a = match s.policy with
  | None -> true
  | Some f -> f a
	
let init s (ls,vs) = {
  key_sug = vs.key ;
  blocked = false ;
  policy  = s.exchange;
  bckgr   = Idle ;
  nonce = 0 ;
  last_time = Time.zero
}
			 
(**************************************************************)

let marshal, unmarshal = Buf.make_marsh "EXCHANGE" true
let marshal2, unmarshal2 = Buf.make_marsh "EXCHANGE2" true

let hdlrs s ((ls,vs) as vf) {up_out=up;upnm_out=upnm;dn_out=dn;dnlm_out=dnlm;dnnm_out=dnnm}  =
  let log = Trace.log2 name ls.name in
  let log1 = Trace.log2 (name^"1") ls.name in
  let logd = Trace.log2 (name^"D") ls.name in
  let logs = Trace.log2 (name^"S") ls.name in
  let shared = Cipher.lookup "RC4" in
  let my_id = (ls.rank,ls.endpt,vs.ltime,ls.addr) in

  let gossip_send msg =
    let msg = marshal msg in
    let msg = Buf.to_string msg in
    let msg = ExchangeGos msg in
    msg
  in
    
  let gossip_get a = 
    let a = Buf.of_string name a in
    let src = unmarshal a len0 (Buf.length a) in 
    src
  in
    
  let gossip_recv msg = 
    let msg = gossip_get msg in
    if s.blocked || s.bckgr <> Idle then
      logd (fun () -> sprintf "blocked++, %s" (string_of_bckgr s.bckgr))
    else
      match msg with 
      | Id(((s_rank, s_endpt, s_lt, s_addr) as s_id), s_nonce) -> 
	  if s_endpt <= ls.endpt then 
	    logd (fun () -> sprintf "discarding id %s" (Endpt.string_of_id s_endpt))
	  else
	    if not (check_policy s (s_endpt,s_addr)) then
	      log (fun () -> "recvd id, but policy rejected it")
	    else (
	      log (fun () -> sprintf "recvd and ok'd id") ;
	      s.bckgr <- Computing;
	      let clear_text = marshal2 (s_id, s_nonce, my_id, s.key_sug) in
	      dnlm (create name EPrivateEnc [
		PrivateEnc (s_addr, clear_text)
	      ])) (Hdr_Ticket s_addr);
      | Ticket(trg_addr,s_endpt,s_addr,ticket) ->
	  if ls.addr = trg_addr then 
	    if check_policy s (s_endpt,s_addr) then (
	      log (fun () -> sprintf "got ticket from %s" (Addr.string_of_set s_addr));
	      s.bckgr <- Computing;
	      dnlm (create name EPrivateDec [PrivateDec (s_addr,ticket)]) NoHdr
	    ) else
	      log (fun () -> "Source is not authorized")
	  else
	    logd (fun () -> "Ticket not to me")
  in
  
  let up_hdlr ev abv () = up ev abv
  and uplm_hdlr ev hdr = match getType ev,hdr with
  | EPrivateEncrypted, Hdr_Ticket trg_addr -> 
      log1 (fun () -> "got EPrivateEncrypted");
      if not s.blocked then (
	let ticket = getPrivateEncrypted ev in
	match ticket with
	  | Some ticket -> 
    	      log (fun () -> sprintf "sending ticket to %s" (Addr.string_of_set trg_addr));
	      let msg = gossip_send(Ticket(trg_addr, ls.endpt, ls.addr, ticket)) in 
	      dnnm (create name EGossipExt[msg]);
	  | None ->
	      log (fun () -> sprintf "failed to authenticate id")
      );
      s.bckgr <- Idle

  | EPrivateDecrypted, NoHdr -> 
      log1 (fun () -> "got EPrivateDecrypted");
      if not s.blocked then (
	let reply = getPrivateDecrypted ev in
	s.bckgr <- Idle;
	begin match reply with
	  | Some ticket -> 
	      let (trg_id, trg_nonce, src_id, trg_key) = unmarshal2 ticket Buf.len0 (Buf.length ticket) in
	      if src_id = my_id then 
		log1 (fun () -> "ticket from myself")
	      else
		if trg_id = my_id then 
		  let diff = s.nonce - trg_nonce in
		  if diff < 10 && diff >= 0 then (
	    	    log (fun () -> sprintf "recvd and ok'd ticket") ;
		    if trg_key <> s.key_sug then (
		      log (fun () -> "accepting key, EPrompt") ;
		      s.bckgr <- Accepted ;
		      s.key_sug <- trg_key ;
		      upnm (create name EPrompt [])
		    ) else
		      log (fun () -> "s.key_sug = received key");
		  ) else 
		    log (fun () -> sprintf "Nonce invalid diff=%d, dropping" diff)
	  | None ->
	      logs (fun () -> "Ticket is empty (None)")
	end
      )
	
  | _ -> failwith "bad uplm event"

  and upnm_hdlr ev = match getType ev with
    (* Decrypt new_key with old_key
     * It is none if it was disseminated using Rekey. 
     *)
  | EView ->
      let new_vs = getViewState ev in
      let new_vs = 
	match new_vs.key with 
	| Security.NoKey -> new_vs (* Dissemination using Rekey *)
	| Security.Common enc_key -> 
	    let context = Cipher.init shared vs.key true in
	    let key = Cipher.encrypt 
	      shared context enc_key len0 (Buf.length enc_key) in
	    let key = Security.Common key in
	    logs (fun () -> sprintf "up EView %s" (Security.string_of_key key));
	    View.set new_vs [Vs_key key] 
      in
      s.blocked <- true ;
      upnm (set name ev[ViewState new_vs])

  | EBlock ->
      s.blocked <- true ;
      upnm ev
  | EGossipExt -> 
      if ls.am_coord then (
    	getExtendOpt ev (function
	| ExchangeGos(a) -> gossip_recv a ; true
	| _ -> false
	)
      ) ;
      upnm ev
	
  | EInit -> 
      s.last_time <- getTime ev;
      upnm ev

  | ETimer ->
      let now = getTime ev in
      if Time.ge (Time.sub now s.last_time) (Time.of_int 1) then (
	s.nonce <- succ s.nonce;
	s.last_time <- now
      );
      upnm ev

  | EDump -> ( dump vf s ; upnm ev )
  | _ -> upnm ev
	
  and dn_hdlr ev abv = dn ev abv ()
			 
  and dnnm_hdlr ev = match getType ev with
    (* Encrypt new_key with old_key
     * It is none if it was disseminated using Rekey. 
     *)
  | EView ->
      logs (fun () -> "dn EView");
      let new_vs = getViewState ev in
      let new_vs = 
	match new_vs.key with 
        | Security.NoKey -> new_vs (* Dissemination using Rekey *)
	| Security.Common key -> 
	    match s.key_sug with 
	    | Security.NoKey -> new_vs
	    | Security.Common key_sug -> 
		let context = Cipher.init shared vs.key true in
		let enc_key_sug = 
		  Cipher.encrypt shared context key_sug len0 (Buf.length key_sug) 
		in
	    	View.set new_vs [Vs_key (Security.Common enc_key_sug)] 
      in
      dnnm (set name ev[ViewState new_vs])
	
  | EGossipExt ->
      let ev =
	if ls.am_coord && not s.blocked then (
	  let msg = gossip_send(Id(my_id,s.nonce)) in
	  set name ev [msg]
	) else ev
      in
      dnnm ev

  | _ -> dnnm ev
	
  in {up_in=up_hdlr;uplm_in=uplm_hdlr;upnm_in=upnm_hdlr;dn_in=dn_hdlr;dnnm_in=dnnm_hdlr}
       
let l args vf = Layer.hdr init hdlrs None NoOpt args vf
		  
(* [sec_sim] simulate authentication?
 *)
let _ = 
  Param.default "sec_sim" (Param.Bool false) ;
  Elink.layer_install name l
    
(**************************************************************)
