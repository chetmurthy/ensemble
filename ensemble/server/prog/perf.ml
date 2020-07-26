(**************************************************************)
(* PERF.ML: round-trip performance demo *)
(* Author: Mark Hayden, 8/95 *)
(**************************************************************)
open Ensemble
open Util
open Appl
open View
open Appl_intf open New
open Trans
open Buf
(**************************************************************)
let name = Trace.file "PERF"
let failwith s = Trace.make_failwith name s
let log = Trace.log name
let log_iov = Trace.log (name^":IOV")
(**************************************************************)
external (=|) : int -> int -> bool = "%eq"
external (<>|) : int -> int -> bool = "%noteq"
external (>=|) : int -> int -> bool = "%geint"
external (<=|) : int -> int -> bool = "%leint"
external (>|) : int -> int -> bool = "%gtint"
external (<|) : int -> int -> bool = "%ltint"
(**************************************************************)
(* Should we add an md5 hash to messages? 
*)
let md5 = ref false 
(**************************************************************)

let digest iovl =
  let md5 = Hsys.md5_init () in
  Hsys.md5_update_iovl md5 iovl ;
  Hsys.md5_final md5

let gen_msg len  = 
  printf "generating message\n";
  (*eprintf "RAND:len=%d\n" len ;*)
  let send_pool = Iovec.get_send_pool () in
  let iov = Iovec.alloc send_pool len in
  let iov = Iovecl.of_iovec iov in
  let d = digest iov in
  let d = Iovec.of_buf send_pool (Buf.of_string d) len0 md5len in
  let iovl = Iovecl.prependi d iov in
  iovl

let check iovl =
  let len = Iovecl.len iovl in
  assert (len >= md5len) ;
  let d_iovl = Iovecl.sub iovl len0 md5len in
  let d_iov = Iovecl.flatten d_iovl in
  let d = Iovec.buf_of d_iov in
  Iovec.free d_iov ;
  Iovecl.free d_iovl ;
  let iovl = Iovecl.sub iovl md5len (len -|| md5len) in
  let d' = Buf.of_string (digest iovl) in
  Iovecl.free iovl ;
  if d <> d' then 
    failwith "bad message"

(**************************************************************)

let nmembers = ref 2
let often = ref 100

let meter name often max callb =
  let roll = Queue.create () in
  for i = 0 to 10 do
    Queue.add None roll
  done ;
  let cntr = ref 0 in
  let time = ref 0.0 in
  let init = Time.gettimeofday () in
  let init = Time.to_float init in
  let min_len  = ref 10000 in
  let f () = 
    if (!cntr mod often) =| 0 then (
      let now = Time.gettimeofday () in
      let now = Time.to_float now in
      let roll_rate =
	match Queue.take roll with
	|  None -> 0.0
	|  Some(roll_cntr,roll_time) ->
	    (now -. roll_time) /. (float (!cntr - roll_cntr))
      in
      Queue.add (Some(!cntr,now)) roll ;

      let rate = 
      	if !cntr = 0 then 0.0 else
	  ((now -. !time) /. (float often))
      in
      let s = callb () in 
      
      let p = (*if Arge.get Arge.perturb then "perturb" else*) "" in
      printf "PERF:%s #=%06d rate=%8.6f roll=%8.6f ctime=%8.6f %s %s\n" 
        name !cntr rate roll_rate (now -. init) s p;
      time := now ;
      match max with 
      |	None -> ()
      |	Some max ->
	  if !cntr >= max then (
	    Timestamp.print () ;
	    exit 0
	  )
    ) ;
    incr cntr

  and final () = 
    let now = Time.gettimeofday () in
    let now = Time.to_float now in
    eprintf "PERF:%s msgs per seconds = %f\n" name (float !cntr /. (now -. init))
  in
  
  f,final

(**************************************************************)

let timestamp () =
  let n = 10000 in
  let s = Time.gettimeofday () in
  let s_recv = Timestamp.register "UDP:recv" in
  let add_recv () = Timestamp.add s_recv in
  let s_xmit = Timestamp.register "UDP:xmit" in
  let add_xmit () = Timestamp.add s_xmit in
  for i = 1 to n do
    add_recv () ;
    add_xmit ()
  done ;
  Timestamp.print () ;
(*
  let e = Time.gettimeofday () in
  let t = Time.sub e s in
  eprintf "PERF:time to take %d samples: %s\n" n (Time.to_string t) ;
*)
  exit 0

(**************************************************************)

type iov_action = (Iovecl.t,Iovecl.t) action

type test = {
  start : iov_action array ;
  hbt : Time.t -> bool*(bool array) -> iov_action array ;
  cast : origin -> Iovecl.t -> iov_action array ;
  send : origin -> Iovecl.t -> iov_action array
}  

