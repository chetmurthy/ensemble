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
(* SUSPECT.ML *)
(* Author: Mark Hayden, 11/96 *)
(**************************************************************)
open Trans
open Buf
open Util
open Layer
open View
open Event
(**************************************************************)
let name = Trace.filel "SUSPECT"
(**************************************************************)

type header = Ping of bool Arrayf.t * ltime Arrayf.t

type state = {
  max_idle	: int ;
  sweep		: Time.t ;
  pad           : len ;

  send		: ltime array ;
  recv          : ltime array ;
  mutable failed : bool Arrayf.t ;
  mutable next_sweep : Time.t
}

let conv rank ofs idles =
  let idles = Array.map (fun idle -> string_of_int (ofs - idle)) idles in
  idles.(rank) <- "_" ;
  string_of_array ident idles

let dump = Layer.layer_dump name (fun (ls,vs) s -> [|
  sprintf "failed=%s\n" (Arrayf.bool_to_string s.failed) ;
  sprintf "send=%s\n" (string_of_int_array s.send) ;
  sprintf "recv=%s\n" (string_of_int_array s.recv) ;
  sprintf "idle=%s\n" (conv ls.rank s.send.(ls.rank) s.recv)
|])

let init _ (ls,vs) =
  let pad = Param.int vs.params "suspect_pad" in
  let pad = ceil pad in 
{
  max_idle   = Param.int vs.params "suspect_max_idle" ;
  sweep	     = Param.time vs.params "suspect_sweep" ;
  pad        = pad ;

  failed     = ls.falses ;
  send 	     = Array.create ls.nmembers 0 ;
  recv       = Array.create ls.nmembers 0 ;
  next_sweep = Time.invalid
}

let hdlrs s ((ls,vs) as vf) {up_out=up;upnm_out=upnm;dn_out=dn;dnlm_out=dnlm;dnnm_out=dnnm} =
  let failwith = layer_fail dump vf s name in
  let log = Trace.log2 name ls.name in
  let logp = Trace.log2 (name^"P") ls.name in

  let pad = 
    if s.pad >|| len0 then (
      let iov = Iovec.create name s.pad in
      let iov = Iovecl.of_iovec name iov in
      iov
    ) else Iovecl.empty
  in

  let up_hdlr ev abv () = up ev abv
  and uplm_hdlr ev hdr = match getType ev,hdr with

    (* Ping Message.
     *)
  | (ECast|ESend|ECastUnrel|ESendUnrel), Ping(failed,cnts) ->
      let origin = getPeer ev in
      logp (fun () -> sprintf "Ping from %d %s" origin (Arrayf.int_to_string cnts)) ;
      if origin <> ls.rank		(* Check just in case. *)
      && (not (Arrayf.get failed ls.rank)) (* BUG: could auto-fail him *)
      && (not (Arrayf.get s.failed origin))
      then (
	s.recv.(origin) <- int_max s.recv.(origin) (Arrayf.get cnts ls.rank) ;
        s.send.(origin) <- int_max s.send.(origin) (Arrayf.get cnts origin) ;
(*	dump vf s*)
      ) else (
	logp (fun () -> sprintf "dropping ping") ;
      ) ;
      free name ev

  | _ -> failwith unknown_local

  and upnm_hdlr ev = match getType ev with

    (* EFail: mark the failed members.
     *)
  | EFail ->
      s.failed <- getFailures ev ;
      upnm ev

    (* EInit: request a first timer alarm to bootstrap things.
     *)
  | EInit ->
      dnnm (timerAlarm name Time.zero) ;
      upnm ev

    (* ETimer: every so often:
     *   1. check for suspicions
     *   2. ping the other members
     *)
  | ETimer ->
      let time = getTime ev in
      if Time.ge time s.next_sweep then (
	s.next_sweep <- Time.add time s.sweep ;
	dnnm (timerAlarm name s.next_sweep) ; (* request next sweep *)
      	logp (fun () -> sprintf "Pinging:%s" (Time.to_string time)) ;

	(* We provide an option to pad the ping messages.
	 *)
	let ev =
	  if s.pad >|| len0 then (
	    create name ECastUnrel[Iov (Iovecl.copy name pad)]
	  ) else (
	    create name ECastUnrel[]
	  )
	in
	array_incr s.send ls.rank ;
	dnlm ev (Ping(s.failed,Arrayf.of_array s.send)) ;

	let suspicions = Array.create ls.nmembers false in
	let any = ref false in
	for i = 0 to pred ls.nmembers do
	  if i <> ls.rank 
	  && not (Arrayf.get s.failed i)
	  && s.send.(ls.rank) - s.recv.(i) > s.max_idle
	  then (
	    suspicions.(i) <- true ;
	    any := true
	  )
	done ;
	logp (fun () -> sprintf "Idles:%s" (conv ls.rank s.send.(ls.rank) s.recv)) ;
	if !any then (
	  let suspicions = Arrayf.of_array suspicions in
	  log (fun () -> sprintf "Suspect:%s" (Arrayf.bool_to_string suspicions)) ;
	  dnnm (suspectReason name suspicions name) ;
	)
      ) ;
      upnm ev

  | EDump -> dump vf s ; upnm ev
  | _ -> upnm ev

  and dn_hdlr ev abv = dn ev abv ()
  and dnnm_hdlr = dnnm

in {up_in=up_hdlr;uplm_in=uplm_hdlr;upnm_in=upnm_hdlr;dn_in=dn_hdlr;dnnm_in=dnnm_hdlr}

let l args vf = Layer.hdr init hdlrs None NoOpt args vf

let _ =
  Param.default "suspect_sweep" (Param.Time (Time.of_int 1)) ;
  Param.default "suspect_max_idle" (Param.Int 15) ;
  Param.default "suspect_pad" (Param.Int 0) ;
  Elink.layer_install name l

(**************************************************************)