(**************************************************************)
(* REFLECT.ML: server side of gossip transport *)
(* Author: Mark Hayden, 8/95 *)
(**************************************************************)
open Util
open View
open Appl_intf open New
(**************************************************************)
let name = Trace.file "REFLECT"
let failwith = Trace.make_failwith name
let log = Trace.log name
(**************************************************************)

(* This is the amount of time for which we will forward
 * gossip to another process without having heard from it.
 *)
let remove_timeout = Time.of_int 20

(* This is time before we will forward the same message
 * another time.
 *)
let repeat_timeout = Time.of_string "0.1"

let max_msg_len = Hsys.max_msg_len ()

(* This function returns the interface record that defines
 * the callbacks for the application.
 *)
let intf alarm sock =
  let clients = Hashtbl.create (*name*) 10 in

  let recv_gossip_r = ref (fun () -> ()) in
  let recv_gossip () = !recv_gossip_r () in

  Alarm.add_sock_recv alarm name sock (Hsys.Handler0 recv_gossip) ;

  let install (ls,vs) =
    if not !quiet then
      eprintf "REFLECT:view:%d:%s\n" ls.nmembers (View.to_string vs.view) ;
    let async = Appl.async (vs.group,ls.endpt) in
    let actions = Queuee.create () in
    let reflect (inet,port) msg =
      if ls.am_coord then (
	let time = Alarm.gettime alarm in
	let _,time',digest' = 
	  try Hashtbl.find clients (inet,port) with Not_found ->
	    let sendinfo = Hsys.sendto_info sock [|inet,port|] in
	    let digest = Digest.string "" in
	    let info = (sendinfo,(ref time),(ref digest)) in
	    Hashtbl.add clients (inet,port) info ;
	    info
	in
	let digest = Digest.string msg in
	
	if digest <> !digest' 
        || Time.ge time (Time.add !time' repeat_timeout)
	then (
	  digest' := digest ;
	  time'   := time ;
	  let dests = hashtbl_to_list clients in
	  List.iter (fun ((inet,port),(info,time',_)) ->
	    if Time.ge time (Time.add !time' remove_timeout) then (
	      if !verbose then
		eprintf "REFLECT:removing          (%s,%d)\n" 
		  (Hsys.string_of_inet inet) port ;
	      Hashtbl.remove clients (inet,port)
	    ) else (
	      if !verbose then
		eprintf "REFLECT:send_gossip: to   (%s,%d)\n" 
		  (Hsys.string_of_inet inet) port ;
	      Hsys.sendto info msg 0 (String.length msg)
	    )
	  ) dests
	)
      ) else (
	if Queuee.empty actions then
	  async () ;
	Queuee.add (Send([|vs.coord|],((inet,port),msg))) actions ;
      )
    in
      
    let recv_gossip =
      let buf = String.create max_msg_len in
      fun () ->
	if !verbose then 
	  eprintf "REFLECT:#clients=%d\n" (hashtbl_size clients) ;
	try
          let (len,inet,port) = Hsys.recvfrom sock buf 0 max_msg_len in
	  if !verbose then (
	    eprintf "REFLECT:recv_gossip: from (%s,%d)\n" 
	      (Hsys.string_of_inet inet) port ;
	    ) ;
	  let msg = String.sub buf 0 len in
	  reflect (inet,port) msg
	with e -> 
	  if !verbose then
	    eprintf "REFLECT:warning:%s\n" (Hsys.error e)
    in
    recv_gossip_r := recv_gossip ;

    let receive origin bl cs =
      match bl,cs with
      |	U,S -> (
	  fun (from,msg) ->
	    if !verbose then
	      eprintf "REFLECT:forwarded:origin=%s gossiper=(%s,%d)\n" 
	      	(Endpt.string_of_id (Arrayf.get vs.view origin))
	      	(Hsys.string_of_inet (fst from)) (snd from) ;
	    reflect from msg ;
	    [||]			(*BUG*)
	 )
      |	_ -> null
    in
    let block () = [||] in

    let heartbeat time =
      let sactions = Queuee.to_list actions in
      Queuee.clear actions ;
      let actions = Array.of_list sactions in
      actions
    in

    let handlers = { 
			flow_block = (fun _ -> ());
      heartbeat = heartbeat ;
      receive = receive ;
      block = block ;
      disable = Util.ident
    } in
    [||],handlers
  in

  let exit () = () in

  {
    heartbeat_rate = Time.of_int 1 ;
    install = install ;
    exit = exit
  }

(**************************************************************)

let init alarm (ls,vs) port force =
  (* Figure out port information and bind to it.
   *)
  let host = Hsys.gethost () in
  let localhost = Hsys.inet_of_string "localhost" in
  if not !quiet then
    eprintf "REFLECT:server starting on %s\n" (Hsys.string_of_inet host) ;

  let hosts = Arge.check name Arge.gossip_hosts in
  let hosts = Arge.inet_of_string_list Arge.gossip_hosts hosts in

  (* Check that I'm in my list of gossip hosts.
   *)
  if (not force) 
  && (not (List.mem host hosts)) 
  && (not (List.mem localhost hosts)) 
  then (
    if not !quiet then (
      eprintf "REFLECT:I'm not in the list of gossip hosts, exiting\n" ;
      eprintf "  (the hosts are %s)\n" 
        (string_of_list Hsys.string_of_inet hosts) ;
    ) ;
    exit 1
  ) ;

  if not !quiet then
    eprintf "REFLECT:server binding to port %d\n" port ;

  (* Create datagram socket.
   *)
  let sock = Hsys.socket_dgram () in

  (* Try to disable error ICMP error reporting.
   *)
  begin try
    Hsys.setsockopt sock (Hsys.Bsdcompat true)
  with e ->
    log (fun () -> sprintf "warning:setsockopt:Bsdcompat:%s" (Hsys.error e))
  end ;

  (* Bind it to the gossip port.
   *)
  begin
    try Hsys.bind sock (Hsys.inet_any()) port with e ->
      (* Don't bother closing the socket.
       *)
      if not !quiet then (
	eprintf "REFLECT:error when binding to port\n" ;
	eprintf "  (this probably means that a gossip server is already running)\n" ;
      ) ;
      raise e
  end ;

  if not !quiet then
    eprintf "REFLECT:server ready\n" ;

  (*
   * Initialize the application interface.
   *)
  let interface = intf alarm sock in

  (* Ensure that groupd is unset.
   *)
  let properties = Property.vsync in
  let protocol = Property.choose properties in
  let vs = View.set vs [
    Vs_groupd false;
    Vs_proto_id protocol
  ] in
  let ls = View.local name ls.endpt vs in
  let interface = full interface in
  ((ls,vs),interface)

(**************************************************************)

let _ =
  Elink.put Elink.reflect_init init

(**************************************************************)
