(**************************************************************)
(* HTK.ML *)
(* Author: Mark Hayden, 3/96 *)
(**************************************************************)
open Tk
open Util
open Trans
open Hsys
(**************************************************************)
let name = Trace.file "HTK"
let failwith s = Trace.make_failwith name s
let log = Trace.log name
(**************************************************************)

let exec_events sched =
  while Sched.step sched 100 do
    log (fun () -> sprintf "looping")
  done

let alarm ((unique,sched,async,handlers,mbuf) as gorp) =
  let gettime = Time.gettimeofday

  and alarm callback =
    let disable () = () in
    let schedule time =
      let timef	= Time.to_float time in
      let now 	= Time.gettimeofday () in
      let now   = Time.to_float now in
      let milli	= (timef -. now) *. 1000.0 in

      (* We sometimes get timers that are set to go off in
       * in the past!
       *)
      let milli 	= max 0 (truncate milli) in

      ignore (Timer.add milli (fun () ->
	Hsys.catch (fun () ->
	  log (fun () -> sprintf "timer awake{") ;

	  (* Tk sometimes delivers alarms early, according
	   * got gettimeofday and our calculations above.
	   *)
	  let now = max time (Time.gettimeofday ()) in

	  (* Make the callback and execute all events to
	   * completion.
	   *)
	  callback now ;
	  exec_events sched ;

	  log (fun () -> sprintf "timer asleep}") ;
        ) ()
      ))
    in Alarm.c_alarm disable schedule
  in

  let poll_f = ref None in
  let alm_poll b = 
    match !poll_f with
    | Some f -> f b
    | None -> b
  in

  let sockets = Resource.create "HTK:sockets"

    (* Add a callback for a socket.
     *)
    (fun _ (sock,hdlr) -> 
      let fd = Hsys.file_descr_of_socket sock in
      Fileevent.add_fileinput fd (fun () ->
	Hsys.catch (fun () ->
	  log (fun () -> sprintf "sock awake{") ;
	  begin
	    match hdlr with
	    | Hsys.Handler0 f -> f ()
	    | Hsys.Handler1 ->
		Mbuf.alloc_udp_recv name mbuf
		  handlers
		  sock
		  Route.deliver
		  ()
	  end ;
          ignore (alm_poll false) ;
	  exec_events sched ;
	  log (fun () -> sprintf "sock asleep}") ;
        ) ()
      )
    )

    (* Remove a socket's callback.
     *)
    (fun _ (sock,_) -> 
       let fd = Hsys.file_descr_of_socket sock in
       Fileevent.remove_fileinput fd)

    ignore
    ignore
  in

  let add_sock_recv d s h = Resource.add sockets d (Hsys.int_of_socket s) (s,h)
  and rmv_sock_recv s = Resource.remove sockets (Hsys.int_of_socket s)
  and add_sock_xmit _ = failwith "add_sock_xmit"
  and rmv_sock_xmit _ = failwith "rmv_sock_xmit"
  and add_poll n p = poll_f := Alarm.alm_add_poll n p
  and rmv_poll n = poll_f := Alarm.alm_rmv_poll n
  and min _ 	= failwith "min"
  and check _ 	= failwith "check"
  and block _ 	= failwith "block"
  and poll _	= failwith "poll"

  in Alarm.create
    name
    gettime
    alarm
    check
    min
    add_sock_recv
    rmv_sock_recv
    add_sock_xmit
    rmv_sock_xmit
    block
    add_poll
    rmv_poll
    poll
    gorp

(**************************************************************)

let init alarm =
  exec_events (Alarm.sched alarm)

(**************************************************************)

let _ =
  Elink.put Elink.htk_init init ;
  Elink.put Elink.htk_alarm alarm ;
  Elink.alarm_install "TK" (fun s -> Elink.get name Elink.htk_alarm s)

(**************************************************************)
