(**************************************************************)
(*
 *  Ensemble, (Version 1.00)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
(****************************************************************)
(* SEQUENCER.ML                                                 *)
(* Author: Roy Friedman, 3/96                                   *)
(* Bug fixes: Mark Hayden, 10/96				*)
(* Based on the C implementation of dynseq but without rotating	*)
(* the sequencer.					        *)
(*                                                              *)
(* The coordinator of the group acts as a sequencer; in order   *)
(* to send messages, processes must send the messages pt2pt to  *)
(* the sequencer, who then broadcasts these messages to         *)
(* the rest of the group.                                       *)
(****************************************************************)
open Layer
open View
open Event
open Util
open Trans
(**************************************************************)
let name = Trace.filel "SEQUENCER"
let failwith = Trace.make_failwith name
(**************************************************************)
(* Headers

 * NoHdr: all non-totally ordered cast messages.

 * Ordered(rank): deliver this message as though from member
 * 'rank'.

 * Unordered: (ie., not ordered by a token holder) Sent at
 * the end of the view.  All members deliver unordered
 * messages in fifo order in order of the sending members
 * rank.
 *)

type header = NoHdr
  | ToSeq
  | Ordered of rank
  | Unordered of seqno

(**************************************************************)

type ('abv,'b) state = {
  seq_rank		: rank ;        (* who is the sequencer *)
  ordered		: seqno array ;
  mutable got_view	: bool ;	(* have we got an EView? *)
  mutable blocking 	: bool ;	(* are we blocking? *)

  (* buffered send messages (waiting for delivery from coordinator) *)
  casts 		: 'abv Iq.t ;

  (* buffered recv messages waiting for the end of the view *)
  up_unord 		: (seqno * 'abv * Iovecl.t)  Queuee.t array
}

(**************************************************************)

let dump (ls,vs) s =
  eprintf "SEQUENCER:dump:%s\n" ls.name ;
  sprintf "blocking=%b\n" s.blocking

(**************************************************************)

let init _ (ls,vs) = {
  seq_rank      = 0 ;			(* always rank 0 *)
  ordered	= Array.create ls.nmembers 0 ;
  blocking 	= false ;
  casts 	= Iq.create name NoMsg ;
  got_view	= false ;
  up_unord 	=
    Array.init ls.nmembers (fun _ -> Queuee.create ())
}

(**************************************************************)

let hdlrs s ((ls,vs) as vf) {up_out=up;upnm_out=upnm;dn_out=dn;dnlm_out=dnlm;dnnm_out=dnnm} =
  let log = Trace.log2 name ls.name in

  let up_hdlr ev abv hdr = match getType ev, hdr with
    | ESend, ToSeq ->
	if ls.rank <> s.seq_rank then
	  failwith "send when not sequencer" ;

	(* Bounce the message back out and deliver locally. 
	 *)
	if not s.blocking then (
	  let origin = getPeer ev in
	  let iov = getIov ev in
	  let iov' = Iovecl.copy "Sequ:local" iov in
	  up (castPeerIov name origin iov') abv ;
	  if ls.nmembers > 1 then (
	    let iov' = Iovecl.copy "Sequ:bounce" iov in
	    dn (castIovAppl name iov') abv (Ordered origin)
	  ) ;
	  array_incr s.ordered origin ;
	) ;
	free name ev

    | ECast, Ordered rank ->
      	if s.got_view then
	  failwith "got ordered after view" ;
	if s.seq_rank = ls.rank then
	  failwith "sequencer got ordered message" ;

      	(* If it's from me, then remove from my iq.
	 *)
	if rank = ls.rank then
	  Iq.set_lo s.casts s.ordered.(rank) ;

      	(* Deliver ordered messages.  Keep track of how many
	 * I've got from each member.
       	 *)
(*	log (fun () -> sprintf "delivering ordered msg from %d: #ordered=%d" rank s.ordered.(rank)) ;*)
	array_incr s.ordered rank ;
	up (set name ev[Peer rank]) abv

    | ECast, Unordered seqno ->
      	(* Buffer unordered messages until the view.
	 *)
	let iov = Iovecl.copy "Sequ:Unord" (getIov ev) in
	Queuee.add (seqno,abv,iov) s.up_unord.(getPeer ev) ;
	free name ev

    | _, NoHdr      -> up ev abv (* all other events have NoHdr *)
    | _             -> failwith "non-NoHdr on non ECast"

  and uplm_hdlr ev hdr = failwith "local message event"

  and upnm_hdlr ev = match getType ev with
  | EView ->
      s.got_view <- true ;
      
      (* Deliver unordered messages and then the view.
       *)
      for i = 0 to pred ls.nmembers do
	Queuee.clean (fun (seqno,abv,iov) ->
	  if seqno >= s.ordered.(i) then (
(*	    log (fun () -> sprintf "delivering unordered msg:seqno=%d, #ordered=%d" seqno s.ordered.(i)) ;*)
	    up (castPeerIov name i iov) abv
	  ) else (
	    Iovecl.free name iov
	  )
	) s.up_unord.(i)
      done ;
      upnm ev
  | _ -> upnm ev

  and dn_hdlr ev abv = match getType ev with
  | ECast ->
      let iov = getIov ev in

      if getNoTotal ev then (
      	(* Send without ordering properties.
	 *)
      	dn ev abv NoHdr
      ) else if s.blocking then (
      	eprintf "SEQUENCER:warning dropping ECast after EBlockOk\n" ;
	free name ev
      ) else if ls.rank = s.seq_rank then (
	(* If I'm the sequencer, send out immediately as an ordered message.
	 * Otherwise, send pt2pt to sequencer and stash a copy of it in
	 * case the sequencer fails and we need to resend it.
	 *)
	let iov = Iovecl.copy "Sequ:coord" (getIov ev) in
	if ls.nmembers > 1 then
	  dn ev abv (Ordered(ls.rank))
	else
	  free name ev ;
	up (castPeerIov name ls.rank iov) abv ;
	array_incr s.ordered ls.rank
      ) else (
	ignore (Iq.add s.casts iov abv) ;
	let iov = Iovecl.copy "Sequ:send_to_coord" iov in
	dn (sendPeerIov name s.seq_rank iov) abv ToSeq ;
	free name ev
      )

    (* Handle local delivery for sends.
     *)
  | ESend ->
      let dest = getPeer ev in
      if dest = ls.rank then (
	let iov = Iovecl.copy "Seqno:local_send" (getIov ev) in
      	up (sendPeerIov name ls.rank iov) abv ;
  	free name ev
      ) else (
	dn ev abv NoHdr
      )

  | _ -> dn ev abv NoHdr

  and dnnm_hdlr ev = match getType ev with
    (* Send any messages we have buffered as 'unordered.'  
     *)
  | EBlock ->
      if not s.blocking then (
	s.blocking <- true ;
	List.iter (fun (seqno,iov,abv) ->
	  Queuee.add (seqno,abv,iov) s.up_unord.(ls.rank) ;
	  let iov = Iovecl.copy "Sequ:now_blocking" iov in
	  dn (castIovAppl name iov) abv (Unordered seqno)
	) (Iq.list_of_iq s.casts)
      ) ;
      dnnm ev

  | _ -> dnnm ev

in {up_in=up_hdlr;uplm_in=uplm_hdlr;upnm_in=upnm_hdlr;dn_in=dn_hdlr;dnnm_in=dnnm_hdlr}

let l args vf = Layer.hdr init hdlrs None NoOpt args vf

let _ = Elink.layer_install name l

(**************************************************************)
