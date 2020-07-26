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
(* FRAG_ABV.ML *)
(* Author: Ohad Rodeh, 6/95 *)
(**************************************************************)
open Trans
open Buf
open Layer
open View
open Event
open Util
(**************************************************************)
let name = Trace.filel "FRAG_ABV"
let failwith = Trace.make_failwith name
(**************************************************************)

type header = 
  | NoHdr
  | Iov_msg

type state = {
  alarm         : Alarm.t ;
  all_local     : bool ;                (* are all members local? *)
  local         : bool Arrayf.t		(* which members are local to my process *)
}

let dump = Layer.layer_dump name (fun (ls,vs) s -> [|
  sprintf "my_rank=%d, nmembers=%d\n" ls.rank ls.nmembers ;
  sprintf "view =%s\n" (View.to_string vs.view) ;
  sprintf "local=%s\n" (Arrayf.to_string string_of_bool s.local)
|])

let init _ (ls,vs) = 
  let addr = ls.addr in
  let local = Arrayf.map (fun a -> Addr.same_process addr a) vs.address in
  let all_local = Arrayf.for_all ident local in
  { 
    all_local = all_local ;
    local = local ;
    alarm = Elink.alarm_get_hack ()
  }

let hdlrs s ((ls,vs) as vf) {up_out=up;upnm_out=upnm;dn_out=dn;dnlm_out=dnlm;dnnm_out=dnnm} =
  let log = Trace.log2 name ls.name in

(*  let mbuf = Alarm.mbuf s.alarm in*)
  let marsh,unmarsh = Iovecl.make_marsh name in


  let up_hdlr ev abv hdr = match getType ev, hdr with
    (* Common case: no fragmentation.
     *)
  | _, NoHdr -> up ev abv

  | _, _     -> failwith bad_up_event

  and uplm_hdlr ev hdr = match getType ev, hdr with 
  | ESend, Iov_msg
  | ECast, Iov_msg -> 
      let iovl = getIov ev in
      let abv = 
      try 
	unmarsh iovl 
      with e -> 
	eprintf "problem in FRAG_ABV"; 
	raise e
      in
      Iovecl.free name iovl ;
      up (set name ev [Iov Iovecl.empty]) abv 

  | _ -> failwith unknown_local
      
  and upnm_hdlr ev = upnm ev
  
  and dn_hdlr ev abv = match getType ev with
  | ECast 
  | ESend -> 
      (* Convert into Iovecls all messages that are: 
       * 1) reliable
       * 2) Don't have an Iovec factor. (all messages above should have this property).
       *)
      let iovl = getIov ev in
      let lenl = Iovecl.len name iovl in
      if lenl >|| len0
	|| (getType ev = ECast && s.all_local)
	|| (getType ev = ESend && Arrayf.get s.local (getPeer ev))
      then (
	(* Uncommon case: no converstion
	 *)
      	dn ev abv NoHdr
      ) else (
	(* Common case: convert into an iovecl.
	  *)
	log (fun () -> "converting into an iovec");

	let m = marsh abv in
	dnlm (set name ev [Iov m]) Iov_msg
      )

  | _ -> dn ev abv NoHdr

  and dnnm_hdlr = dnnm 


in {up_in=up_hdlr;uplm_in=uplm_hdlr;upnm_in=upnm_hdlr;dn_in=dn_hdlr;dnnm_in=dnnm_hdlr}

let l args vf = Layer.hdr init hdlrs None NoOpt args vf

let _ = Elink.layer_install name l
    
(**************************************************************)
