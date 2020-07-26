(**************************************************************)
(*
 *  Ensemble, (Version 1.00)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
(*
 * Module seqBB. An sequencer based broadcast-broadcast
 * total ordering protocol.
 * A sender who wishes to initiate a totally ordered broadcast,
 * sends it immediatly. All receivers buffer the message until
 * they receive a special accept message from the sequencer.
 * The sequencer itself listens for broadcast messages and sends
 * the accept message as soon as it receives a broadcast.
 *
 * Messages are identified by the senders rank and by their position 
 * in the stream of input messages (MNAK provides FIFO).
 * 
 * When a member receives an accept, it delivers the
 * corresponsing message. If the message is not yet 
 * available the accept is buffered.
 * IMPORTANT : This protocol requires a reliable channel that already
 * provides FIFO ordering (per member), I.e. MNAK.
 *
 * The BB protocol has advantages on multicast networks, with
 * with large messages.
 * 
 * Written by Lars Hofhansl Mai 1997
 * 
 * Warning, this is my first Program in ocaml (and ensemble),
 * so be patient with me...
 *)


(* import some modules *)

open Layer
open Event
open Util
open View
open Trans

let name = Trace.filel "SEQBB"
let failwith = Trace.make_failwith name

type header = NoHdr
  | Cast         (* an ordered BCast msg *)
  | Acc of rank  (* accept from the sequencer *)

type 'abv state = {
    (* the rank of the sequencer *)
    seq_rank : int;   

    (* array of queues containing all not yet accepted msg for
       each member *)
    to_deliver : ('abv * Event.t) Queue.t array;

    (* list of all accept msgs *)
    accepts : int Queue.t;

    (* is the view in a blocking state ? *)
    mutable blocking : bool
}

(* vs is a viewstate record, s is a state record *)

let dump (ls,vs) s = ()

let init _ (ls,vs) = {
  seq_rank = 0;      (* sequencer is always 0 *)
  blocking = false;
  to_deliver = Array.init ls.nmembers (fun _ -> Queue.create());
  accepts = Queue.create ()
}


let hdlrs s ((ls,vs) as vf) {up_out=up;upnm_out=upnm;dn_out=dn;dnlm_out=dnlm;dnnm_out=dnnm} =

  (* scan through the list of accepts and try to deliver the corresponding
     msgs. If successful try the next one *)

  let rec deliver () =
    try 
      let rank = Queue.peek s.accepts in

      let (abv,ev) = Queue.take s.to_deliver.(rank) in

      ignore (Queue.take s.accepts) ; (* if reached : remove head *)

      up ev abv;             (* deliver the msg            *)
      deliver ();            (* .. and try the next accept *)
	
    with Queue.Empty -> ()   (* either accepts of msg-queue empty...
				do nothing ... *)
  in

  (* rcv evt from below *) 
  let up_hdlr ev abv hdr =

    (* if we receive a normal cast message: 
       - the sequencer casts the accept message,
         and delivers the original message
       - all others store the message, until the
         accept message arrives *)
    match getType(ev),hdr with
    | ECast, Cast ->
	let rank = getPeer ev in 

      	if ls.rank = s.seq_rank then (
	  (*printf "sequencer: got Cast send accept for %d from %d\n"
	    seqno rank;*)

	  (* cast accept message *)
	  dnlm (create name ECast[Peer ls.rank]) (Acc rank);

	  (* deliver *)
	  up ev abv ;

	) else (
	  (*printf "storing cast %d from %d\n" seqno rank;*)
	  Queue.add (abv,ev) s.to_deliver.(rank);
	  deliver ()
	)
    | _ -> up ev abv

  (* rcv ev from below, handle msg *)
  and uplm_hdlr ev hdr = match getType ev, hdr with
  | ECast,Acc(rank) ->
      (* deliver the message from rank *)

      if( ls.rank <> s.seq_rank ) then (
	(*printf "got accept %d from %d... queueing\n" seqno rank;*)

	Queue.add rank s.accepts;

	deliver ();
      );
      free name ev
  | _ -> failwith "uplm_hdlr... strange"

  (* rcv ev from below *)
  and upnm_hdlr ev = match getType ev with
    (* if I get get a new view I deliver all msg that wait for
       delivery in some deterministic order - here ordered by
       rank -- oops, also take seqno into account !! *)
  | EView ->
      for i = 0 to pred ls.nmembers do
	for j = 1 to Queue.length s.to_deliver.(i) do 
	  let (abv,ev) = Queue.take s.to_deliver.(i) in
	  up ev abv
	done;
      done;
      upnm ev
  | _ -> upnm ev

  (* rcv ev from above, forward msg *)  
  and dn_hdlr ev abv = 
    match getType(ev) with
    | ECast ->
        (* we got a broadcast request from the application here *)
	if getNoTotal ev then (
	  dn ev abv NoHdr

	) else if s.blocking then (
	  eprintf "the view is blocked... dropping\n" ;
	  free name ev
	) else (
	  (* all members can cast the message immediately ! *)
	  if ls.nmembers > 1 then (

	    (* append the sequencer number and send it ... *)
    	    dn ev abv Cast;

	    if( ls.rank = s.seq_rank ) then (

	      (* if I'm the sequencer send the accept
                 - each message is uniqly indentified by
                   the senders rank and the sequence number *)
	      (*printf "sequencer sending accept for %d\n" s.curr_seq_num;*)

	      dnlm (create name ECast[Peer ls.rank]) (Acc ls.rank);

	      (* the sequencer delivers the message immediately *)
	      up (Event.set name ev[Peer ls.rank]) abv

	    ) else (
	      (* all others store their message and wait for
	         the accept *)

	      (*printf "storing own cast %d me %d -- %d\n"
		s.curr_seq_num ls.rank (getOrigin ev);*)

	      Queue.add (abv,(Event.set name ev[Peer ls.rank]))
		s.to_deliver.(ls.rank);

	    )
          )
        )
    | _ -> dn ev abv NoHdr

  (* rcv ev from above *)
  and dnnm_hdlr ev = match getType ev with
  | EBlock ->
      (* make sure we don't accept any broadcast while 
         the system is merging a new group *)
      s.blocking <- true;
      dnnm ev
  | _ -> dnnm ev

in {up_in=up_hdlr;uplm_in=uplm_hdlr;upnm_in=upnm_hdlr;dn_in=dn_hdlr;dnnm_in=dnnm_hdlr}


let l args vf = Layer.hdr init hdlrs None NoOpt args vf

let _ = Elink.layer_install name l