type testrun = View.full -> test option

let fast_iov len =(* Hack! *)
  if !md5 then 
    gen_msg len
  else
    let send_pool = Iovec.get_send_pool () in
    let msg = Iovec.alloc send_pool len in
    Iovecl.of_iovec msg

(**************************************************************)
(**************************************************************)

let error_handler _ = failwith sanity

(**************************************************************)
(**************************************************************)

let gc_info () =
  List.iter (fun s ->
    eprintf "PERF:GC:%s\n" s ;
  ) (string_list_of_gc_stat (Gc.stat ()))

let rt size nrounds (ls,vs) =
  let async = Appl.async (vs.group,ls.endpt) in
  Gc.full_major () ; gc_info () ;
  let start_t = Time.to_float (Time.gettimeofday ()) in
  let round= ref 0 in

  let partner =
    match ls.rank with
    | 0 -> 1
    | 1 -> 0
    | _ -> -1
  in

  let msgi = fast_iov size in
  let msg = [|Cast msgi|] in
  
  let print_result () =
    let end_t = Time.to_float (Time.gettimeofday ()) in
    let time = end_t -. start_t in
    Timestamp.print () ;
    printf "real-time: %.6f\n"time ;
    printf "latency/round: %.6f\n"      (time /. (float nrounds)) ;
    printf "msgs/sec: %.3f\n"((float nrounds) /. time)
  in

  let cast origin =
    match ls.rank,origin with
    | 0,1 | 1,0 -> (fun _ ->
(*	eprintf "msg %d\n" !round ;*)
      	incr round ;
      	if !round >=| nrounds then (
	  async () ;
	  if ls.rank =| 1 then ( 
	    ignore (Iovecl.copy msgi) ;
	    msg
	  ) else [||]
	) else (
	  ignore (Iovecl.copy msgi) ;
	  msg
	)
      )
    | _ -> null
  and send _ = error_handler
  and hbt _ _ =
    if !round >= nrounds then (
      gc_info () ;
      print_result () ;
      exit 0
    ) else [||]
  and start = 
    if ls.rank =| 0 then (
      ignore (Iovecl.copy msgi) ;
      msg 
    ) else [||]
  in 

  Some{
    start = start ;
    cast = cast ;
    send = send ;
    hbt = hbt
  } 

(**************************************************************)
(**************************************************************)

let latency size nrounds (ls,vs) =
  let start_t = Time.to_float (Time.gettimeofday ()) in
  let round = ref 0 in

  let src = (pred ls.rank + ls.nmembers) mod ls.nmembers in
  let msg = fast_iov size in
  let msg_ref () = ignore (Iovecl.copy msg) in
  let msg = [|Cast msg|] in
  
  let print_result () =
    let end_t = Time.to_float (Time.gettimeofday ()) in
    let time = end_t -. start_t in
    Timestamp.print () ;
    printf "real-time: %.6f\n"time ;
    printf "latency/round: %.6f\n" (time /. (float nrounds))
  in

  let cast origin _ =
    if Random.int 100 = 0 then
      log_iov (fun () ->
	let num,lens = Iovec.debug () in
	sprintf "refcounts = %d,%d\n   GC=%s" num lens 
	  (Util.string_of_list ident
	    (Util.string_list_of_gc_stat (Gc.stat ())))
      );
    incr round ;
    if origin =| src then (
      if !round >=| nrounds then (
        print_result () ;
	msg_ref () ;
        Array.append msg [|Control Leave|]
      ) else (
	msg_ref () ; 
	msg
      )
    ) else [||]
  and send _ = error_handler
  and hbt _ _ = [||]
  and start = 
    if ls.am_coord then (
      msg_ref () ;
      msg 
    ) else [||]
  in 

  Some{
    start = start ;
    cast = cast ;
    send = send ;
    hbt = hbt
  } 

(**************************************************************)
(**************************************************************)

let zero = 0.0
let sleep = ref 0.0

