(**************************************************************)
(* MNAK.ML : FIFO, reliable multicast protocol *)
(* Author: Mark Hayden, 12/95 *)
(* Based on code by: Robbert vanRenesse *)
(**************************************************************)
open View
open Event
open Util
open Layer
open Trans
(**************************************************************)
let name = Trace.filel "MNAK"
let name_nak = addinfo "nak" name
(**************************************************************)
(* Data(seqno): sent with message number 'seqno'

 * Retrans(seqno): sent with the retransmission of member
 * 'rank's messsage number 'seqno.'

 * Nak(rank,lo,hi): request for retransmission of messages
 * number 'lo' to 'hi'. 
 * BUG: comment should say, inclusive/exclusive.

 *)
type header = NoHdr
  | Data    of seqno
  | Retrans of rank * seqno
  | Ack     of seqno
  | Nak     of rank * seqno * seqno

let string_of_header = function
  | NoHdr -> "NoHdr"
  | Data seqno -> sprintf "Data(%d)" seqno
  | Ack seqno -> sprintf "Ack(%d)" seqno
  | Retrans(rank,seqno) -> sprintf "Retrans(%d,%d)" rank seqno
  | Nak(rank,lo,hi) -> sprintf "Nak(%d,%d,%d)" rank lo hi

(**************************************************************)
(* These are for optimizations in the Layer module.
 * They take advantage of the similar representation
 * between headers and options.
 *)

let _ =
  if Some 23 <> Obj.magic (Data 23) then
    failwith "MNAK:tag sanity"

let extractor = function 
  | (Data _) as d -> (Obj.magic d : seqno option)
  | _ -> None

let constructor = function
  | None -> failwith sanity
  | (Some _) as s -> (Obj.magic s : header)

(**************************************************************)

(* selectively delete messages that all but fuzzy received
 *)
let selective_fuzzy local global mins myrank nmembers k buf =
  (* We want to make sure we keep at least two copies of each message *)
  let k = if nmembers >= 2*k then k else nmembers / 2 in
  let k = if k < 1 then 1 else k in
  let kth = nmembers / k in
  for rank = 0 to pred nmembers do
    if rank <> myrank then
      let modrank = rank mod k in
      let start = Arrayf.get mins rank in
      let stop = pred (Arrayf.get local rank) in
      for seqno = start to stop do
        if (seqno mod kth) <> modrank then
          Iq.clear_item (Arrayf.get buf rank) seqno
      done
  done
  
(* compress messages that all but fuzzy received
 *)
let compress_fuzzy local global mins myrank nmembers k buf =
  failwith "compress_fuzzy not yet implemented"
  
(* stripe messages that all but fuzzy received using a (k,n) method
 *)
let shared_fuzzy local global mins myrank nmembers k buf =
  failwith "shared_fuzzy not yet implemented"
  
(* In this policy, we keep all messages
 *)
let never_fuzzy _ _ _ _ _ _ _ =
  ()
  
let default_handle_fuzzy = never_fuzzy

let fuzzy_handlers =
  [ ("Selective",selective_fuzzy);
    ("Shared",shared_fuzzy);
    ("Compress",compress_fuzzy);
    ("Never",never_fuzzy)
  ]

(**************************************************************)

let _ = Random.self_init ()

let always () = true

let sometimes n () =
  (Random.int n) = 0

let high_probability n recently_heard =
  let range = int_min 4 ((n+1)/2) in
  let range = if recently_heard then 2*range else range in
  if range <=1 then always
  else sometimes range

let low_probability n recently_heard =
  let range = (n+1)/2 in
  let range = if recently_heard then 2*range else range in
  if range <=1 then always
  else sometimes range

(**************************************************************)
type 'abv state = {
  mutable coord : rank;
  mutable failed : bool Arrayf.t ;
  buf		 : 'abv Iq.t Arrayf.t ;
  naked		 : seqno array ;

  acked          : seqno array ;
  mutable acker  : rank ;
  mutable recently_heard : (seqno*seqno) array;

  fuzzy_th : int ;
  fuzzy_k : int ;
  local_fuzzy : bool array ;
  handle_fuzzy : seqno Arrayf.t -> seqno Arrayf.t -> seqno Arrayf.t -> rank ->
                                  int -> int -> 'abv Iq.t Arrayf.t -> unit ;
  neighbor_nak : bool ; (* Whether to transmit Naks only to my neighbors *)
  mutable timer_timeout : Time.t
(*
  mutable acct_size  : int ;		(* # bytes buffered *)
  dbg_n		 : int array
*)
}

