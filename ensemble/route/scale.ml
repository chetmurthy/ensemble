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
(* SCALE: 16-byte MD5'd connection IDs. *)
(* Author: Mark Hayden, 3/97 *)
(**************************************************************)
open Trans
open Util
open Conn
open Route
open Transport
open Buf
(**************************************************************)
let name = Trace.file "SCALE"
let failwith = Trace.make_failwith name
(**************************************************************)

let pack_of_conn c =
  Conn.hash_of_id (snd (Conn.squash_sender c))

let f mbuf =
  let const handler = Route.Scale(handler true) in

  let (marsh,_,unmarsh) = Mbuf.make_marsh name mbuf in

  let merge info =
    let upcalls = Arrayf.map (function
      | (_,p,_,(Route.Scale h)) -> (p,h)
      | _ -> failwith sanity
      ) info
    in
    let upcalls = Route.group upcalls in

    Arrayf.map (fun (pack,upcalls) ->
      let upcalls = Route.merge4iov upcalls in
      let upcall rbuf ofs len =
	let buf = Refcnt.read name rbuf in
	if len <|| md5len_plus_12 then (
	  Refcnt.free name rbuf ;
	  Route.drop (fun () -> sprintf "%s:size below minimum:len=%d\n" name (int_of_len len))
	) else if not (Buf.subeq16 buf (ofs +|| len -|| md5len) pack) then (
	  Refcnt.free name rbuf ;
	  Route.drop (fun () -> sprintf "%s:rest of Conn.id did not match" name)
	) else (
	  let mrank = Buf.read_net_int buf (ofs +|| len -|| md5len_plus_4) in
	  let mi    = Buf.read_net_int buf (ofs +|| len -|| md5len_plus_8) in
	  let molen = Buf.read_net_len buf (ofs +|| len -|| md5len_plus_12) in
	  let len = len -|| md5len_plus_12 in
	  if molen =|| len0 then (
	    let mv = Iovecl.alloc_noref name rbuf ofs len in
	    upcalls mrank None mi mv
	  ) else if len >=|| molen then (
	    let mo = Some(unmarsh buf (ofs +|| len -|| molen) molen) in
	    let mv = Iovecl.alloc_noref name rbuf ofs (len -|| molen) in
	    upcalls mrank mo mi mv
	  ) else (
	    Refcnt.free name rbuf ;
	    Route.drop (fun () -> sprintf "%s:short message:len=%d:molen=%d\n" name (int_of_len len) (int_of_len molen))
	  )
	)
      in upcall
    ) upcalls
  in

  let blast (_,_,xmitvs) _ pack conn _ =
    let sender =
      let sender,_ = Conn.squash_sender conn in
      match sender with
      | Some rank -> rank
      |	None -> -1			(* hack! *)
    in

    let ints_s = Buf.create len12 in
    let suffix = Buf.concat [ints_s;pack] in

    fun mo mi mv ->
      let mo = match mo with
      | None -> Iovecl.empty
      | Some obj -> marsh obj 
      in
      Buf.write_net_int suffix len8 sender ;
      Buf.write_net_int suffix len4 mi ;
      Buf.write_net_len suffix len0 (Iovecl.len name mo) ;
      xmitvs (Iovecl.append name mv mo) suffix
  in
  Route.create name false true const pack_of_conn merge blast

let _ = Elink.put Elink.scale_f f

(**************************************************************)
