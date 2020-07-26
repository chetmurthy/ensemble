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
(* FRAG.ML *)
(* Author: Mark Hayden, 6/95 *)
(* There is something of a hack for the interaction between
 * this and the Mflow layer.  This layer marks all
 * fragmented messages with the Fragment flag.  This forces
 * the message to be subject to flow control even if the
 * event is not from the application.  Otherwise, the Mflow
 * layer may reorder application and non-application
 * fragments, causing problems. *)
(**************************************************************)
open Trans
open Buf
open Layer
open View
open Event
open Util
(**************************************************************)
let name = Trace.filel "FRAG"
let failwith = Trace.make_failwith name
(**************************************************************)

type frag = {
  mutable iov : Iovecl.t array ;
  mutable i : int
}

(* The last fragment also has the protocol headers
 * for the layers above us.
 *)
type header = NoHdr 
  | Frag of seqno * seqno		(* ith of n fragments *)
  | Last of seqno			(* num of fragments *)

type state = {
  max_len	: len ;			(* maximum transmisstion size *)
  cast		: frag array ;		(* recv fragments for Cast's *)
  send		: frag array ;		(* recv fragments for Send's *)
  all_local     : bool ;                (* are all members local? *)
  local         : bool Arrayf.t		(* which members are local to my process *)
}

let dump = Layer.layer_dump name (fun (ls,vs) s -> [|
  sprintf "my_rank=%d, nmembers=%d\n" ls.rank ls.nmembers ;
  sprintf "view =%s\n" (View.to_string vs.view) ;
  sprintf "local=%s\n" (Arrayf.to_string string_of_bool s.local)
|])

let init _ (ls,vs) = 
  let local_frag = Param.bool vs.params "frag_local_frag" in
  let addr = ls.addr in
  let local = Arrayf.map (fun a -> (not local_frag) && Addr.same_process addr a) vs.address in
  let all_local = Arrayf.for_all ident local in
  let log = Trace.log2 name ls.name in
  { max_len = len_of_int (Param.int vs.params "frag_max_len") ;
    cast = Array.init ls.nmembers (fun _ -> {iov=[||];i=0}) ;
    send = Array.init ls.nmembers (fun _ -> {iov=[||];i=0}) ;
    all_local = all_local ;
    local = local
  }

let hdlrs s ((ls,vs) as vf) {up_out=up;upnm_out=upnm;dn_out=dn;dnlm_out=dnlm;dnnm_out=dnnm} =
(*let ack = make_acker name dnnm in*)
  let log = Trace.log2 name ls.name in

  (* Handle the fragments as they arrive.
   *)
  let handle_frag ev i n abv =
    (* First, flatten the iovec.  Normally, the iovec
     * should have only one element anyway.  
     *)
    let iovl = getIov ev in
    let origin = getPeer ev in
    
    (* Select the fragment info to use.
     *)
    let frag = 
      if getType ev = ECast
      then s.cast.(origin)
      else s.send.(origin)
    in

    (* Check for out-of-order fragments: could send up lost
     * message when they come out of order.  
     *)
    if frag.i <> i then (
      log (fun () -> sprintf "expect=%d/%d, got=%d, type=%s\n" 
        frag.i (Array.length frag.iov) i (Event.to_string ev)) ;
      failwith "fragment arrived out of order" ;
    ) ;
    
    (* On first fragment, allocate the iovec array where
     * we will put the rest of the entries.
     *)
    if i = 0 then (
      if frag.iov <> [||] then failwith sanity ;
      frag.iov <- Array.create n Iovecl.empty
    ) ;
    if Array.length frag.iov <> n then
      failwith "bad frag array" ;
    
    (* Add fragment into array.
     *)
    if i >= Array.length frag.iov then
      failwith "frag index out of bounds" ;
    frag.iov.(i) <- iovl ;
    frag.i <- succ i ;
    
    (* On last fragment, send it up.  Note that the ack on
     * this should ack all previous fragments.
     *)
    match abv with
    | None ->
	if i = pred n then failwith sanity ;
      	(*ack ev ;*) free_noIov name ev
    | Some abv ->
    	if i <> pred n then failwith sanity ;
        let iov = Iovecl.concata name (Arrayf.of_array frag.iov) in
      	frag.iov <- [||] ;
      	frag.i <- 0 ;
      	up (set name ev [Iov iov]) abv
  in

  let up_hdlr ev abv hdr = match getType ev, hdr with
    (* Common case: no fragmentation.
     *)
  | _, NoHdr -> up ev abv

  | (ECast | ESend), Last(n) ->
      handle_frag ev (pred n) n (Some abv)
  | _, _     -> failwith bad_up_event

  and uplm_hdlr ev hdr = match getType ev, hdr with
  | (ECast | ESend), Frag(i,n) ->
      handle_frag ev i n None
  | _ -> failwith unknown_local

  and upnm_hdlr ev = match getType ev with
  | EExit ->
      (* GC all partially received fragments.
       *)
      let free_frag_array fa =
	Array.iter (fun f ->
	  Array.iter (fun i -> Iovecl.free name i) f.iov ;
          f.iov <- [||]
	) fa
      in

      free_frag_array s.send ;
      free_frag_array s.cast ;
      upnm ev

  | _ -> upnm ev
  
  and dn_hdlr ev abv = match getType ev with
  | ECast | ESend ->
      (* Messages are not fragmented if either:
       * 1) They are small.
       * 2) They are tagged as unreliable. (BUG?)
       * 3) All their destinations are within this process.
       *)
      let iovl = getIov ev in
      let lenl = Iovecl.len name iovl in
      if lenl <=|| s.max_len
      || (getType ev = ECast && s.all_local)
      || (getType ev = ESend && Arrayf.get s.local (getPeer ev))
      then (
	(* Common case: no fragmentation.
	 *)
      	dn ev abv NoHdr
      ) else (
	let iovl = Iovecl.copy name iovl in
(*
        log (fun () -> sprintf "fragmenting") ;
*)
	(* Fragment the message.
	 *)
	let frags = Iovecl.fragment name s.max_len iovl in
	Iovecl.free name iovl ;

	let nfrags = Arrayf.length frags in
	assert (nfrags >= 2) ;
	for i = 0 to nfrags - 2 do
	  dnlm (setIovFragment name ev (Arrayf.get frags i)) (Frag(i,nfrags)) ;
	done ;

	(* The last fragment has the header above us.
         *)
	dn (setIovFragment name ev (Arrayf.get frags (pred nfrags))) abv (Last(nfrags)) ;
	free name ev
      )
  | _ -> dn ev abv NoHdr

  and dnnm_hdlr = dnnm

in {up_in=up_hdlr;uplm_in=uplm_hdlr;upnm_in=upnm_hdlr;dn_in=dn_hdlr;dnnm_in=dnnm_hdlr}

let l args vs = Layer.hdr init hdlrs None (FullNoHdr NoHdr) args vs
let l2 args vs = Layer.hdr_noopt init hdlrs args vs

let _ = 
  let frag_len = Hsys.max_msg_len () - 2000 in
  Param.default "frag_max_len" (Param.Int frag_len) ;
  Param.default "frag_local_frag" (Param.Bool false) ;
  Elink.layer_install name l
    
(**************************************************************)