(**************************************************************)

let dump vf s = Layer.layer_dump name (fun (ls,vs) s -> [|
  sprintf "failed   =%s\n" (Arrayf.bool_to_string s.failed) ;
  sprintf "cast_lo  =%s\n" (Arrayf.int_to_string (Arrayf.map Iq.lo s.buf)) ;
  sprintf "cast_hi  =%s\n" (Arrayf.int_to_string (Arrayf.map Iq.hi s.buf)) ;
  sprintf "cast_read=%s\n" (Arrayf.int_to_string (Arrayf.map Iq.read s.buf)) ;
  sprintf "fuzzy_th=%d\n" s.fuzzy_th ;
  sprintf "fuzzy_k=%d\n" s.fuzzy_k ;
  sprintf "local_fuzzy=%s\n" (string_of_array string_of_bool s.local_fuzzy)
(*
  ; sprintf "dbg_n  =%s\n" (string_of_int_array s.dbg_n)
  ; for i = 0 to pred ls.nmembers do
    sprintf "buf(%d)=%s\n" i (string_of_int_list (List.map fst (Iq.list_of_iq s.buf.(i))))
  done
*)
|]) vf s

(**************************************************************)

let init _ (ls,vs) = 
  let buf = Arrayf.init ls.nmembers (fun _ -> Iq.create name Local_nohdr) in
  let iq_init = Param.int vs.params "mnak_iq_init" in
  if iq_init > 0 then
    Arrayf.iter (fun iq -> Iq.grow iq iq_init) buf ;
  { coord      = 0;
    buf        = buf ;
    failed     = ls.falses ;
    naked      = Array.create ls.nmembers 0 ;
    recently_heard = Array.create ls.nmembers ((-1),(-1));

    acked      = Array.create ls.nmembers 0 ;
    acker      = (succ ls.rank) mod ls.nmembers ;
    neighbor_nak = Param.bool vs.params "mnak_neighbor" ;
    fuzzy_th   = Param.int vs.params "mnak_fuzzy_th" ;
    fuzzy_k    = Param.int vs.params "mnak_fuzzy_k" ;
    local_fuzzy = Array.create ls.nmembers false ;
    timer_timeout = Time.zero;
    handle_fuzzy =
      try
        List.assoc (Param.string vs.params "mnak_fuzzy_policy") fuzzy_handlers
      with _ ->
        default_handle_fuzzy
    
(*
    acct_size  = 0 ;
    dbg_n      = Array.create ls.nmembers 0
*)
  }

(**************************************************************)

let hdlrs s ((ls,vs) as vf) {up_out=up;upnm_out=upnm;dn_out=dn;dnlm_out=dnlm;dnnm_out=dnnm} =
  let log = Trace.log2 name ls.name in
  let log1 = Trace.log2 (name^"1") ls.name in
  let logn = Trace.log2 (name^"N") ls.name in (* Naks *)
  let logb = Trace.log3 Layer.buffer ls.name name in
  let failwith = layer_fail dump vf s name in

  (* Arguments to two functions below:
   * - rank: rank of member who's cast I've just gotten (or heard about)
   * - seqno: seqno of message from member 'rank'
   *)

  (*
   * CHECK_NAK: checks if missing a message, and sends appropriate
   * Nak. If there is a hole then send a Nak to (in this order):
   * 1. to original owner of message if he is not failed or fuzzy.
   * 2. to coord if I'm not the coord and coord is not fuzzy
   * 3. to entire group
   *)
  let check_nak rank is_stable =
    let buf = Arrayf.get s.buf rank in
    if_some (Iq.read_hole buf) (fun (lo,hi) ->
      if is_stable || (hi > s.naked.(rank)) then (
(*
	if seqno >= lo then (
*)
	  (* Keep track of highest msg # we've naked.
	   *)
	      s.naked.(rank) <- int_max s.naked.(rank) hi ;
	  logn (fun () -> sprintf "send:Nak(%d,%d..%d).\n" rank lo hi) ;

    if s.neighbor_nak then (
      let (know_lo,know_hi) = s.recently_heard.(rank) in
        if lo < know_lo || hi > know_hi then (
          let nak_ev = castUnrel name in
          let nak_ev = set name nak_ev [TTL 1] in
            dnlm nak_ev (Nak(rank,lo,hi))
        )
    ) else
      if not (Arrayf.get s.failed rank) && not s.local_fuzzy.(rank) then (
	      dnlm (sendPeer name rank) (Nak(rank,lo,hi))
      ) else if s.coord <> ls.rank && not s.local_fuzzy.(s.coord) then (
	      dnlm (sendPeer name s.coord) (Nak(rank,lo,hi))
	    ) else (
	      (* Don't forget to set the Unreliable option
	       * for the STABLE layer (see note in stable.ml).
	       *)
	      dnlm (castUnrel name)  (Nak(rank,lo,hi))
	    )
(*
	)
*)
      )
    )
  in

  (* READ_PREFIX: called to read messages from beginning of buffer.
   *)
  let read_prefix rank =
    let buf = Arrayf.get s.buf rank in
    Iq.read_prefix buf (fun seqno iov abv ->
      log (fun () -> sprintf "read_prefix:%d:Data(%d)" rank seqno) ;
      let iov = Iovecl.copy iov in
      up (castPeerIov name rank iov) abv
    ) ;

