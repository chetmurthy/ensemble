(**************************************************************)
(* HSYSSUPP.ML *)
(* Author: Mark Hayden, 6/96 *)
(**************************************************************)
(* This modules is used for managing TCP connections.
 * It provides support for sending and receiving packets
 * over streams.  It takes into account the possibility
 * that the send and receive operations will not send
 * data in increments of 4 bytes.  *)
(**************************************************************)
open Trans
open Util
open Buf
(**************************************************************)
let name = Trace.file "HSYSSUPP"
let failwith = Trace.make_failwith name
let log = Trace.log name
(**************************************************************)

type 'a conn =
  (debug -> (Iovecl.t -> unit) ->
  ((Iovecl.t -> unit) * (unit -> unit) * 'a))

let word_len = 4
let mask1 = pred word_len
let mask2 = lnot mask1

(* Round up/down to next multiple of 4.
 *)
let is_len i = i land mask1 = 0
let floor i = i land mask2
let ceil i = (i + mask1) land mask2

let empty = ""

let string_empty s =
  String.length s = 0

let string_sub b o l =
  if l = 0 then empty else
    String.sub b o l

let recv_chan debug deliver =
  let qlen = ref len0 in
  let plen = ref len0 in
  let q = Queuee.create () in
  let rec recv iov =
    assert (Iovec.len debug iov <>|| len0) ;
    
    (* If this is the first part of packet, get length
     * and strip off those bytes.
     *)
    let iov =
      if !plen <>|| len0 then (
	iov
      ) else (
	assert (!qlen =|| len0) ;
	plen := Iovec.read_net_len debug iov len0 ;
	let len = Iovec.len debug iov in
	let iov = Iovec.sub_take debug iov len4 (len -|| len4) in
	iov
      )
    in

    let len = Iovec.len debug iov in
    qlen := !qlen +|| len ;
    if !qlen <|| !plen then (
      (* Not a full packet yet, just add this one to the queue.
       *)
      Queuee.add iov q
    ) else (
      (* Add in the portion of this iovec needed to complete
       * the current packet.
       *)
      let rem = !qlen -|| !plen in
      let iov_hd = Iovec.sub debug iov len0 (len -|| rem) in
      Queuee.add iov_hd q ;

      (* Convert the queue of Iovec's into an Iovecl.
       *)
      let hd = Queuee.to_array q in	(* clears the queue *)
      let hd = Arrayf.of_array hd in
      let hd = Iovecl.of_iovec_array hd in
      deliver hd ;

      (* Re-initialize state and insert remainder of iovec.
       *)
      assert (Queuee.empty q) ;
      plen := len0 ;
      qlen := len0 ;
      if rem =|| len0 then (
	Iovec.free debug iov
      ) else (
	let iov_tl = Iovec.sub_take debug iov (len -|| rem) rem in
	recv iov_tl
      )
    )
  in

  let disable () =
    Queuee.iter (Iovec.free debug) q
  in
  recv,disable

let tcp debug alarm sock deliver disable =
  Util.disable_sigpipe () ;
  let mbuf = Alarm.mbuf alarm in
  let debug = Refcnt.info2 name "tcp" debug in 
  let connected = ref true in

  let send_state = ref None in
  let deliver,disable_del = recv_chan debug deliver in

  (* Space for partial recvs.
   *)
  let recv_part = ref empty in

  let send_info = Hsys.send_info sock in

  (* Temporary scribbling area.
   *)
  let scribble = Buf.create len4 in

  let select_info =
    let sa = [|sock|] in
    let ba = [|false|] in
    Hsys.select_info None (Some(sa,ba)) None
  in

  let disable () =
    connected := false ;
    disable () ;
    disable_del () ;
    Alarm.rmv_sock_recv alarm sock ;
    if !send_state <> None then (
      Alarm.rmv_sock_xmit alarm sock
    ) ;
    Hsys.close sock
  in

  let read buf ofs len =
    let ofs = int_of_len ofs in
    let len = int_of_len len in
    let len = Buf.recv_hack sock buf ofs len in
    if is_len len then (
      (len_of_int len),empty
    ) else (
      let flen = floor len in
      let flenb = len_of_int flen in
      let part = Buf.sub debug buf (len_of_int ofs +|| flenb) len4 in
      let part = Buf.to_string part in
      let part = string_sub part 0 (len land 3) in
      (len_of_int flen), part
    )
  in
(*
  let try_deliver () =
    let len = Iovecl.len debug !recv_iovl in
    if len >=|| len4 then (
      let pac_len = Iovecl.read_net_len debug !recv_iovl len0 in
      assert (pac_len >=|| len0) ;
      if pac_len +|| len4 <=|| len then (
	let hd = Iovecl.sub debug !recv_iovl len4 pac_len in
	let hd = Iovecl.take debug hd in
	deliver hd ;
	let tl = Iovecl.sub_take debug !recv_iovl (len4 +|| pac_len) (len -|| (len4 +|| pac_len)) in
	recv_iovl := tl ;
	true
      ) else false
    ) else false
  in
*)
  let recv () =
    if !connected then (
      if string_empty !recv_part then (
	(* No partial data, try to read a big block.
	 *)
	let iov,part = Mbuf.alloc_fun debug mbuf read in
	let len = Iovecl.len debug iov in
	if len =|| len0 && string_empty part then (
	  log (fun () -> sprintf "HSYSSUPP:0 return on receive[1]") ;
	  disable ()
	) else (
	  if not (string_empty part) then
	    recv_part := part ;
	  if len <> len0 then (
	    (* It must be a singleton.
	     *)
	    assert (Iovecl.is_singleton debug iov) ;
	    let iov = Iovecl.get_singleton debug iov in
	    deliver iov
	  )
	)
      ) else (
	(* When we have some partial data, then just try to
	 * read the remainder of the 4 byte block.  Performance
	 * should not matter much here.
	 *)
	let len = 4 - String.length !recv_part in
	let buf = String.create len in
	let len_new = Hsys.recv sock buf 0 len in
	if len_new = 0 then (
	  log (fun () -> sprintf "HSYSSUPP:0 return on receive[2]") ;
	  disable ()
	) else if len_new = len then (
	  let buf = !recv_part ^ buf in
	  assert (Buf.is_len (String.length buf)) ;
	  let iov = Iovec.of_string debug buf in
	  recv_part := empty  ;
	  deliver iov ;
	) else (
	  recv_part := !recv_part ^ (string_sub buf 0 len_new) ;
	  assert (String.length !recv_part < 4)
	)
      )
    )
  in

  let send_split iovl ret =
    let len = Iovecl.len name iovl in
    assert (ret < int_of_len len) ;
    let floor = Buf.floor ret in
    let ceil = Buf.ceil ret in
    let part =
      if is_len ret then
	empty
      else (
	let part = Iovecl.sub name iovl floor len4 in
	let part = Iovecl.flatten name part in
	let part = Iovec.to_string name part in
	string_sub part (ret land 3) (4 - (ret land 3))
      )
    in
    let iovl =
      if ceil = len0 then
	iovl
      else
	Iovecl.sub_take debug iovl ceil (len -|| ceil) 
    in
    (iovl, part)
  in

  let writer () =
    if !connected then (
      match !send_state with
      | None -> 
	  log (fun () -> sprintf "HSYSSUPP:warning")
      | Some(send_part,q) ->
	  if string_empty !send_part then (
	    assert (not (Queuee.empty q)) ;
	    let iovlr = Queuee.peek q in
	    let ret = Iovecl.sendv send_info !iovlr in
	    let len = Iovecl.len debug !iovlr in
	    if ret = int_of_len len then (
	      Iovecl.free debug !iovlr ;
	      ignore (Queuee.take q)
	    ) else (
	      let sub, part = send_split !iovlr ret in
	      assert (Iovecl.len debug sub <> len0) ;
	      iovlr := sub ;
	      send_part := part
	    ) 
	  ) else (
	    let len = String.length !send_part in
	    let ret = Hsys.sendp send_info !send_part 0 len in 
	    send_part := string_sub !send_part ret (len - ret)
	  ) ;

	  if Queuee.empty q && string_empty !send_part then (
	    log (fun () -> sprintf "rmv_sock_xmit") ;
	    send_state := None ;
	    Alarm.rmv_sock_xmit alarm sock
	  )
    )
  in

  let send iovl =
    let iovl = Iovecl.take debug iovl in
    if not !connected then (
      Iovecl.free debug iovl
    ) else (
      let len = Iovecl.len debug iovl in
      Buf.write_net_len scribble len0 len ;
      let hdr = Mbuf.alloc debug mbuf scribble len0 len4 in
      let iovl = Iovecl.prependi debug hdr iovl in
      match !send_state with
      |	Some(_,q) ->
	  Queuee.add (ref iovl) q
      |	None -> 
	  let ret =
	    if Hsys.poll select_info > 0 then
	      Iovecl.sendv send_info iovl
	    else
	      0
	  in
	  if ret = int_of_len (len +|| len4) then (
	    Iovecl.free debug iovl
	  ) else (
	    log (fun () -> sprintf "add_sock_xmit") ;
	    let (iovl,part) = send_split iovl ret in
	    let q = Queuee.create () in
	    Queuee.add (ref iovl) q ;
	    send_state := Some(ref part,q) ;
	    Alarm.add_sock_xmit alarm debug sock writer
	  )
(*
	  log (fun () -> sprintf "add_sock_xmit") ;
	  let q = Queuee.create () in
	  Queuee.add (ref iovl) q ;
	  send_state := Some(ref empty,q) ;
	  Alarm.add_sock_xmit alarm debug sock writer
*)
    )
  in
  Alarm.add_sock_recv alarm debug sock (Hsys.Handler0 recv) ;
  send

(**************************************************************)

let server debug alarm port client =
  let sock = Hsys.socket_stream () in
  Hsys.setsockopt sock Hsys.Reuse ;

  if not !quiet then
    eprintf "%s:server binding to port %d\n" debug port ;
  begin
    try Hsys.bind sock (Hsys.inet_any()) port with e ->
      (* Don't bother closing the socket.
       *)
      if not !quiet then (
	eprintf "%s:error when binding to port\n" debug ;
	eprintf "  (this probably means that a groupd server is already running)\n" ;
      ) ;
      Hsys.close sock ;
      raise e
  end ;
  Hsys.listen sock 5 ;
  if not !quiet then
    eprintf "%s:server installed\n" debug ;

  let svr_handler () =
    let sock,inet,port = Hsys.accept sock in
    let info = sprintf "{inet=%s;port=%d}"
	(Hsys.string_of_inet_nums inet) port
    in
    let connected = ref true in

    let recv_r = ref (fun _ -> failwith sanity) in
    let recv iov = !recv_r iov in
    let disable_r = ref (fun _ -> failwith sanity) in
    let disable () = !disable_r () in

    let send = tcp debug alarm sock recv disable in

    let recv,disable,() = client info send in

    recv_r := recv ;
    disable_r := disable
  in
  
  let debug = sprintf "%s(server)" debug in
  Alarm.add_sock_recv alarm debug sock (Hsys.Handler0 svr_handler)

(**************************************************************)

let client debug alarm sock serv_init =
  let recv_r = ref (fun _ -> failwith sanity) in
  let recv iov = !recv_r iov in
  let disable_r = ref (fun _ -> failwith sanity) in
  let disable () = !disable_r () in

  let send = tcp debug alarm sock recv disable in
  let recv,disable,state = serv_init debug send in
  recv_r := recv ;
  disable_r := disable ;
  state

(**************************************************************)

let random_list l =
  let l = Array.of_list l in
  let n = Array.length l in
  for i = 1 to pred n do
    let j = Random.int i in 
    let tmp = l.(i) in
    l.(i) <- l.(j) ;
    l.(j) <- tmp
  done ;
  Array.to_list l

let connect debug port hosts balance repeat =
  if !verbose then
    eprintf "HSYSSUPP:connect:using port %d for %s server\n" port debug ;
  let try_connect host =
    let sock = Hsys.socket_stream () in
    if !verbose then
      eprintf "HSYSSUPP:connect:attempting connection to %s server at %s\n" debug (Hsys.string_of_inet host) ; 
    try
      Hsys.connect sock host port ;
      if !verbose then
        eprintf "HSYSSUPP:connect:connected to %s server\n" debug ;
      Some sock
    with e ->
      if !verbose then
        eprintf "HSYSSUPP:connect:connection to %s server failed (%s)\n" debug (Hsys.error e) ;
      Hsys.close sock ;
      None
  in

  let host = Hsys.gethost () in
  let localhost = Hsys.inet_of_string "localhost" in

  (* Randomize the list of hosts for load balancing.
   *)
  let hosts = 
    if balance then
      random_list hosts
    else 
      hosts
  in
  
  (* Strip out my host name from the list and then add it to
   * the front.
   *)
  let hosts = localhost :: (except host hosts) in
  let sock =
    let rec loop = function
    | [] -> None
    | hd::tl ->
        if_none (try_connect hd) (fun () -> loop tl)
    in loop hosts
  in

  (* Try locally some more, if requested to do so.
   *)
  let sock = 
    match sock with
    | None ->
	if repeat then (
	  eprintf "HSYSSUPP:connect:no %s server found, trying locally some more times\n" debug ;

	  let rec loop attempts =
	    if attempts <= 0 then None else (
	      (* Sleep for 1 second between tries.
	       *)
	      ignore (Time.select (Hsys.select_info None None None) (Time.of_int 1)) ;
	      match try_connect localhost with
	      | None -> loop (pred attempts)
	      | s -> s
	    )
	  in loop 20 (* Try 20 times. *)
	) else None
    | s -> s
  in
                  
  match sock with 
  | None ->
      let hosts = List.map (Hsys.string_of_inet) (host::hosts) in
      let hosts = string_of_list ident hosts in
      eprintf "HSYSSUPP:connect:no %s server found at %s, exiting\n" debug hosts ;
      exit 1
  | Some sock ->
      sock

(**************************************************************)

let _ =
  Elink.put Elink.hsyssupp_connect connect ;
  Elink.put Elink.hsyssupp_server server ;
  Elink.put Elink.hsyssupp_client client

(**************************************************************)
