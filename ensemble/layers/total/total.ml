(**************************************************************)
(*
 *  Ensemble, (Version 1.00)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
(**************************************************************)
(* TOTAL.ML *)
(* Author: Mark Hayden, 4/95 *)
(* Based on code by: Robbert vanRenesse *)
(**************************************************************)
open Layer
open Event
open Util
open View
open Trans
(**************************************************************)
let name = Trace.filel "TOTAL"
let failwith = Trace.make_failwith name
(**************************************************************)
(* Notes
  * assumes local delivery for casts below it: use local layer
  * does not observe causality
  *)

(* BUG: should clear ack field when passing events up *)
(* BUG: await_ack arg not used *)
(* BUG: doesn't properly clear out iq buffer at the end
 * of view *)
(* TODO: optimization: allow option to request that the
 * the total layer wait for acknowledgement of message
 * before forwarding the token. *)

(* Headers

 * NoHdr: all non-cast messages

 * TokenRequest: request for token

 * TokenSend(token,next): Assigns next token holder to
 * member 'next'.  This header type never comes with
 * attached data.  The new token holder will send his first
 * message with sequence number 'token.'  All members can
 * forget any token requests by the sender of this message.

 * Ordered(token): Deliver this message with sequence number
 * 'token.'

 * OrderedTokenSendReq(token,next): Combination of previous
 * 3 headers.  The attached message is to be delivered with
 * sequence number 'token-1'.  The next token holder is
 * 'next' who will begin broadcasting with token number
 * 'token'.  In addition the sender requests to be sent
 * token again.

 * Unordered: (ie., not ordered by a token holder) Sent at
 * the end of the view.  All members deliver unordered
 * messages in fifo order in order of the sending members
 * rank.
 *)
type token = seqno
type next  = rank

type header = NoHdr
  | TokenRequest
  | TokenSend           of token * next
  | Ordered             of token
  | OrderedTokenSendReq of token * next
  | Unordered

(**************************************************************)

type 'abv state = {
  await_ack		: bool ;	(* wait for ack before forwarding token? *)
  mutable requested	: bool ; 	(* have I requested the token? *)
  mutable blocking 	: bool ;	(* are we blocking? *)
  mutable token 	: token option ;(* the token, if I have it *)
  request : Request.t ;			(* token requests I've gotten *)
  waiting : ('abv * Iovecl.t) Queuee.t ;	(* buffered xmit waiting for token *)
  order : (rank * 'abv) Iq.t ;		(* buffered recv messages ordered by the token  *)

  (* buffered recv messages waiting for the end of the view *)
  unord : ('abv * Iovecl.t) Queuee.t array ;

  acct               : bool ;		(* accting data *)
  mutable acct_data	: int ;
  mutable acct_token_req : int ;
  mutable acct_token_send : int
}

(**************************************************************)

let dump vf s = Layer.layer_dump name (fun (ls,vs) s -> [|
  sprintf "blocking=%b, request=%s\n" s.blocking (Request.to_string s.request) ;
  sprintf "token=%s waiting_len=%d\n" (string_of_option string_of_int s.token) (Queuee.length s.waiting) ;
  sprintf "ordered=%d..%d\n" (Iq.lo s.order) (Iq.hi s.order) ;
  sprintf "acct(data=%d,toksend=%d,tokreq=%d)\n"
    s.acct_data s.acct_token_req s.acct_token_send
|]) vf s

(**************************************************************)

let init _ (ls,vs) = {
  await_ack	= false ;
  blocking 	= false ;
  token 	= if ls.rank = 0 then Some 0 else None ;
  request 	= Request.create ls.nmembers ;
  requested	= false ;
  waiting 	= Queuee.create () ;
  order 	= Iq.create name (0,NoMsg) ;
  unord 	= Array.init ls.nmembers (fun _ -> Queuee.create()) ;

  acct	        = Param.bool vs.params "total_account" ;
  acct_data	= 0 ;
  acct_token_req = 0 ;
  acct_token_send = 0
}

(**************************************************************)

let hdlrs s ((ls,vs) as vf) {up_out=up;upnm_out=upnm;dn_out=dn;dnlm_out=dnlm;dnnm_out=dnnm} =
  let log = Trace.log2 name ls.name in
(*let ack = make_acker name dnnm in*)

  let acct_hdr = function
  | TokenRequest ->
      s.acct_token_req  <- succ s.acct_token_req
  | TokenSend(_,_) ->
      s.acct_token_send <- succ s.acct_token_send
  | Ordered _
  | OrderedTokenSendReq(_,_)
  | Unordered ->
      s.acct_data <- succ s.acct_data
  | _ -> ()
  in

  (* Decide whether to intercept messages for accounting
   * info.
   *)
  let dn,dnlm =
    if s.acct then
      ((fun ev abv hdr -> acct_hdr hdr ; dn ev abv hdr),
       (fun ev     hdr -> acct_hdr hdr ; dnlm ev   hdr))
    else (dn,dnlm)
  in

  (* Put a message in my buffer and deliver any messages now
   * in order.
   *)
  let add_and_deliver token origin abv iov =
    ignore (Iq.assign s.order token iov (origin,abv)) ;
    Iq.get_prefix s.order (fun seqno iov (origin,abv) ->
      up (castPeerIov name origin iov) abv
    )

  and got_token token =
    if s.token <> None then
      failwith "token holder got another token" ;

    (* Check for any requests.  If there are requests and
     * we have no messages buffered, then just send the
     * token on.  If we have messages, then send them, with the
     * last message being sent as an OrderedTokenSendReq.
     *)
    let next = Request.take s.request in
    let len = Queuee.length s.waiting in
    if next >= 0 then (
      if len = 0 then (
        dnlm (castEv name) (TokenSend(token,next)) ;
	s.requested <- false
      ) else (
      	for i = 0 to len-2 do
	  let abv,iov = Queuee.take s.waiting in
	  dn (castIov name iov) abv
 	     (Ordered (token+i))
        done ;
        let abv,iov = Queuee.take s.waiting in
	dn (castIov name iov) abv
       	   (OrderedTokenSendReq(token+len,next)) ;
	s.requested <- true
      )
    ) else (
      (* No further requests, send messages and keep the
       * token.
       *)
      for i = 0 to pred len do
        let abv,iov = Queuee.take s.waiting in
	dn (castIov name iov) abv
      	   (Ordered (token+i))
      done ;
      s.token <- Some(token+len)
    )
  in

  let up_hdlr ev abv hdr = (*ack ev ;*) match getType ev, hdr with
  | ECast, Ordered(token) ->
      if Iq.opt_update_old s.order token then (
	up ev abv
      ) else (
        add_and_deliver token (getPeer ev) abv (getIov ev) ;
        free name ev
      )

  | ECast, OrderedTokenSendReq(token,next) ->
      let origin = getPeer ev in
      s.acct_data <- succ s.acct_data ;

      (* Remove and add the sender from the requests
       *)
      Request.remove s.request origin ;
      Request.add    s.request origin ;
      
      (* Check if the token is for me.
       *)
      if next = ls.rank then
	got_token token ;
      
      (* Finally, deliver the messages.  Note that the seqno
       * number of the message is one less than that of the
       * token it came with.
       *)
      if Iq.opt_update_old s.order (pred token) then (
	up ev abv
      ) else (
	add_and_deliver (pred token) origin abv (getIov ev) ;
	free name ev
      )

  | ECast, Unordered ->
      s.acct_data <- succ s.acct_data ;
      let origin = getPeer ev in
      Queuee.add (abv,(getIov ev)) s.unord.(origin) ;
      free name ev

  | ECast, NoHdr -> failwith "ECast with NoHdr"
  | _, NoHdr -> up ev abv
  | _ -> failwith bad_up_event

  and uplm_hdlr ev hdr = (*ack ev ;*) match getType ev, hdr with
  | ECast, TokenRequest ->
      if not s.blocking then (
	match s.token with
	| Some t ->
	    log (fun () -> sprintf "sending token to %d" (getPeer ev)) ;
	    dnlm (castEv name) (TokenSend(t,(getPeer ev))) ;
	    s.token     <- None ;
	    s.requested <- false
	| None -> 
	    Request.add s.request (getPeer ev)
      ) ;
      free name ev

    (* Could use sends to pass the token around... (with
     * buffering, is that more efficient?)
     *)
  | ECast, TokenSend(token,next) ->
      if ls.rank = next then
	got_token token ;
      free name ev
      
  | _ -> failwith "bad uplm message"

  and upnm_hdlr ev = match getType ev with
  | EView ->
      (* Deliver unordered messages.
       *)
      Array.iteri (fun i item ->
	Queuee.clean (fun (abv,iov) ->
	  up (castPeerIov name i iov) abv
	) item
      ) s.unord ;
      upnm ev
  | _ -> upnm ev

  and dn_hdlr ev abv = match getType ev with
  | ECast ->
      begin
	match s.token with
	| Some t ->
	    dn ev abv (Ordered t) ;
	    s.token <- Some(succ t)
	| None ->
	    if not s.requested then (
	      log (fun () -> sprintf "requesting token") ;
	      s.requested <- true ;
	      dnlm ev TokenRequest
	    ) ;
	    Queuee.add (abv,(getIov ev)) s.waiting
      end ;
      free name ev

  | _ -> dn ev abv NoHdr

  and dnnm_hdlr ev = match getType ev with
    (* Send any messages we have buffered as 'unordered.'
     *)
  | EBlockOk ->
      if not s.blocking then (
	s.blocking <- true ;
	Queuee.clean (fun (abv,iov) ->
      	  dn (castIov name iov) abv Unordered
	) s.waiting
      ) ;
      dnnm ev

    (* Drop all acknowledgements from above.
     *)
(*
  | EAck ->
      free name ev
*)

  | _ -> dnnm ev

in {up_in=up_hdlr;uplm_in=uplm_hdlr;upnm_in=upnm_hdlr;dn_in=dn_hdlr;dnnm_in=dnnm_hdlr}

let l args vf = Layer.hdr init hdlrs None NoOpt args vf

let _ = 
  Param.default "total_account" (Param.Bool false) ;
  Elink.layer_install name l

(**************************************************************)