(*  if Iq.read buf >= s.naked.(rank) then*) (
      check_nak rank false
    )
  in

  (*
   * RECV_CAST: called when a cast message is recieved,
   * either as a data message or a retranmission.
   * This function is on the "slow path," the fast
   * path is in the up_hdlr for ECast.
   *)
  let recv_cast rank seqno abv iov =
    (* Add to buffer and check if events are now in order.
     *)
    let buf = Arrayf.get s.buf rank in
    if Iq.assign buf seqno iov abv then (
      log (fun () -> sprintf "recv_cast:%d:assign=%d" rank seqno) ;
      read_prefix rank
    ) else (
(*      log (fun () -> sprintf "recv_cast:%d:dropping redundant msg:seqno=%d" rank seqno) *)
    )
  in

  let up_hdlr ev abv hdr = match getType ev, hdr with

    (* ECast:Data: Got a data message from other
     * member.  Check for fast path or call recv_cast.
     *)
  | ECast iovl, Data(seqno) ->
      let origin = getPeer ev in
(*      assert (not (Arrayf.get s.failed origin)) ; *)
      let buf = Arrayf.get s.buf origin in

      (* Check for fast-path.
       *)
      if Iq.opt_insert_check buf seqno then (
	(* Fast-path.
	 *)
	(* The assignment below is unnecessary, but is
	 * added for the functional optimizations.
	 *)
	(*Arraye.set s.buf origin*) let _ = (Iq.opt_insert_doread buf seqno iovl abv) in
(*
      	if seqno <> s.dbg_n.(o) then failwith sanity ;
	s.dbg_n.(o) <- succ s.dbg_n.(o) ;
*)   	
	up ev abv
      ) else (
      	recv_cast origin seqno abv iovl ;
        free name ev
      )

    (* ESend:Ack: Got an ack.
     *)
  | ESend _, Ack seqno ->
      (* Update the ack entry.
       *)
      let origin = getPeer ev in
      if seqno > s.acked.(origin) then
	s.acked.(origin) <- seqno ;

      (* Scan through the acks.
       *)
      let init = s.acker in
      if ls.nmembers > 2 then (
	while
	  let next = Arrayf.get ls.loop s.acker in
	  next <> init &&
	  s.acked.(next) >= s.acked.(s.acker) 
	do
	  s.acker <- Arrayf.get ls.loop s.acker
	done
      ) ;

      (* GC any newly freed messages.
       *)
      let buf = Arrayf.get s.buf ls.rank in
