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
(* RAW router. *)
(* Author: Mark Hayden, 3/97 *)
(**************************************************************)
open Trans
open Buf
open Util
(**************************************************************)
let name = Trace.file "RAW"
let failwith = Trace.make_failwith name
(**************************************************************)

let f mbuf =
  let const handler = Route.Raw(handler true) in

  let merge info =
    let upcalls = Arrayf.map (function 
      | (_,p,_,Route.Raw u) -> (p,u)
      | _ -> failwith sanity
      ) info 
    in
    let upcalls = Route.group upcalls in

    Arrayf.map (fun (pack,upcalls) ->
      let upcalls = Route.merge1iov upcalls in
      let upcall rbuf ofs len =
	let buf = Refcnt.read name rbuf in
	if len <|| md5len then (
	  Refcnt.free name rbuf ;
	  Route.drop (fun () -> sprintf "Raw:size below minimum:len=%d\n" (int_of_len len)) ;
	) else if not (Buf.subeq16 buf (ofs +|| len -|| md5len) pack) then (
	  Refcnt.free name rbuf ;
	  Route.drop (fun () -> sprintf "Raw:rest of Conn.id did not match") ;
	) else (
	  let iov = Iovecl.alloc_noref name rbuf ofs (len -|| md5len) in
	  upcalls iov
	)
      in upcall
    ) upcalls
  in

  let blast (_,_,xmitsv) _ pack _ =
    let xmit iovs =
      xmitsv iovs pack
    in xmit
  in

  Route.create name false false const Route.pack_of_conn merge blast

let _ = Elink.put Elink.raw_f f

(**************************************************************)