let ring nmsgs size nrounds (ls,vs) =
  let start_t = Time.to_float (Time.gettimeofday ()) in
  let end_t = ref zero in
  let rnd = ref 0 in
  let got = ref 0 in
  let got_end = ref false in
  let gc = Gc.stat () in
  let to_send = ref 0 in

  let msg = fast_iov size in
  let msgs = Array.create 1 (Cast msg) in
  let msg_ref () =
    for i = 1 to nmsgs do
      ignore (Iovecl.copy msg)
    done
  in
  msg_ref () ;
  let msgs_per_rnd = (pred ls.nmembers) * nmsgs in

  if not !quiet then
    printf "RING:got view, nmembers=%d, rank=%d\n" ls.nmembers ls.rank ;
  if not !quiet then
    printf "RING:starting\n" ; 
    (*Profile.start () ;*)

  let print_result () =
    end_t := Time.to_float (Time.gettimeofday ()) ;
    let gc' = Gc.stat () in
    let time = !end_t -. start_t in
    let total_msgs = nrounds * nmsgs * ls.nmembers in
    (*Profile.end () ;*)
    (*Timestamp.print () ;*)

    let latency = time /. (float nrounds) in
    let msgs_sec = (float total_msgs) /. time in
    let msgs_mbr_sec = (float total_msgs) /. time /. (float ls.nmembers) in
    if not !quiet then (
      Timestamp.print () ;
      printf "latency/round: %.6f\n"    latency ;
      printf "msgs/sec: %.3f\n"msgs_sec ;
      printf "msgs/mbr/sec: %.3f\n"     msgs_mbr_sec ;
      printf "real-time: %.6f\n"time
(*
  printf "#gcs: %d\n"(gc'.minor_collections - gc.minor_collections) ;
  printf "minorwords: %d\n"(gc'.minor_words - gc.minor_words) ;
*)
    ) else (
      printf "OUTPUT:n=%d, rank=%d, protocol=%s, latency=%.6f\n"
      ls.nmembers ls.rank (Proto.string_of_id vs.proto_id) latency
    )
  in

  let cast origin =
    if origin <>| ls.rank then (fun _ ->
      incr got ;
      if !got =| msgs_per_rnd then (
	got := 0 ;
	incr rnd ;
	if !rnd >= nrounds then (
	  print_result ();
	  if !sleep = zero then
	    [|Control Leave|]
	  else (
	    (*        printf "\nRING: going to idle for %f sec...\n" !sleep;*)
	    got_end := true ;
	    [||]
	  )
	) else ( to_send := nmsgs; [||])
      ) else [||]
    ) else null
  and send _ = null
  and hbt _ _ =
   if !to_send > 0 then (
      decr to_send; 
      let msg = ignore (Iovecl.copy msg) in
      msgs
    ) else (

     if !quiet then
       printf "RING:heartbeat (%d/%d of %d)\n" !got msgs_per_rnd !rnd ;
     if !got_end then (
       let now = Time.to_float (Time.gettimeofday ()) in
         
       let dif = now -. !end_t in
         (* printf "RING heartbeat: %f elapsed since end\n" dif ;*)
         if dif > !sleep then
           [|Control Leave|]
         else (
           (*        printf "RING: %f elapsed since end\n" dif ;*)
 	         [||]
         )
     )
     else [||]
   )
  and start = msg_ref () ; msgs 
  in Some{
    start = start ;
    cast = cast ;
    send = send ;
    hbt = hbt
  } 

(**************************************************************)
(**************************************************************)

let chain nrounds size nchains (ls,vs) =
  let round = ref 0 in
  let start_t = Time.to_float (Time.gettimeofday ()) in
  let end_t= ref zero in

  let chain = Array.create nrounds 0 in
  (* Initialize the chain.
   *)
  for i = 0 to pred nrounds do
    chain.(i) <- i mod ls.nmembers
  done ;
 
  (* Scramble the entries.
   *)
  Random.init 1023 ;
  for i = 1 to pred nrounds do
    let j = Random.int i in
    let tmp = chain.(i) in
    chain.(i) <- chain.(j) ;
    chain.(j) <- tmp
  done ;
  printf "CHAIN:%s\n" (string_of_int_array chain) ;

  let msg = [|Cast (fast_iov size)|] in

  let print_result () =
    end_t := Time.to_float (Time.gettimeofday ()) ;
    let time = !end_t -. start_t in
    let latency = time /. (float nrounds) in
    Timestamp.print () ;
    if not !quiet then (
      printf "real-time: %.6f\n"time ;
      printf "latency/round: %.6f\n"    latency
    ) else (
      printf "OUTPUT:n=%d, rank=%d, c=%d, protocol=%s, latency=%.6f\n"
      ls.nmembers ls.rank nchains (Proto.string_of_id vs.proto_id) latency
    )
  in

  if not !quiet then
    printf "CHAIN:got view, nmembers=%d, rank=%d\n" ls.nmembers ls.rank ;

  if not !quiet then
    printf "CHAIN:starting\n" ; 
  let start_t = Time.to_float (Time.gettimeofday ()) in

  let cast origin = fun _ ->
    incr round ;
    printf "round=%d, %d\n" !round (Array.length chain) ;
    if !round = nrounds then (
      print_result () ;
      [|Control Leave|]
    ) else if chain.(pred !round) = ls.rank then (
      msg
    ) else (
      [||]
    )
  and send _ = null
  and hbt _ _ = 
    if not !quiet then
      printf "CHAIN:heartbeat:round:%d/%d\n" !round nrounds ;
    [||]
  and start = 
    let msgl = Array.to_list msg in
    let m = Array.create (nchains / ls.nmembers) msgl in
    let m = Array.to_list m in
    let m = List.flatten m in
    let m = Array.of_list m in
    if ls.rank < nchains then
      Array.append msg m
    else
      m
  in Some{
    start = start ;
    cast = cast ;
    send = send ;
    hbt = hbt
} 

(**************************************************************)
(**************************************************************)

let one_to_n size rate terminate_time (ls,vs) =
  let iov = 
    fast_iov size
  in
  let msg = Cast iov in
  let next = ref (Time.gettimeofday ()) in
	let stop = Time.add !next terminate_time in
  let ctr,final = meter "1-n" !often None (fun () -> if ls.rank=0 then "coord" else "") in
	let fcount = ref 0 in
  let start =
    if ls.am_coord then (
      ignore (Iovecl.copy iov) ;
      [|msg|]
    ) else [||]
  and cast _ iovl = 
    ctr () ;
    [||]
  and send _ = null
  and hbt time fub =
    if Time.ge time stop then (
      eprintf "time up\n";
      final ();
      [|Control Leave|]
    ) else
      if ls.am_coord then 
	if (fst fub) = false then (
	  incr fcount;
	  if !fcount mod 100 = 0 then 
	    log (fun () -> sprintf "FlowBlocked %d" !fcount) ;
	  next := Time.add !next rate;
	  [||]
	) else (
      	  let msgs = ref [] in
      	  while time >= !next do
    	    ctr () ;
	    ignore (Iovecl.copy iov) ;
	    msgs := msg :: !msgs ;
	    next := Time.add !next rate ;
      	  done ;
      	  Array.of_list !msgs
        ) else [||]
  in Some{
    start = start ;
    cast = cast ;
    send = send ;
    hbt = hbt
  }


(**************************************************************)
(**************************************************************)

let m_to_n size rate sender terminate_time (ls,vs) =
  let iov = fast_iov size in
  let msg = Cast iov in
  let next = ref (Time.gettimeofday ()) in
  
  let stop = Time.add !next terminate_time in
  
  let name = (sprintf "m-n  %s" ls.name) in 
   
  let callback = fun () -> sprintf "sent=%d recvd=%d %s" 
      (Appl.cast_info.Appl.acct_sent)
      (Appl.cast_info.Appl.acct_retrans + Appl.cast_info.Appl.acct_bad_ret) 
      (if sender then "sender" else "")
  in 
  let ctr,_ = meter name 100 None callback in
  let start =
    if sender then (
      ignore (Iovecl.copy iov) ;
      [|msg|]
    ) else [||]
  and cast origin _ = 
    ctr () ; 
    [||]
  and send _ = null
  and hbt time _ =
    if time > stop then (
      if !verbose then eprintf "time up";
      [|Control Leave|]
    ) else if sender then (
      let msgs = ref [] in
      while time >= !next do
	ctr () ;
	ignore (Iovecl.copy iov) ;
	msgs := msg :: !msgs ;
	next := Time.add !next rate ;
      done ;
      Array.of_list !msgs
    ) else [||]
  in Some{
    start = start ;
    cast = cast ;
    send = send ;
    hbt = hbt
  } 

(**************************************************************)
(**************************************************************)

let rpc size rounds (ls,vs) =
  let msg = fast_iov size in
  let msg_ref () = ignore (Iovecl.copy msg) in
  let request = [|Cast(msg)|] in
  let reply = [|Send1(0,msg)|] in
  let count = ref 0 in
  let roundcount = ref 0 in
  let ctr,_ = meter "rpc" (*10000*)1000 (*(Some rounds)*)None (fun () -> if ls.rank=0 then "coord" else "") in
  let start =
    if ls.rank = 0 then (
      count := pred ls.nmembers ;
      msg_ref () ;
      request 
    ) else [||]
  and cast origin =
    if ls.rank <> 0 then (
      fun _ -> 
    	ctr () ;
	incr roundcount;
	if !roundcount >= rounds then (
	    Timestamp.print () ;
	    Array.append reply [|Control Leave|]
	)
	else ( 
	  msg_ref () ;
	  reply 
        )
    ) else null
  and send origin =
    if ls.rank = 0 then (
      fun _ ->
	decr count ;
	if !count =| 0 then (
	  ctr () ;
  	  incr roundcount;
	  if !roundcount >= rounds then (
            Timestamp.print ();
            [| Control Leave |]
          )
          else (
	    count := pred ls.nmembers ;
	    msg_ref () ;
	    request
          )
	) else [||]
    ) else null
  and hbt _ _ = [||]
  in Some{
    start = start ;
    cast = cast ;
    send = send ;
    hbt = hbt
  } 


(**************************************************************)
(**************************************************************)

let switch () =
  let count = ref 0 in
  let start = ref (-1.0) in
  fun (ls,vs) ->
    if !start = (-1.0) then
      start := Time.to_float (Time.gettimeofday ()) ;
    incr count ;
    if ls.rank = 0 && (!count mod 100) = 0 then (
      let now = Time.to_float (Time.gettimeofday ()) in
      printf "PERF:switch: %5d views %6.3f sec/view\n" 
        !count ((now -. !start) /. float !count) ;
    ) ;
    
    let start = 
      if ls.rank = 0 then (
      (*eprintf "PERF:switching\n" ;*)
	[|Control (Protocol vs.proto_id)|]
      ) else
	[||]
    and cast _ = error_handler
    and send _ = error_handler
    and hbt _ _ = [||]
    in Some{
      start = start ;
      cast = cast ;
      send = send ;
      hbt = hbt
  } 

(**************************************************************)
(**************************************************************)

let pt2ptfc size rate terminate_time (ls,vs) = 
  let var_test = true in
  let iov = fast_iov size in
  let msg = Send1 (0,iov) in
  let chunk = 4 in   (* sec, when variable test *)
  let start_t = Time.gettimeofday () in
  let stop_t  = Time.add start_t 
    (if var_test then Time.of_int ((!nmembers - 1) * chunk) else terminate_time) in
  let stop_t = if ls.rank = 0 then stop_t else Time.add stop_t (Time.of_int 6) in
  let next = ref start_t in
  let var_start_t = Time.add start_t (Time.of_int ((ls.rank - 1) * chunk)) in
  let var_stop_t  = Time.add var_start_t (Time.of_int chunk) in
(*  let name = (sprintf "pt2ptfc  %s" ls.name) in *)
(*  let callback = fun () -> (if ls.rank = 0 then "receiver" else "") in *)
(*  let ctr,final = meter name !often None callback in *)
  let messages = Array.create ls.nmembers 0 in
  let sending = ref false in
  let start = [||]
  and cast _ = null
  and send origin _ = 
    (* ctr () ;*) 
    messages.(origin) <- succ messages.(origin) ;
    [||]
  and hbt time fub =
    if Time.ge time stop_t then (
      printf "time up\n" ;
      (* final () ;*)
      if ls.rank = 0 then (
	let dt = Time.to_float (Time.sub stop_t start_t) in
	for i = 1 to pred ls.nmembers do
	  let bytes = messages.(i) * (int_of_len size) in
	  printf "from %d : %d msgs, bandwidth %.3f B/s, throughput %.3f msgs/s\n" 
	    i  messages.(i) (float_of_int bytes /. dt) (float_of_int messages.(i) /. dt)
	done ;
	let sum = ref 0 in
	Array.iter (fun v -> sum := !sum + v) messages ;
	let bytes = !sum * (int_of_len size) in
	printf "total  : %d msgs, bandwidth %.3f B/s, throughput %.3f msgs/s\n"
	  !sum (float_of_int bytes /. dt) (float_of_int !sum /. dt);
	printf "real-time: %.6f sec\n" dt
      ) ;
      [|Control Leave|]
    ) else 
      if ls.rank > 0 then (
        let msgs = ref [] in
        while Time.ge time !next do
	  if var_test && not !sending && 
	    Time.ge !next var_start_t &&  Time.ge var_stop_t !next then (
	    eprintf "%d starts sending\n" ls.rank ;
	    sending := true 
	  ) ;
    	  (* ctr () ;*)
	  if (snd fub).(0) && (not var_test || !sending) then (
	    ignore (Iovecl.copy iov) ;
	    msgs := msg :: !msgs 
	  ) ;
	  next := Time.add !next rate ;
	  if var_test && !sending && Time.ge !next var_stop_t then (
	    eprintf "%d finishes sending\n" ls.rank ;
	    sending := false
	  ) ;
	done ;
	Array.of_list !msgs
      ) else [||]
  in Some{
      start = start ;
      cast = cast ;
      send = send ;
      hbt = hbt
    } 
	 
(**************************************************************)
(**************************************************************)

let wait nmembers f =
  let correct_number = ref false in
  fun (ls,vs) ->
    if ls.nmembers = nmembers then (
      correct_number := true ;
      if !verbose then
      	printf "PERF:wait:got all members:cur=%d\n" ls.nmembers ;
      f (ls,vs)
    ) else if !correct_number then (
      if !verbose then 
	eprintf "PERF:wait:new view formed before my timer expired\n" ;
      exit 0
    ) else (
      if !verbose then
	eprintf "PERF:wait:wrong # members:cur=%d:goal=%d\n"
	  ls.nmembers nmembers ;
      None
    ) 

let once f =
  let ran = ref false in
  fun vs ->
    if !ran then (
      Timestamp.print () ;
      exit 0
    ) ;
    let i = f vs in
    if i <> None then
      ran := true ;
    i

(**************************************************************)

let nulli () = ([||],{
  flow_block = (fun _ -> ());
  receive = (fun _ _ _ _ -> [||]) ;
  heartbeat = (fun _ -> [||]) ;
  block = (fun _ -> [||]) ;
  disable = Util.ident
})

let interface rate test =
  let log = Trace.log name in
  let install (ls,vs) =
    let flow_unblocked = ref true in
    let flow_unblocked_arr = Array.create ls.nmembers true in
    let unblocked = ref true in
    let count = ref 0 in
    eprintf "PERF:view:%s:nmembers=%d\n" ls.name ls.nmembers ;
(*
    printf "PERF:view change:nmembers=%d, rank=%d\n" ls.nmembers ls.rank ;
    printf "PERF:view=%s\n" (Endpt.string_of_id_list vs.view) ;
    printf "PERF:view_id=%s\n" (View.string_of_id vs.view_id) ;
*)
    match test (ls,vs) with
    | None -> nulli ()
    | Some(cb) ->
	let actions = cb.start
	and flow_block (ro,b) = match ro with 
	    | Some(r) -> 
		flow_unblocked_arr.(r) <- not b ;
		log (fun () -> sprintf "flow_unblocked=%b to %d" (not b) r) ;
		()
	    | None -> flow_unblocked := not b; 
		log (fun () -> sprintf "flow_unblocked=%b" !flow_unblocked) ;
		()
	and receive origin block cs msg =
	  if !md5 then check msg;
	  Iovecl.free msg;
	  match block,cs with
	  | U,C -> cb.cast origin msg
	  | U,S -> cb.send origin msg
	  | _ -> null msg
	and heartbeat time =
	  if !unblocked then
	    cb.hbt time (!flow_unblocked,flow_unblocked_arr)
	  else
	    [||]
	and block () = 
	  unblocked := false ;
	  [||] 
	and disable = Util.ident 
	in
	actions,{flow_block=flow_block;
		 receive=receive;block=block;heartbeat=heartbeat;disable=disable}
  in
  
  let exit () = exit 0 in

  { install = install ;
    heartbeat_rate = rate ;
    exit = exit }

(**************************************************************)
(*
let empty =
  let recv_cast _ () = [||]
  and recv_send _ () = [||]
  and block () = [||]
  and heartbeat _ = [||]
  and block_recv_cast _ _ = ()
  and block_recv_send _ _ = ()
  and block_view (ls,vs) = [ls.rank,()]
  and block_install_view _ _ = ()
  and unblock_view _ () = [||]
  and exit () = ()
  in full {
    recv_cast           = recv_cast ;
    recv_send           = recv_send ;
    heartbeat           = heartbeat ;
    heartbeat_rate      = Time.of_float 100.0 ;(* a big number *)
    block               = block ;
    block_recv_cast     = block_recv_cast ;
    block_recv_send     = block_recv_send ;
    block_view          = block_view ;
    block_install_view  = block_install_view ;
    unblock_view        = unblock_view ;
    exit                = exit
} 
*)
(**************************************************************)
(*
let groupd wait group endpt counter send =
  let log = Trace.log "GROUPD" "" in
  let recv msg = match msg with
  | Mutil.View(_,_,view) ->
      log (fun () -> "View()") ;
      let n = List.length view in
      if (not wait) 
      || n = !nmembers then (
      	counter n ;
      	if List.hd view = endpt then
	    send (Mutil.Fail[])
      )
  | Mutil.Sync ->
      log (fun () -> "Sync") ;
      send Mutil.Synced
  | Mutil.Failed _ ->
      ()
  in
  recv
*)
(**************************************************************)
(**************************************************************)

let use_locator file am_server =
  if am_server then (
    let host = Hsys.gethostname () in
    (* Had problems opening for append mode.
     *)
    ignore (Sys.command (sprintf "echo %s >>%s" host file))
(*
	let co = open_out_gen [Open_append;Open_text;Open_creat] 0o666 file in
        output_string co (sprintf "%s\n" host) ;
	close_out co
*)
  ) ;
  
  (* Sleep for 5 seconds for everyone who wants to 
   * to write their names in the file.
   *)
  Unix.sleep 5 ;

  (* Now read from the file.
   *)
  let hosts =
    let l = ref [] in
    let ci = open_in file in
    begin try while true do
      let host = input_line ci in
      l := host :: !l
    done with End_of_file -> () end ;
    close_in ci ;
    Some !l
  in
(*
  eprintf "PERF:locator hosts=%s\n" hosts ;
*)

  (* Override the environment with these host
   * lists.
   *)
  Arge.set Arge.groupd_hosts hosts ;
  Arge.set Arge.gossip_hosts hosts ;

  let alarm = Appl.alarm name in

  (* If I'm a server then also initialize the 
   * server stacks.
   *)
  if am_server then (
    let vf = Appl.default_info "locator:gossip" in
    let port = Arge.check name Arge.gossip_port in
    let vf, interface = Reflect.init alarm vf port true in
    Appl.config_new interface vf ;

    let vf = Appl.default_info "locator:groupd" in
    let port = Arge.check name Arge.groupd_port in
    let vf, intf = Manage.create_proxy_server alarm port vf in
    Appl.config_new intf vf ;
  ) ;

  (* Sleep for 5 seconds for everyone who wants to 
   * to write their names in the file.
   *)
  Unix.sleep 5

(**************************************************************)
(**************************************************************)

let size        = ref 0
let nrounds     = ref 100
let msgs_per_round = ref 1
let nchains     = ref 1
let prog        = ref ""
let nlocal      = ref 1
let mlocal      = ref false
let sender      = ref false
let rate_r      = ref (Time.of_float 0.01)
let heartbeat_rate = ref (Time.of_float 10.0)
let wait_r      = ref true
let ngroups     = ref 1
let once_r      = ref false
let stoptime    = ref (Time.of_float 0.00)
let locator     = ref None
let locator_server = ref false
let proto_id    = ref None
let terminate_time = ref (Time.of_float 20.0)

let run () =
  let undoc = "undocumented" in
  Arge.parse [
    "-n",Arg.Int(fun i -> nmembers := i), ": # of members" ;
    "-s",Arg.Int(fun i -> size := i), ": size of messages" ;
    "-r",Arg.Int(fun i -> nrounds := i), ": # of rounds" ;
    "-c",Arg.Int(fun i -> nchains := i),undoc ;
    "-k", Arg.Int(fun i -> msgs_per_round := i),undoc ;
    "-often", Arg.Int(fun i -> often := i), undoc ;
    "-local",   Arg.Int(fun i -> nlocal := i), ": # of local members" ;
    "-rate",    Arg.Float(fun i -> rate_r := Time.of_float i),undoc ;
    "-stoptime",    Arg.Float(fun i -> stoptime := Time.of_float i),undoc ;
    "-sleep",Arg.Float(fun i -> sleep := i),undoc ;
    "-nowait",  Arg.Clear(wait_r),undoc ;
    "-ngroups", Arg.Int(fun i-> ngroups :=i),"";
    "-prog",    Arg.String(fun s -> prog := s), undoc ;
    "-sender",  Arg.Set sender, " : set this process as a sender";
    "-mlocal",  Arg.Set mlocal, " : use local manager" ;
    "-once",    Arg.Set once_r, " : only run test once" ;
    "-locator", Arg.String(fun s -> locator := Some s), " : use locator (for SP2)" ;
    "-locator_server", Arg.Set locator_server, " : act as locator server (for SP2)" ;
    "-protocol",Arg.String(fun s -> proto_id := Some s), " : set protocol" ;
    "-md5", Arg.Set(md5), "Add an MD5 hash to messages"; 
    "-terminate_time", Arg.Float(fun f -> terminate_time := Time.of_float f), undoc  ] 
    (Arge.badarg name) "perf: Ensemble performance testing" ;

  if not !quiet then
    printf "nmembers=%d size=%d round=%d rate=%s\n"
      !nmembers !size !nrounds (Time.to_string !rate_r) ;

  let alarm = Appl.alarm name in
  
  let sleep t f =
    let now = Alarm.gettime alarm in
    Alarm.schedule (Alarm.alarm alarm f) (Time.add now t)
  in

  (* Check if we are using the file system to meet up.
   *)
  begin match !locator with
  | Some file -> use_locator file !locator_server
  | None -> ()
  end ;


  (* This allows killing this process by closing stdin.
   *)
  let stdin = Hsys.stdin () in
  let buf = String.create 100 in
  let get_input () =
    let len = Hsys.read stdin buf 0 (String.length buf) in 
    if len=0 then (
      printf "Killing process\n";
      exit 0
    )
  in
  Alarm.add_sock_recv alarm name stdin (Hsys.Handler0 get_input) ;

  let ready () =
    for i = 1 to !nlocal do
      let (ls,vs) =
 	Appl.default_info "perf" 
      in
      let vs =
	match !proto_id with
	| None -> vs
	| Some proto -> View.set vs [Vs_proto_id (Proto.id_of_string proto)] 
      in

      let size = len_of_int !size in
      let prog = match !prog with
      |	"timestamp" -> timestamp ()
      | "ring"  -> ring !msgs_per_round size !nrounds
      | "rt"    -> rt size !nrounds
      | "chain" -> chain !nrounds size !nchains
      | "latency" -> latency size !nrounds
      | "rpc"   -> 
	  once_r := true ;
	  rpc size !nrounds 
      | "switch" -> 
	  switch ()
      | "1-n" -> 
	  heartbeat_rate := !rate_r ;
	  one_to_n size !rate_r !terminate_time
      | "m-n"   -> 
	  heartbeat_rate := !rate_r ;
	  m_to_n size !rate_r !sender !terminate_time
(*
      | "empty" ->
	  let start_t = Hsys.gettimeofday () in
	  for i = 1 to !nrounds do
	    let (ls,vs) = Appl.default_info "perf" in
	    Appl.config empty (ls,vs) ;
	  done ;
	  let end_t = Hsys.gettimeofday () in
	  eprintf "PERF:empty: #views=%5d %8.5f sec/view\n" 
	    !nrounds ((end_t -. start_t) /. float !nrounds) ;
	  exit 0
*)
(*
      | "groupd" ->
	  let m = 
	    if !mlocal then (
	      let m, vs, intf = Manage.create (ls,vs) in
	      Appl.config intf vs ;
	      m
	    ) else (
	      Appl.init_groupd ()
	    )
	  in
	  for i = 1 to !nlocal do
  (*
    let gbl_counter = rate "Groupd" 50 None (fun () -> "") in
   *)
	    for g = 1 to !ngroups do
	      let name = sprintf "Perf%03d" g in
	      let group = Group.named name in
	      let group = Group.string_of_id group in
	      let nmem = ref 0 in
	      let counter,_ = meter name (if g = 1 then 25 else 400) None 
		(fun() -> if perturb then "perturb" else "") 
                (fun () -> sprintf "nmembers=%d" !nmem)
	      in
	      let counter n =
		nmem := n ;
		counter ()
	      in

	      let endpt = Endpt.id () in
	      let endpt = Endpt.string_of_id endpt in

	      let send_r = ref (fun _ -> failwith sanity) in
	      let send msg = !send_r msg in
	      
	      let groupd = groupd !wait_r group endpt counter in
	      let groupd = Mutil.wrap groupd in
	      let recv = groupd send in
	      send_r := Manage.join m group endpt 0 recv
	    done
	  done ;
	  Appl.main_loop () ;
	  exit 1
*)
	| "pt2ptfc"  -> 
	    heartbeat_rate := !rate_r ;
	    pt2ptfc size !rate_r !terminate_time

	|  _ -> failwith "unknown performance test"
      in

      let prog =
	if !wait_r then
	  wait !nmembers prog
	else prog
      in

      let prog =
	if !once_r then
	  once prog
	else prog
      in

(*
      if Arge.get Arge.perturb false then (
	let perturb alarm doze rate =
	  let next = ref (Alarm.gettime alarm) in
	  let nosocks = Hsys.select_info None None None in

	  let disabled = ref false in
	  let disable () =
	    disabled := true
	  in

	  let handler_r = ref (fun _ -> ()) in
	  let handler time = !handler_r time in
	  let schedule = Alarm.alarm alarm handler in
	  handler_r := (fun time ->
	    if !disabled then (
	      Alarm.disable schedule
	    ) else (
	      while !next <= Alarm.gettime alarm do
		next := Time.add !next doze ;
		if Random.float 1.0 < rate then (
		  ignore (Time.select nosocks doze)
		)
	      done ;

	      Alarm.schedule schedule !next 
	    )
	  ) ;

	  handler (Alarm.gettime alarm) ;
	  disable
	in

	let disable = 
	  perturb alarm
	    (Arge.get Arge.perturb_doze)
	    (Arge.get Arge.perturb_rate)
	in ()
      ) ;
*)
      let interface = interface !heartbeat_rate prog in
      Appl.config_new interface (ls,vs) ;
    done ;

    (* timeout code, as suggested by Mark.... *)
    let timeout = Time.add (Alarm.gettime alarm) (Time.of_float 123.0) in 
    let alarm = Alarm.alarm alarm (fun _ -> exit 0 ) in 
    if (Time.to_float !stoptime) <> 0.0 then
      Alarm.schedule alarm 
      (Time.add (Time.gettimeofday ()) !stoptime);
    (*  end of mark's suggestion *) 
  in

  ready () ;
  Appl.main_loop ()

let _ = 
  Appl.exec ["perf"] run

(**************************************************************)