(*
      Iq.set_lo buf s.acked.(Arrayf.get ls.loop s.acker) ;
*)

      up ev abv

    (* Retrans: Got a retransmission.  Always use the slow
     * path.  
     *)
  | (ECast iov|ESend iov|ECastUnrel iov|ESendUnrel iov), Retrans(rank,seqno) ->
      if rank <> ls.rank then (
(*      	log (fun () -> sprintf "retrans:%d->%d->me:seqno=%d" rank (getPeer ev) seqno) ; *)
(*
      	eprintf "MNAK:Cast:Retrans:seqno=%d\n" seqno ;
	let buf = s.buf.(rank) in
	let l = Iq.list_of_iq buf in
	let l = List.map fst l in
	sprintf "head=%d,read=%d,tail=%d,%s\n" 
	  (Iq.lo buf) (Iq.read buf)
	  (Iq.hi buf) (string_of_int_list l)
*)
        recv_cast rank seqno abv iov ;
      ) ;
      free name ev

  | _, NoHdr -> up ev abv
  | _        -> failwith bad_header

  and uplm_hdlr ev hdr = match getType ev,hdr with

    (* Nak: got a request for retransmission.  Send any
     * messages I have in the requested interval, lo..hi.
     *)
  | (ESend iov|ECast iov|ECastUnrel iov|ESendUnrel iov), Nak(rank,lo,hi) ->
      (* Retransmit any of the messages asked for that I have.
       *)
      (* TODO: check if request is for message from failed member
       * and I'm coordinator and I don't have what is being asked for
       *)
      let recently_heard = 
        let (know_lo,know_hi) = s.recently_heard.(rank) in
        let new_lo = min lo know_lo in
        let new_hi = max hi know_hi in
          if new_lo < lo || new_hi > hi then (
            s.recently_heard.(rank) <- (new_lo,new_hi);
            true
          )
          else
            false
      in
        


      let origin = getPeer ev in
      if s.neighbor_nak &&  origin = ls.rank then
        logn (fun () -> sprintf "Received my own NAK cast.  Ignoring.\n")
      else begin
        let ttl = match getTTL ev with
          Some(x) -> x
        | None -> 0 
        in
      logn (fun () -> sprintf "recd:origin=%d:original=%d:Nak(%d..%d), ttl=%d\n" origin rank lo hi ttl) ;
      let buf = Arrayf.get s.buf rank in

      (* We do not retransmit messages that we have not been
       * able to read.  See the notes for Iq.clean_unread in
       * the Efail handler.  Note: this should probably be
       * [pred (Iq.read buf)], but then again there should
       * be no messages in that last slot.
       *
       * We retransmit according to the following rules:
       * 1) If I am coordinator or original sender, I always reply
       * 2) Else, if (not coord or originator and) coordinator is fuzzy,
       *          reply with high probability (max{2/n,1/4})
       * 3) Else, (not coord or originator and coordinator is not fuzzy)
       *          reply with low probability (2/n)
       *)
      let hi = int_min hi (Iq.read buf) in

      let reply_policy =
        if rank = ls.rank or ls.rank = s.coord or
                  s.handle_fuzzy == selective_fuzzy or
                  s.handle_fuzzy == shared_fuzzy then
          always
        else if s.local_fuzzy.(s.coord) then
          high_probability ls.nmembers recently_heard
        else
          low_probability ls.nmembers recently_heard
      in
      
      for seqno = lo to hi do
        if reply_policy () then
          match Iq.get buf seqno with
          | Iq.GData(iov,abv) ->
              let iov = Iovecl.copy iov in
              dn (sendUnrelPeerIov name origin iov) abv (Retrans(rank,seqno))
	| Iq.GReset | Iq.GUnset ->
	    (* Do nothing...
	     *)
	    log (fun () -> sprintf "Nak from %d for message I think is Unset or Reset" origin) ;
      done ;

      logn (fun () -> sprintf "SEND: Retransmitting some parts of %d..%d to %d\n" lo hi origin);
      end;
      free name ev


  | _ -> failwith unknown_local

  and upnm_hdlr ev = match getType ev with
    (* EFail: Mark failed members, find out who is the new
     * coordinator, and pass on up.  
     *)
  | EFail ->
      s.failed <- getFailures ev ;

      (* Find out who's the new coordinator.
       *)
      s.coord <- Arrayf.min_false s.failed ;

      (* Clear all messages in our buffers from failed
       * processes that we haven't read yet.  If all
       * processes do this in a consistent cut, we guarantee
       * that any message from a failed process that can be
       * delivered has been delivered at some process.  This
       * is necessary for the Vsync layer to function
       * properly.  
       *)
      for i = 0 to pred ls.nmembers do
	if Arrayf.get s.failed i then (
	  let buf = Arrayf.get s.buf i in
	  log (fun () -> sprintf "EFail:%d:cleaning %d" i (Iq.read buf)) ;
	  Iq.clear_unread buf
	)
      done ;

      upnm ev

    (* Got new fuzzy information. Remember who is fuzzy
     *)
  | EFuzzy ->
      Arrayf.iteri (fun i fuzziness ->
        s.local_fuzzy.(i) <- (fuzziness > s.fuzzy_th)
      ) (getLocalFuzziness ev) ;

      upnm ev

    (* Stability protocol is requesting information about my
     * buffers.  I pass up the seqno of messages that I've
     * read so far.  Note that I could tell about the
     * messages I've received but not delivered yet (because
     * they are out of order), but I suspect that would
     * introduce liveness problems.  
     *)
  | EStableReq ->
      let casts = Arrayf.map Iq.read s.buf in
      upnm (set name ev [NumCasts casts])

    (* EStable: got stability and num casts information.
     * 1. garbage collect now-stable messages.
     * 2. check for any messages I'm missing.
     *)
  | EStable ->
      (* GC any messages that are now stable.
       *)
      let mins = getStability ev in
      for rank = 0 to pred ls.nmembers do
	let buf = Arrayf.get s.buf rank in
	let min = Arrayf.get mins rank in
        Iq.set_lo buf min
      done ;

      (* Check if there are some messages that we haven't
       * gotten yet.  
       *)
      (* TODO: when max=stable then we must zap the iq (you remember why...) *)
      let maxs = getNumCasts ev in
      for rank = 0 to pred ls.nmembers do
      	if rank <>| ls.rank then (
	  let buf = Arrayf.get s.buf rank in
	  Iq.set_hi buf (Arrayf.get maxs rank) ; (*BUG?*)
	  check_nak rank true
	)
      done ;

      (* Handle messages that were acked by all except for fuzzy nodes
       * Issue - a conflict between partial deletion of messages and
       * probabilistic retransmission policy. So, either ones should be
       * employed, but not both.
       *)
      s.handle_fuzzy (getLocalFuzzyStability ev) (getGlobalFuzzyStability ev)
                          mins ls.rank ls.nmembers s.fuzzy_k s.buf;

      upnm ev

  | EExit ->
      (* GC all buffers.
       *)
      Arrayf.iter Iq.free s.buf ;
      upnm ev

  | EAccount ->
      (* Dump information about status of buffers.
       *)
