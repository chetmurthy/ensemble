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
(* SIGNED: MD5 signatures, 16-byte md5 connection ids. *)
(* Author: Mark Hayden, 3/97 *)
(**************************************************************)
open Trans
open Buf
open Util
open Shared
(**************************************************************)
let name = Trace.file "SIGNED"
let failwith = Trace.make_failwith name
let log = Trace.log name
(**************************************************************)

let hdr_len = md5len_plus_8 +|| md5len

let const handler = Route.Signed handler

let f mbuf =
  let (marshal,_,unmarshal) = Mbuf.make_marsh name mbuf in

  let recv pack key secureh insecureh = 
    let key = Security.buf_of_key key in
    let handler rbuf ofs len =
      if len <|| hdr_len then (
	Route.drop (fun () -> sprintf "%s:size below minimum:len=%d\n" name (int_of_len len)) ;
      ) else ( 
	(* Extract connection info.
	 *)
	let buf = Refcnt.read name rbuf in
	if not (Buf.subeq16 buf (ofs +|| len -|| md5len) pack) then (
	  Route.drop (fun () -> sprintf "%s:rest of Conn.id did not match" name) ;
	) else (
	  (* Calculate the signature for the message
	   *)
	  let sign_cpt =
	    let ctx = Hsys.md5_init () in
	    Buf.md5_update ctx buf ofs (len -|| hdr_len) ;
	    Buf.md5_update ctx buf (ofs +|| len -|| md5len_plus_8) md5len_plus_8 ;
	    Buf.md5_update ctx key len0 md5len ;
	    Buf.md5_final ctx
	  in

	  (* Get the integer value and length of
	   * of the marshalled portion of the message.
	   *)
	  let mi    = Buf.read_net_int buf (ofs +|| len -|| md5len_plus_8) in
	  let molen = Buf.read_net_len buf (ofs +|| len -|| md5len_plus_4) in

	  (* Advance past previous fields.
	   * Also subtract off the signature space at the end.
	   *)
	  if Buf.subeq16 buf (ofs +|| len -|| hdr_len) sign_cpt then (
	    if molen =|| len0 then (
	      let mv = Iovecl.alloc_noref name rbuf ofs (len -|| hdr_len) in
	      secureh None mi mv
	    ) else if len >=|| molen then (
	      let len = len -|| hdr_len in
	      let mo = Some(unmarshal buf (ofs +|| len -|| molen) molen) in
	      let mv = Iovecl.alloc_noref name rbuf ofs (len -|| molen) in
	      secureh mo mi mv
	    ) else (
	      Route.drop (fun () -> sprintf "%s:short message:len=%d:molen=%d\n"
		name (int_of_len len) (int_of_len molen)) ;
	    )
	  ) else (
	    if len <|| molen +|| hdr_len then (
	      Route.drop (fun () -> sprintf "%s:(insecure) short message:len=%d:molen=%d\n" 
		name (int_of_len len) (int_of_len molen)) ;
	    ) else (
	      (* Only information passed up is the iovec.
	       *)
	      log (fun () -> sprintf "insecure message") ;
	      let mv = Iovecl.alloc_noref name rbuf ofs (len -|| molen -|| hdr_len) in
	      insecureh None (-1) mv
	    )
	  )
	)
      )
    in handler
  in

  let merge info =
    let upcalls = Arrayf.map (function
      | (_,p,k,(Route.Signed h)) -> ((p,k),h)
      | _ -> failwith sanity
      ) info 
    in
    let upcalls = Route.group upcalls in
    let upcalls =
      Arrayf.map (fun ((pack,key),upcalls) ->
	let secure   = Route.merge3iov (Arrayf.map (fun u -> u true ) upcalls) in
	let insecure = Route.merge3iov (Arrayf.map (fun u -> u false) upcalls) in
	recv pack key secure insecure
      ) upcalls
    in
    upcalls
  in

  let blast (_,_,xmitvs) key pack conn =
    let ints_s = Buf.create len8 in
    let suffix = Buf.append ints_s pack in
    let key = Security.buf_of_key key in

    let xmit mo mi mv =
      let mo = match mo with
      | None -> Iovecl.empty
      | Some(mo) -> marshal mo
      in
      let molen = Iovecl.len name mo in

      Buf.write_net_int suffix len0 mi ;
      Buf.write_net_len suffix len4 molen ;

      (* Calculate the signature.
       *)
      let sign =
	let ctx = Hsys.md5_init () in
	Iovecl.md5_update name ctx mv ;
	Iovecl.md5_update name ctx mo ;
	Buf.md5_update ctx suffix len0 (Buf.length suffix) ;
	Buf.md5_update ctx key len0 md5len ;
	let sign = Buf.md5_final ctx in
	Mbuf.allocl name mbuf sign len0 md5len
      in
      let iovl = Iovecl.concat name [mv;mo;sign] in
      xmitvs iovl suffix
    in xmit
  in

  Route.create name true false const Route.pack_of_conn merge blast

let _ = Elink.put Elink.signed_f f

(**************************************************************)
