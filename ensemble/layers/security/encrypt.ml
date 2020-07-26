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
(* ENCRYPT.ML *)
(* Author: Mark Hayden, 4/97 *)
(**************************************************************)
open Trans
open Buf
open Layer
open View
open Event
open Util
open Shared 
(**************************************************************)
let name = Trace.filel "ENCRYPT"
let log = Trace.log name
let failwith = Trace.make_failwith name
(**************************************************************)

type header = NoHdr | Encrypted

type state ={
  in_place      : bool ;
  shared        : Cipher.t ;
  x_cast	: Cipher.context ;
  x_send        : Cipher.context array ;
  r_cast	: Cipher.context array ; 
  r_send	: Cipher.context array 
}

let dump = Layer.layer_dump name (fun (ls,vs) (s:state) -> [|
|])

let init _ (ls,vs) = 
  let shared = Cipher.lookup "RC4" in
  let chan e = Cipher.init shared vs.key e in

  { 
    in_place = Param.bool vs.params "encrypt_in_place";
    shared = shared; 
    x_cast = chan true ;
    r_cast = Array.init ls.nmembers (fun _ -> chan false ) ;
    x_send = Array.init ls.nmembers (fun _ -> chan true ) ;
    r_send = Array.init ls.nmembers (fun _ -> chan false ) 
  }

let hdlrs s ((ls,vs) as vf) {up_out=up;upnm_out=upnm;dn_out=dn;dnlm_out=dnlm;dnnm_out=dnnm} =
  let log = Trace.log2 name ls.name in
  let mbuf = Alarm.mbuf (Elink.alarm_get_hack ()) in

  let encrypt ev ctx =
    let iov = getIov ev in
    let len = Iovecl.len name iov in
      
    let iov =
      if len <=|| Mbuf.max_len mbuf then (
	let iov,_ =
	  Mbuf.alloc_fun name mbuf (fun buf ofs _ ->
            let len' = Iovecl.flatten_buf name iov buf ofs len in
	    assert (len' =|| len) ;
	    Cipher.encrypt_inplace s.shared ctx buf ofs len ;
	    len,()
	  )
	in iov
      ) else (
	let buf = Buf.create len in
	ignore (Iovecl.flatten_buf name iov buf len0 len) ;
	Cipher.encrypt_inplace s.shared ctx buf len0 len ;
	Iovecl.alloc name (Iovec.heap name buf) len0 len
      )
    in

(*
    let iov = 
      let iov = Mbuf.flatten name mbuf iov in
    (* We are encrypting the iovec in-place here.
     *)
(*
      if s.in_place then ( 
	log (fun () -> "inplace");
	Iovec.read name iov (fun buf ofs len ->
	  Cipher.encrypt_inplace s.shared ctx buf ofs len
	); 
	iov
      ) else *)(
       (* We are allocating a new iovec here.
	*)
	let buf =
	  Iovec.read name iov (fun buf ofs len ->
	    Cipher.encrypt s.shared ctx buf ofs len
	  )
	in
	let len = Buf.length buf in
	let iov = Iovecl.alloc name (Iovec.heap name buf) len0 len in
	iov
      ) 
    in
*)
    let ev = set name ev [Iov iov] in
    ev
  in
  
  let up_hdlr ev abv hdr = match getType ev, hdr with
  | ECast, Encrypted -> 
      log (fun () -> "decrypting");
      let src = getPeer ev in
      let ev = encrypt ev s.r_cast.(src) in
      up ev abv
	
  | ESend, Encrypted -> 
      log (fun () -> "decrypting");
      let src = getPeer ev in
      let ev = encrypt ev s.r_send.(src) in
      up ev abv
	
  | _, NoHdr -> up ev abv
  | _, _     -> failwith bad_up_event

  and uplm_hdlr ev () = failwith "got uplm event"
  and upnm_hdlr = upnm
  
  and dn_hdlr ev abv = match getType ev with
  | ECast when getApplMsg ev -> 
      log (fun () -> "encrypting");
      let ev = encrypt ev s.x_cast in
      dn ev abv Encrypted

  | ESend when getApplMsg ev -> 
      log (fun () -> "encrypting");
      let dst = getPeer ev in
      let ev = encrypt ev s.x_send.(dst) in
      dn ev abv Encrypted

  | _ -> dn ev abv NoHdr

  and dnnm_hdlr = dnnm

in {up_in=up_hdlr;uplm_in=uplm_hdlr;upnm_in=upnm_hdlr;dn_in=dn_hdlr;dnnm_in=dnnm_hdlr}

let l args vs = Layer.hdr init hdlrs None (FullNoHdr NoHdr) args vs

let _ = 
  Param.default "encrypt_in_place" (Param.Bool false) ;
  Elink.layer_install name l
    
(**************************************************************)