(*
      logb (fun () -> sprintf "total bytes=%d" s.acct_size) ;
*)
      logb (fun () -> sprintf "msgs=%s"
        (Arrayf.int_to_string (Arrayf.map (fun c -> Iq.read c - Iq.lo c) s.buf)));
      upnm ev

  | EDump -> ( dump vf s ; upnm ev )
  | EInit -> dnnm (timerAlarm name Time.zero); upnm ev
  | ETimer -> 
      if Time.ge (getTime ev) s.timer_timeout then (
        for i = 0 to pred ls.nmembers do
          s.recently_heard.(i) <- (-1,-1)
        done;
        s.timer_timeout <- Time.add (getTime ev) (Time.of_int 1);
        dnnm (timerAlarm name s.timer_timeout);
      );
      upnm ev

  | _ -> upnm ev

  and dn_hdlr ev abv = match getType ev with

    (* ECast: buffer a copy and send it on.
     *)
  | ECast iov ->
      let buf = Arrayf.get s.buf ls.rank in
      let seqno = Iq.read buf in
      assert (Iq.opt_insert_check buf seqno) ;
      
      if (Iovecl.array_len iov > 0) then (
        let iov1 = Iovecl.get iov 0 in
        let num_refs = Iovec.num_refs iov1 in
        if num_refs < 3 then 
          log1 (fun () -> sprintf "ECast(len=%d, refs=%d)" (Buf.int_of_len (Iovec.len iov1)) num_refs);
      );

      (* The assignment below is unnecessary, but is
       * added for the functional optimizations.
       *)
      (*Arraye.set s.buf ls.rank*) let _ = (Iq.opt_insert_doread buf seqno iov abv) in
(*
      s.acct_size <- s.acct_size + getIovLen ev ;
*)
      dn ev abv (Data seqno)

  | ESend _ ->
      if getApplMsg ev then (
	dn ev abv NoHdr
      ) else (
	let buf = Arrayf.get s.buf (getPeer ev) in
	let seqno = Iq.read buf in
	dn ev abv (Ack seqno)
      )

  | _ -> dn ev abv NoHdr

  and dnnm_hdlr = dnnm

in {up_in=up_hdlr;uplm_in=uplm_hdlr;upnm_in=upnm_hdlr;dn_in=dn_hdlr;dnnm_in=dnnm_hdlr}

let l args vs = Layer.hdr init hdlrs None (LocalSeqno(NoHdr,C_ECast,extractor,constructor)) args vs
let l2 args vs = Layer.hdr_noopt init hdlrs args vs

let _ = 
  Param.default "mnak_iq_init" (Param.Int 0) ;
  Param.default "mnak_neighbor" (Param.Bool true) ;
  Param.default "mnak_fuzzy_th" (Param.Int 10) ;
  Param.default "mnak_fuzzy_k" (Param.Int 3) ;
  Param.default "mnak_fuzzy_policy" (Param.String "Never") ;
  Layer.install name l

(**************************************************************)
