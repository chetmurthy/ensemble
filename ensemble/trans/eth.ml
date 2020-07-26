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
(* ETH.ML *)
(* Author: Mark Hayden, 7/99 *)
(**************************************************************)
open Hsys
open Util
open Buf
open Trans
(**************************************************************)
let name = Trace.file "ETH"
let failwith s = Trace.make_failwith name s
let log = Trace.log name
(**************************************************************)

let domain alarm =
  let mbuf = Alarm.mbuf alarm in
  let handlers = Alarm.handlers alarm in
  let broadcast = eth_of_bin_string (hex_to_string "ffffffffffff") in

  (* Get the interface to use.
   *)
  let interface = Arge.get Arge.eth_interface in

  (* Open the raw ethernet packet socket.
   *)
  let eth_addr, sock =
    try Hsys.eth_init interface with e ->
      eprintf "ETH:error creating raw ethernet socket:%s, exiting\n" (Hsys.error e) ;
      eprintf "  (Note: This is only supported on Linux configured with CONFIG_PACKET.\n" ;
      eprintf "   Also, you typically need to run this process as root.)\n" ;
      exit 1
  in

  (* Set the socket to be nonblocking.
   *)
  begin try
    Hsys.setsockopt sock (Hsys.Nonblock true) ;
  with e ->
    log (fun () -> sprintf "warning:setsockopt:Nonblock:%s" (Hsys.error e))
  end ;
  
  (* Getpid should not fail.
   *)
  let pid = 
    try Hsys.getpid () with
    | e ->
	eprintf "ETH:getpid failed (!!!) (%s), exiting\n" (Hsys.error e) ;
	exit 1
  in

  (* An ethernet address also has to include this process'
   * pid.  The pid will obviously be unique throughout the
   * life of this process and remember that addresses are
   * only assocated with processes, not endpoints.  The pid
   * is needed because of code in Transport that assume
   * equivalent addresses correspond to the same process,
   * which is not what we want.  
   *)
  let addr = Addr.EthA(eth_addr,pid) in

  let enable mode group endpt view =
    let recv = Mbuf.alloc_eth_recv name mbuf handlers sock Route.deliver in
    Alarm.add_sock_recv alarm name sock (Hsys.Handler0 recv) ;
    
    let disable () =
      Alarm.rmv_sock_recv alarm sock

    and xmit dest =
      (* Do some preprocessing.
       *)
      let dests =
	match dest with
	| Domain.Pt2pt dests ->
	    Arrayf.map (fun dest ->
	      match Addr.project dest Addr.Eth with 	  
	      | Addr.EthA(addr,_) -> addr
	      | _ -> failwith sanity
	    ) dests
	| Domain.Mcast _
	| Domain.Gossip _ ->
	    Arrayf.singleton broadcast
      in

  (*
      eprintf "ETH:addresses\n" ;
      Arrayf.iter (fun dest ->
	eprintf "ETH:addresses:%s->%s\n"
	  (string_of_eth eth_addr)
	  (string_of_eth dest)
      ) dests ;
  *)

      let info = eth_sendto_info sock interface 0 eth_addr (Arrayf.to_array dests) in

      let xmit buf ofs len = failwith "xmit:unsupported"
      and xmitv iovl = Iovecl.eth_sendtovs info iovl (Buf.empty ())
      and xmitvs iovl s = Iovecl.eth_sendtovs info iovl s 
      in
      Some(xmit,xmitv,xmitvs)
    in
    
    Domain.handle disable xmit
  in

  let addr _ = addr in
  
  Domain.create name addr enable

(**************************************************************)

let _ = Elink.put Elink.eth_domain domain

(**************************************************************)
