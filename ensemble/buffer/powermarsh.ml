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
(* POWERMARSH *)
(* Author: Mark Hayden, 8/97 *)
(**************************************************************)
open Util
open Trans
open Buf
(**************************************************************)
let name = Trace.file "POWERMARSH"
let failwith = Trace.make_failwith name
let log = Trace.log name
(**************************************************************)

let f debug mbuf = 
  let debug = Refcnt.info name debug in
  let imarsh,iunmarsh,_ = Mbuf.make_marsh debug mbuf in
  let scribble = Buf.create len4 in

  let marsh (obj,iovl) = 
    let obj_iovl = imarsh obj in
    Buf.write_net_len scribble len0 (Iovecl.len debug obj_iovl) ;
    let len_iov = Mbuf.alloc debug mbuf scribble len0 (Buf.length scribble) in
    Iovecl.prependi name len_iov (Iovecl.append name obj_iovl iovl)
  and unmarsh iovl =
    let len = Iovecl.len debug iovl in
    if len <|| len4 then
      failwith "POWERMARSH:length(iovl) < 4\n" ;
    let obj_len = Iovecl.read_net_len name iovl len0 in
    let prefix_len = obj_len +|| len4 in

    if len <|| prefix_len then (
      eprintf "POWERMARSH: 4+length(obj)=%d > len=%d\n" (int_of_len obj_len) (int_of_len len) ;
      failwith sanity
    ) ;

    let obj =
      let obj_iovl = Iovecl.sub debug iovl len4 obj_len in
      let obj = iunmarsh obj_iovl in
      obj
    in

    let rest = Iovecl.sub_take debug iovl prefix_len (len -|| prefix_len) in
    (obj,rest)
  in
  (marsh,unmarsh)

(**************************************************************)
    
let _ =
  Elink.put Elink.powermarsh_f f ;

  (* This is testing code for the above function.
   *)
  Trace.test_declare name (fun () ->
    let mbuf = Mbuf.create name Mbuf.mbuf_size (Buf.len_of_int (Hsys.max_msg_len())) in
    let ma,um = f "test" mbuf in
    let name = "tester" in
    for i = 1 to 10000 do
      if (i mod 100) = 0 then
	eprintf "POWERMARSH:test:i=%d\n" i ;
      let str = Buf.create (len_of_int (Random.int 100 * 4)) in
      let iov = Mbuf.allocl name mbuf str len0 (Buf.length str) in
      let iov = ma (str,iov) in
      let len = Iovecl.len name iov in
      let rec loop ofs =
	if ofs >= len then [] else (
	  let chop = Random.int 10 * 4 in
	  let chop = int_min chop (int_of_len (len -|| ofs)) in
	  let chop = len_of_int chop in
	  let sub = Iovecl.sub name iov ofs chop in
	  sub :: (loop (ofs +|| chop))
	)
      in
      Iovecl.free name iov ;
      let iovl = loop len0 in
      let iovl = Iovecl.concat name iovl in

      let str,iovum = um iovl in
      let iov = Mbuf.flatten name mbuf iovum in
      let str' = Iovec.to_string name iov in
      Iovec.free name iov ;
      let str = Buf.to_string str in
      assert (str' = str)
    done
  )

(**************************************************************)
