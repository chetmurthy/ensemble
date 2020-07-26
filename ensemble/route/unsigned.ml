(**************************************************************)
(* UNSIGNED: Unsigned, 16-byte MD5'd connection IDs. *)
(* Author: Mark Hayden, 3/97 *)
(**************************************************************)
open Trans
open Buf
open Util
(**************************************************************)
let name = Trace.file "UNSIGNED"
let failwith = Trace.make_failwith name
let log  = Trace.log name
(**************************************************************)

let const handler = Route.Unsigned(handler true)

let f mbuf =
  let (marshal,_,unmarshal) = Mbuf.make_marsh name mbuf in

  (* Merge handlers together.
   *)
  let merge info =
    (* Project the connection ids ("pack") and the upcalls.
     *)
    let upcalls = Arrayf.map (function
      | (_,p,_,(Route.Unsigned u)) -> (p,u)
      | _ -> failwith sanity
      ) info
    in

    (* Group upcalls for equal connection ids.
     *)
    let upcalls = Route.group upcalls in

    (* Generate an array of handlers
     *)
    Arrayf.map (fun (pack,upcalls) ->
      let upcalls = Route.merge3iov upcalls in
      Route.info (fun () -> sprintf "%s:recv:%s" (Buf.to_hex pack) name) ;
      let upcall rbuf ofs len =
	let buf = Refcnt.read name rbuf in
	let hdr = ofs +|| len -|| md5len_plus_8 in
	if len <|| md5len_plus_8 then (
	  Refcnt.free name rbuf ;
	  Route.drop (fun () -> sprintf "%s:size below minimum:len=%d\n" name (int_of_len len))
	) else if not (Buf.subeq16 buf (hdr +|| len8) pack) then (
	  Refcnt.free name rbuf ;
	  Route.drop (fun () -> sprintf "%s:rest of Conn.id did not match" name)
	) else (
	  let mi    = Buf.read_net_int buf (hdr +|| len4) in
	  let molen = Buf.read_net_len buf hdr in
	  if molen =|| len0 then (
	    (* No marshalled object, just the iovec.
	     *)
	    let mv = Iovecl.alloc_noref name rbuf ofs (len -|| md5len_plus_8) in(*MEM:alloc*)
	    upcalls None mi mv
	  ) else if (len -|| md5len_plus_8) =|| molen then (
	    (* Just a marshalled object.
	     *)
	    let mo = unmarshal buf (hdr -|| molen) molen in
	    Refcnt.free name rbuf ;
	    upcalls (Some mo) mi Iovecl.empty
	  ) else if len >|| molen then (
	    (* Both a marshalled object and an iovec.
	     *)
	    let mo = unmarshal buf (hdr -|| molen) molen in
	    let mv = Iovecl.alloc_noref name rbuf ofs (hdr -|| molen -|| ofs) in
	    upcalls (Some mo) mi mv
	  ) else (
	    Refcnt.free name rbuf ;
	    Route.drop (fun () -> sprintf "%s:short message:len=%d:molen=%d\n"
	      name (int_of_len len) (int_of_len molen))
	  )
	)
      in upcall
    ) upcalls
  in

  (* Transmit a message.  We are given various xmit functions, of which
   * we only use one here and the connection id ("pack").
   *)
  let blast (_,_,xmitvs) _ pack _ =
    let ints_s = Buf.create len8 in
    let suffix = Buf.append ints_s pack in
    let fast_suffix = Buf.copy suffix in
    Buf.write_net_len fast_suffix len0 len0 ;
    let xmit mo mi mv =
(*
      eprintf "UNSIGNED:blast:%04X\n" (Buf.int16_of_substring suffix (Buf.length suffix -|| len4)) ;
*)
      match mo with
      | None ->
	  Buf.write_net_int fast_suffix len4 mi ;
	  xmitvs mv fast_suffix
      | Some mo -> 
	  let mo = marshal mo in
	  let iovl = Iovecl.append name mv mo in
	  Buf.write_net_int suffix len4 mi ;
	  Buf.write_net_len suffix len0 (Iovecl.len name mo) ;
	  xmitvs iovl suffix
    in xmit
  in

  Route.create name false false const Route.pack_of_conn merge blast

let _ = Elink.put Elink.unsigned_f f

(**************************************************************)
