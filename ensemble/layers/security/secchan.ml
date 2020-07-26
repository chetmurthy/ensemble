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
(* SECCHAN: Creating secure channels between ensemble processes.*)
(* Author: Ohad Rodeh  2/98 *)
(**************************************************************)
(* Fine points:
 * 1. Two members may setup channels to each other simultaniously. 
 *    To prevent this, we use a two phase protocol.
 * 2. A Channel must be constructed within one view, otherwise, 
 *    it is torn-down. Communication protocols should take this 
 *    into account.
 *
 *  Checking:

add this flag : 

armadillo -n 3 -prog rekey -pint secchan_cache_size=7 -ptime secchan_ttl=100 -ptime secchan_sweep=3 -pint secchan_rand=1

armadillo -n 5 -prog exchange -pint secchan_cache_size=7 -ptime secchan_ttl=100 -ptime secchan_sweep=3 -pint secchan_rand=1 -trace SECCHAN -trace SECCHAN1 -debug 


check cache (thrash it):
armadillo -n 3 -prog exchange -pint secchan_cache_size=1 -ptime secchan_ttl=100 -ptime secchan_sweep=3 -pint secchan_rand=1 -trace SECCHAN -trace SECCHAN1 -debug -pstr chk_secchan_prog=1_n 

* check sanity, withouth cache_checking.
armadillo -n 5 -prog exchange -pint secchan_cache_size=7 -ptime secchan_ttl=100 -ptime secchan_sweep=3 -pint secchan_rand=1 -trace SECCHAN -debug -pstr chk_secchan_prog=1_n -pa -terminate_time 2000 


armadillo -n 5 -prog exchange -pint secchan_cache_size=1 -ptime secchan_ttl=100 -ptime secchan_sweep=3 -pint secchan_rand=1 -trace SECCHAN -debug -pstr chk_secchan_prog=n_n -pa -terminate_time 2000 


*)

open Util
open Layer
open View
open Event
open Trans
open Shared
  
open Msecchan 
open Channel
(**************************************************************)
let name = Trace.filel "SECCHAN"
(**************************************************************)
  
type header = 
  | NoHdr
  | SealedKey of int * Auth.ticket (* The first int is for PERF measurement *)
  | Ack
  | Data of Buf.t  
  | CloseChan
  | CloseChanOk

  | To of int
  | From of int
      
type bckgr = 
  | B_Idle
  | B_Computing

type chan_gc = 
  | C_Idle
  | C_Removing

type request = 
  | Encrypt of rank * Buf.t
  | Decrypt of rank * int * Auth.ticket
      
    
let string_of_header = function
  | NoHdr -> "NoHdr"
  | SealedKey (i,_) -> "SealedKey(" ^ (string_of_int i) ^ ")"
  | Ack -> "Ack"
  | Data data -> "Data _" 
  | CloseChan -> "CloseChan"
  | CloseChanOk -> "CloseChanOk"
  | To _   -> "To _"
  | From _ -> "From _"
	
(**************************************************************)

(* The current time is actually only an estimate. It is resampled
 * every minute (by default).
*)
type state = {
  mutable pending      : (rank * Buf.t) Queuee.t ;
  channels             : (rank, (Time.t, Security.key, Buf.t, Buf.t) Channel.t) Hashtbls.t; 
  mutable blocked      : bool ;
  mutable bckgr        : bckgr ;
  mutable chan_gc      : chan_gc ;
  request              : request Queue.t ;
  saved                : (Endpt.id * Time.t * Time.t * Security.key * status) list ref ;
  mutable current_time : Time.t ;
  mutable next         : Time.t ;

  (* PERF measurement *)
  mutable num          : int ;
  mutable causal       : int ;
  mutable up_ERekeyPrcl : Event.t option ;

  ttl                  : Time.t ;
  sweep                : Time.t ;
  rand                 : int ;
  cache_size           : int ;
  debug                : bool ;
  causal_flag          : bool 
} 
    
(**************************************************************)
    
let dump (ls,vs) s =
  eprintf "SECCHAN:dump:%s\n" ls.name ;
  let l = Hashtbls.to_list s.channels in
  let s = string_of_list (fun (peer,c) ->
    sprintf "peer=%d %s" peer (Channel.string_of_t c)
  ) l in
  eprintf "links=%s\n" s

