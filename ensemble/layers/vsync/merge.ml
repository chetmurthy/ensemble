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
(* MERGE.ML : reliable merge protocol *)
(* Author: Mark Hayden, 4/95 *)
(* Based on code by: Robbert vanRenesse *)
(**************************************************************)
(* TODO:

 * BUG: should implement acks for merge_denied

 *)
(**************************************************************)
open Util
open Layer
open Event
open View
(*module Hashtbl = Hashtble*)
(**************************************************************)
let name = Trace.filel "MERGE"
let failwith = Trace.make_failwith name
(**************************************************************)

type header = NoHdr | Merge of Addr.set * Endpt.id * int

type ('abv) state = {
  policy                : (Endpt.id * Addr.set -> bool) option ; (* Authorization policy *)
  mutable merging	: bool ;
  mutable next_sweep	: Time.t ;
  mutable new_view	: bool ;
  mutable seqno 	: int ;
  mutable merge_dn 	: (Time.t * dn * 'abv * header) list ;
  merge_up 		: ((Addr.set * Endpt.id),int) Hashtbl.t ;
  mutable buf		: (dn * 'abv * header) list ;
  sweep			: Time.t ;
  timeout		: Time.t
}

let check_policy s a =
  match s.policy with
  | None -> true
  | Some f -> f a

let init s (ls,vs) = {
  policy        = s.exchange;
  sweep	        = Param.time vs.params "merge_sweep" ;
  timeout 	= Param.time vs.params "merge_timeout" ;
  merging	= false ;		(* are we merging now? *)
  new_view      = false ;	        (* set on EView *)
  seqno      	= 0 ;			(* seqno for messages sent *)
  merge_dn   	= [] ;			(* messages sent *)
  merge_up   	= Hashtbl.create (*name*) 10 ; (* messages recd *)
  buf        	= [] ;			(* temporary buffer *)
  next_sweep 	= Time.zero
}
let hdlrs s ((ls,vs) as vf) {up_out=up;upnm_out=upnm;dn_out=dn;dnlm_out=dnlm;dnnm_out=dnnm} =
  let log = Trace.log2 name ls.name in
  let up_hdlr ev abv hdr = match getType ev, hdr with
  | (EMergeRequest|EMergeGranted|EMergeDenied), Merge(saddr,from,seqno) ->
      if not (check_policy s (from,saddr)) then
	free name ev
      else (
	let last_seqno =
          try Hashtbl.find s.merge_up (saddr,from)
          with Not_found -> -1
	in
	if last_seqno < seqno then (
      	(* Remove old entry.
         *)
	  begin
	    try Hashtbl.remove s.merge_up (saddr,from)
	    with Not_found -> ()
	  end ;
	  
  	  Hashtbl.add s.merge_up (saddr,from) seqno ;
	  up ev abv
	) else (
	  free name ev
	)
      )
  | _, NoHdr -> up ev abv
  | _, _     -> failwith bad_up_event
	
  and uplm_hdlr ev hdr = failwith unknown_local
			   
  and upnm_hdlr ev = match getType ev with
  | EView ->
      s.new_view <- true ;
      upnm ev
	
  | ETimer ->
      let time = getTime ev in
      if s.merging then (
	(* Copy from temporary buffer into merge_dn.
	 *)
	List.iter (fun (ev,abv,hdr) ->
	  dn ev abv hdr ;
	  let ev = copy name ev in
	  s.merge_dn <- (Time.add time s.timeout,ev,abv,hdr) :: s.merge_dn
	) s.buf ;
	s.buf <- [] ;

	if Time.ge time s.next_sweep then (
	  s.next_sweep <- Time.add s.next_sweep s.sweep ;

	  List.iter (fun (timeout,ev,abv,hdr) ->
	    let typ = getType ev in
	    if Time.gt timeout time then (
	      let ev = copy name ev in
	      dn ev abv hdr
	     ) else if typ = EMergeRequest
		    && not s.new_view
	     then (
	       log (fun () -> sprintf "failed merge request") ;	
	       upnm (create name EMergeFailed[])
	    )
	  ) s.merge_dn
	)
      ) ;

      upnm ev

  | EExit ->
      List.iter (fun (_,dn,_,_) ->
      	free name dn
      ) s.merge_dn ;
      s.merge_dn <- [] ;
      upnm ev

  | _ -> upnm ev

  and dn_hdlr ev abv = match getType ev with
  | EMergeRequest | EMergeGranted | EMergeDenied ->
      log (fun () -> Event.to_string ev) ;
      s.merging <- true ;
      s.seqno 	<- succ s.seqno ;
      let hdr = Merge(ls.addr,ls.endpt,s.seqno) in
      s.buf 	<- (ev,abv,hdr) :: s.buf ;
      dnnm (timerAlarm name Time.zero) ;
      dn ev abv hdr

  | _ -> dn ev abv NoHdr

  and dnnm_hdlr = dnnm

in {up_in=up_hdlr;uplm_in=uplm_hdlr;upnm_in=upnm_hdlr;dn_in=dn_hdlr;dnnm_in=dnnm_hdlr}

let l args vf = Layer.hdr init hdlrs None NoOpt args vf

let _ = 
  Param.default "merge_sweep" (Param.Time (Time.of_int 1)) ;
  Param.default "merge_timeout" (Param.Time (Time.of_int 15)) ;
  Elink.layer_install name l

(**************************************************************)