(**************************************************************)
    
let init s (ls,vs) = { 
  pending            = Queuee.create () ;
  channels           = Hashtbls.create 7;
  blocked            = false ;
  bckgr              = B_Idle ; 
  chan_gc            = C_Idle ;
  request            = Queue.create () ;
  saved              = s.secchan ;

  num                = 0 ;
  causal             = 0 ;
  up_ERekeyPrcl      = None ;

  current_time       = Time.zero ;    
  next               = Time.zero ;
  ttl                = Param.time vs.params "secchan_ttl" ;
  sweep              = Param.time vs.params "secchan_sweep" ;
  rand               = Param.int vs.params "secchan_rand" ; 
  cache_size         = Param.int vs.params "secchan_cache_size" ;
  debug              = Param.bool vs.params "secchan_debug" ;
  causal_flag        = Param.bool vs.params "secchan_causal_flag"
}
  
(**************************************************************)
  
let marshal m =
  let m = Marshal.to_string m [] in
  Buf.pad_string m
    
let unmarshal m = 
  let m = Buf.to_string m in
  let m = Marshal.from_string m 0 in
  (m : Buf.t * ('_a, '_b, '_c) Layer.msg)

let chans_of_hash h = 
  let l = ref ([] : int list) in
  Hashtbls.iter (fun r _ -> l:=r::!l ) h;
  !l
  
let hdlrs s ((ls,vs) as vf) {up_out=up;upnm_out=upnm;dn_out=dn;dnlm_out=dnlm;dnnm_out=dnnm} =
  let failwith = layer_fail dump vf s name in
  let ls_name = sprintf "%d,%s" ls.rank (Endpt.string_of_id_short ls.endpt) in
  let logs = Trace.log3 Layer.syncing ls.name name in
  let log = Trace.log2 name ls_name in
  let log1 = Trace.log2 (name^"1") ls_name in
  let log2 = Trace.log2 (name^"2") ls_name in
  let log3 = Trace.log2 (name^"3") ls_name in
  let log4 = Trace.log2 (name^"4") ls_name in
  let log5 = Trace.log2 (name^"5") ls_name in
  
  let endpt_of_rank r = Endpt.string_of_id_short (Arrayf.get vs.view r) in

  let shared = Cipher.lookup "RC4" in
  let encrypt key = Cipher.single_use shared key true
  and decrypt key = Cipher.single_use shared key false in
  let s_chan = Channel.create_s Time.zero Security.NoKey Time.ge encrypt decrypt in
  let chan_create key status = Channel.create s_chan key status in

  let sendMsg peer m = dnlm (Event.create name ESend[Peer peer; ForceVsync]) m in

  let close_chan_seq peer ch = 
    log1 (fun () -> sprintf "Closing channel to %d, cache too large" peer);
    sendMsg peer CloseChan ;
    setStatus ch SemiShut 
  in

  (* [close_lru_chan channel_set] Initiate the close sequence for the LRU channel, 
   * form the required set. 
   * 
   * There are two cases: 
   * 1. There is some LRU channel that can be closed.
   *    initiate the close sequence. 
   * 2. A channel has been chosen, and it will be closed in due time.
   *)
  let close_lru_chan () = 
    log1 (fun () -> "close_lru_chan");
    match find_lru s_chan s.channels with 
      | Some (peer_lru,ch) -> close_chan_seq peer_lru ch  
      | None -> ()
  in

  let freeze channels = 
    freeze s_chan (fun rank -> Arrayf.get vs.view rank) channels 
  and unfreeze ch_l = 
    unfreeze s_chan (fun e -> Arrayf.index e vs.view) ch_l s.channels
  in

  (* Add statistics to the ERekeyPrcl message. Statistics are
   * used by PERFREKEY, for performance measurements. 
   *)
  let create_ERekeyPrcl ev = 
    if s.causal_flag then 
      set name ev [SecStat (s.num,s.causal)]
    else 
      set name ev [SecStat (s.num,s.num+1)]
  in
	
  let handle = function
    | Encrypt (dst,new_key) -> 
	s.bckgr <- B_Computing ;
	s.num <- succ s.num ;
	s.causal <- succ s.causal;
	let dst_addr = Arrayf.get vs.address dst in
	dnlm (Event.create name EPrivateEnc [PrivateEnc (dst_addr,new_key)]) (To dst)
    | Decrypt (src,i,cipher_text) -> 
	s.bckgr <- B_Computing ;
	s.num <- succ s.num  ;
	if s.causal_flag then s.causal <- i + 1 + s.causal
	else s.causal <- succ s.causal;
	let dst_addr = Arrayf.get vs.address src in
	dnlm (Event.create name EPrivateDec [PrivateDec (dst_addr, cipher_text)]) (From src)
  in
  
  let push_request r = 
    if (Queue.length s.request = 0) 
      && s.bckgr = B_Idle then 
	handle r
    else
      Queue.add r s.request
	
  and pop_request () = 
    if Queue.length s.request > 0 then
      handle (Queue.take s.request) 
    else match s.up_ERekeyPrcl with 
      | None -> ()
      | Some ev -> 
	  upnm (create_ERekeyPrcl ev) ;
	  s.up_ERekeyPrcl <- None 
  in
  
  (* Add a message to the pending list.
     *)
  let add_pending dst msg = 
    log1 (fun () -> sprintf "added to s.pending (%d,_)" dst) ;
    Queuee.add (dst,msg) s.pending 
  in


  let send_sealed_key dst sealed_key = try 
    assert (not s.blocked);
    log2 (fun () -> sprintf "send_sealed_key -> %d" dst);
    if not s.blocked then 
      let c = Hashtbls.find s.channels dst in
      match getStatus c with 
	| Closed -> 
	    sendMsg dst (SealedKey (s.causal,sealed_key))
	| SemiOpen | OpenBlocked | Open ->
 	    log1 (fun () -> "A Channel from the other direction is being opened, not sending key.")
	| SemiShut | ShutBlocked -> 
	    failwith "Sanity, can't reopen channel while closing it"
  with Not_found -> failwith "Sanity, could not find channel"
  in

  (* Transition from OpenBlock to Open. 
   * 1. Send an ack to the other side. 
   * 2. Encrypt and send all pending messages.
   * 3. If the channel is marked for closing, then close it.
   *)
  let f_OpenBlock_to_Open ch peer key = 
    assert (not s.blocked);
    log (fun () -> sprintf "send_ack %s" (endpt_of_rank peer));
    sendMsg peer Ack;
    setStatus ch Open ;
    let msgs = getMsgs ch in
    Queue.iter (fun msg -> 
      let msg = send s_chan ch s.current_time msg in
      sendMsg peer (Data msg)
    ) msgs ;
    Queue.clear msgs ;
  in

  (* Open channel to me from [src] with encryption key [key].
   *)
  let open_chan_to_me src key = 
      let ch = chan_create key OpenBlocked in
      Hashtbls.add s.channels src ch;
      f_OpenBlock_to_Open ch src key
  in
  
  (* We provide some randomization in the end time_out, so as
   * stagger refresh times for channels created at the same time.
   * This is likely to occur with current security protocols.
   *)
  let recv_sealed_key src key = 
    log3 (fun () -> sprintf "recv_sealed_key %d" src);
    let key = Security.Common key in
    try 
      let ch = Hashtbls.find s.channels src in
      match getStatus ch with
	| Closed | SemiOpen -> 
	    if src < ls.rank then (
	      setKey ch key ;
	      setStatus ch  OpenBlocked ;
	      f_OpenBlock_to_Open ch src key
	    ) else
	      log (fun () -> "My rank is higher, dropping sealed_key")
	| OpenBlocked | Open | SemiShut | ShutBlocked -> 
	    failwith "in wrong state when recv_sealed_key"
    with Not_found -> open_chan_to_me src key

  in
  
  (* Recieve a secure message [msg] from [peer]
   *)
  let handle_data peer msg = try 
    let ch = Hashtbls.find s.channels peer in
    let msg = recv s_chan ch s.current_time msg in 
    let msg,abv = unmarshal msg in
    let e = (Event.create name ESecureMsg[Peer peer; SecureMsg msg])  in
    up e abv 
  with Not_found -> 
    failwith (sprintf "Sanity, received a SecureMsg from %d before the channel is set up." peer)
  in
  
  (* [open_chan_to_peer peer msg] Open a new channel to [peer] and enqueue [msg] to 
   * send.
     *)
  let open_chan_to_peer peer msg = 
    log1 (fun () -> sprintf "open_chan to %s" (endpt_of_rank peer));
    let ch = chan_create (Prng.create ()) Closed in
    Queue.add msg (getMsgs ch);
    Hashtbls.add s.channels peer ch;
    push_request (Encrypt (peer, (Security.buf_of_key (getKey ch))))
  in

  (* Handle a secure message [msg] to be sent to [dst]. 
   * 1.If a channel already exists, then send/enqueue. 
   * 2.If it does not exist, create the channel structure, enqueue the message, 
   *   and create a channel.
   * 3. If the channel is about to be closed then enqueue the message in
   * the pending list.
   * 
   *)
  let handle_secure_msg dst msg = try 
    let ch = Hashtbls.find s.channels dst in
    begin match getStatus ch with 
      | Closed | SemiOpen | OpenBlocked -> Queue.add msg (getMsgs ch)
      | Open -> 
	  let msg = send s_chan ch s.current_time msg in 
	  sendMsg dst (Data msg)
      | SemiShut | ShutBlocked -> add_pending dst msg
    end
  with Not_found -> 
    open_chan_to_peer dst msg
  in
  
  (* Remove a channel from the cache. 
   * 0. Remove the channel from the chan_set.
   * 1. Check whether there are pending messages to send.
   *)
  let remove_chan peer = try 
    let ch = Hashtbls.find s.channels peer in
    Hashtbls.remove s.channels peer;
    if not (Queuee.empty s.pending) then (
      let l = Queuee.to_list s.pending in
      Queuee.clear s.pending ;
      List.iter (fun (dst,msg) -> handle_secure_msg dst msg) l 
    );
    s.chan_gc <- C_Idle
  with Not_found -> failwith "Sanity, remove_chan, for a nonexistent channel"
  in

  (* If his rank is lower, ignore. Otherwise try to decrypt the (SealedKey t) and
   * establish a secure channel.
   *)
  let handle_sealed_key peer i t = try 
    let ch = Hashtbls.find s.channels peer in
    match getStatus ch with 
      | Closed | SemiOpen -> 
	  if peer < ls.rank then (
	    log1 (fun () -> sprintf "received a SealedKey from %d --- using it" peer);
	    setKey ch Security.NoKey; (* Ignore the SealedKey operation *)
	    push_request (Decrypt (peer,i,t))
	  ) else
	    log1 (fun () -> sprintf "received a SealedKey from %d --- ignoring" peer);
      | OpenBlocked | Open -> 
	  failwith (sprintf "Sanity, received a SealedKey from %d, although there is an open Channel already" peer)
      | SemiShut | ShutBlocked -> 
	  failwith (sprintf "Received a sealed_key but channel state is %s" (string_of_status (getStatus ch)))
  with Not_found -> push_request (Decrypt (peer,i,t))
  in	
  
  (* Received an Ack from member [peer].
   * 1. Send all pending messages on the queue.
   * 2. Check that the channel does not need to be closed. 
   *)
  let handle_ack peer = try 
    let ch = Hashtbls.find s.channels peer in
    setTime ch (rand_time2 s.current_time s.ttl s.rand) ;
    setStatus ch  Open;
    Queue.iter (fun msg -> 
      let msg = send s_chan ch s.current_time msg in 
      sendMsg peer (Data msg)
    ) (getMsgs ch);
    Queue.clear (getMsgs ch)
  with Not_found -> failwith "recieved Ack altough channel does not exist"
  in
  
  (* Close, Phase1 at receiver
   *)
  let close_chan peer = try
    let ch = Hashtbls.find s.channels peer in
    match getStatus ch with 
      | Closed | SemiOpen | OpenBlocked -> 
	  failwith ("recieved CloseChan although channel is in state "^
	    (string_of_status (getStatus ch)))
      | Open -> 
	  setStatus ch ShutBlocked;
	  if not s.blocked then (
	    remove_chan peer ;
	    sendMsg peer CloseChanOk
	  )
      | SemiShut | ShutBlocked -> 
	  log (fun () -> "received CloseChan when in SemiShut");
	  if not s.blocked then 
	    sendMsg peer CloseChanOk
  with Not_found -> failwith "recieved CloseChan although channel does not exist"
  in

  (* Close, Phase2 at sender
   *)
  let close_chan_ok peer = try
    let ch = Hashtbls.find s.channels peer in
    assert (getStatus ch = SemiShut);
    remove_chan peer
  with Not_found -> failwith "CloseChanOk although channel does not exist"
  in

  let up_hdlr ev abv () = up ev abv
    
  and uplm_hdlr ev hdr = 
    let peer = getPeer ev in
    begin match getType ev,hdr with
    | ESend, SealedKey (i,t) -> 
	log (fun () -> sprintf "SealedKey <- %s" (endpt_of_rank peer));
	if not s.blocked then 
	  handle_sealed_key peer i t 
	else log (fun () -> "blocked, so SealedKey is dropped");
	  
    | ESend, Ack -> 
	log (fun () -> sprintf "Ack <- %s" (endpt_of_rank peer));
	handle_ack peer
	  
    | ESend, Data msg -> 
	handle_data peer msg
	  
    | ESend, CloseChan -> 
	log (fun () -> sprintf "CloseChan <- %s" (endpt_of_rank peer));
	close_chan peer

    | ESend, CloseChanOk -> 
	log (fun () -> sprintf "CloseChanOk <- %s" (endpt_of_rank peer));
	close_chan_ok peer

    | EPrivateEncrypted, (To dst) -> 
	s.bckgr <- B_Idle ;
	if not s.blocked then (
	  let ticket = getPrivateEncrypted ev in
	  match ticket with
	    | None -> failwith (sprintf "Could not create a ticket")
	    | Some t -> 
		send_sealed_key dst t ; 
		pop_request ()
	) else (
	  log (fun () -> sprintf "blocked, dropped EPrivateEncrypted (To %d)" dst);
	  remove_chan dst;
	);
	
    | EPrivateDecrypted, (From src) -> 
	s.bckgr <- B_Idle ;
	if not s.blocked then (
	  let t = getPrivateDecrypted ev in 
	  match t with 
	    | None -> failwith (sprintf "Sanity, could not authenticate ticket")
	    | Some key -> 
		recv_sealed_key src key; 
		pop_request ()
	) else 
	  log2 (fun () -> sprintf "blocked, dropped EPrivateDecrypted (From %d)" src);
	free name ev

    | _,hdr -> failwith (sprintf "Sanity, unknown event type in uplm_hdlr %s" (string_of_header hdr))
    end;
    free name ev
	  
  and upnm_hdlr ev = match getType ev with
    | EFail | EBlock | ESyncInfo ->
	logs (fun () -> Event.string_of_type (getType ev));
	s.blocked <- true;
	upnm ev

    (* 1. Remove channels to members that have partitioned away. 
     * 2. Throw away all pending messages. 
     * 3. Freeze the current situation, continue in the next view. 
     *)
    | EView ->
	let new_vs = getViewState ev in
	let common = common vs.view new_vs.view in
	log2 (fun () -> sprintf "freezing common=%s view=%s new_view=%s"
	    (View.to_string common)
	    (View.to_string vs.view)
	    (View.to_string new_vs.view)
	);
	Hashtbls.iter (fun rank ch -> 
	  let e = Arrayf.get vs.view rank in
	  if not (Arrayf.mem e common) then 
	    Hashtbls.remove s.channels rank 
	) s.channels;
	s.saved := freeze s.channels ;
	upnm ev
	  
	  
    (* 1. unfreeze the channel list.
     * 2. Remove any channels that did not complete construction. 
     *)
    | EInit -> 
	s.current_time <- Event.getTime ev;
	log3 (fun () -> sprintf "Init time=%f" (Time.to_float s.current_time));
	unfreeze !(s.saved) ;
	s.saved := [];
	Hashtbls.iter (fun peer ch -> 
	  if getStatus ch <> Open then (
	    remove_chan peer ;
	    log5 (fun () -> sprintf "removing %s, state = %s" (endpt_of_rank peer) (string_of_status (getStatus ch)))
	  )
	) s.channels ;
	let l = chans_of_hash s.channels in 
	log2 (fun () -> sprintf "unfreeze, chans = %s" (string_of_list endpt_of_rank l)); 
	if s.debug then upnm (Event.create name ESecChannelList[SecChannelList l]);
	upnm ev
	  
    (* 1. Check every once in a while that channels are still fresh. 
     * 2. If the time is invalid, then the other side has to check freshness.
     * 3. Don't try to close if already in closing states. 
     * 4. If there are more channels than the allowed cache size, then remove one. 
     *)
    | ETimer -> 
	if not s.blocked then (
	  let time = Event.getTime ev in
	  s.current_time <- time;
	  if Time.ge time s.next then (
	    s.next <- Time.add s.sweep s.next;

	    Hashtbls.iter (fun peer ch -> 
	      if getTime ch <> Time.zero && 
		Time.ge s.current_time (getTime ch) && 
		getStatus ch <> SemiShut &&
		getStatus ch <> ShutBlocked then (
		  log1 (fun () -> sprintf "Closing channel to %d, timer" peer);
		  sendMsg peer CloseChan ;
		  setStatus ch SemiShut 
		);

	      if Hashtbls.size s.channels > s.cache_size 
		&& s.chan_gc = C_Idle then (
		  s.chan_gc <- C_Removing ;
		  close_lru_chan ()
		);

	    ) s.channels
	  )
	);
	upnm ev
	    
    | EDump -> ( dump vf s ; upnm ev )
	  
    | _ -> upnm ev
	  
  and dn_hdlr ev abv = match getType ev with
      (* Got a secureMsg to send  
       *)
    | ESecureMsg -> 
	if not s.blocked then (
	  let dst = getPeer ev in
	  let msg = getSecureMsg ev in
	  log2 (fun () -> sprintf "dst=%d,msg=_" dst);
	  let msg = marshal (msg,abv) in
	  ignore (handle_secure_msg dst msg)
	) else 
	  log2 (fun () -> "can't send SecureMsg while blocked, dropped")
	    
    | _ -> dn ev abv ()
	  

  and dnnm_hdlr ev = match getType ev with 
    | EFail | EBlock | ESyncInfo ->
	logs (fun () -> Event.string_of_type (getType ev));
	s.blocked <- true;
	dnnm ev

    (* This section sends up PERF information. 
     * Copy the mutable variables into immutable versions. Then send
     * back up.
     *)
    | ERekeyPrcl -> 
	log5 (fun () -> "ERekeyPrcl");
	if (Queue.length s.request = 0) 
	  && s.bckgr = B_Idle then 
	    upnm (create_ERekeyPrcl ev)
	else
	  s.up_ERekeyPrcl <- Some ev

    (* Close all channels, and clean all pending data. 
     *)
    | ERekeyCleanup -> 
	Queuee.clean (fun _ -> ()) s.pending;
	Hashtbls.clear s.channels;
	s.bckgr <- B_Idle;
	s.chan_gc <- C_Idle ;
	Queue.clear s.request;
	s.saved  := [];
	s.num <- 0 ;
	s.causal <- 0;
	upnm ev
	
    | _ -> dnnm ev
	  
  in {up_in=up_hdlr;uplm_in=uplm_hdlr;upnm_in=upnm_hdlr;dn_in=dn_hdlr;dnnm_in=dnnm_hdlr}
       
let l args vf = Layer.hdr init hdlrs None NoOpt args vf
  
let _ = 
  Param.default "secchan_cache_size" (Param.Int 7) ;
  Param.default "secchan_ttl" (Param.Time (Time.of_int (8 * 60 * 60))) ; (* 8 hours *)
  Param.default "secchan_sweep" (Param.Time (Time.of_int 5)) ;
  Param.default "secchan_rand" (Param.Int 200) ; (* Used to stagger channel refresh times *)
  Param.default "secchan_debug" (Param.Bool false);
  Param.default "secchan_causal_flag" (Param.Bool true);
  Elink.layer_install name l
    
(**************************************************************)
    
    
