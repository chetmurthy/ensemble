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
(* MTALK.ML: multiperson talk program. *)
(* Author: Mark Hayden, 8/95 *)
(**************************************************************)
open Ensemble
open Trans
open Hsys
open Util
open View
open Appl_intf open Old
(**************************************************************)
let name = Trace.file "MTALK"
let failwith s = Trace.make_failwith name s
(**************************************************************)

(* This function returns the interface record that defines
 * the callbacks for the application.
 *)
let intf (ls,vs) my_name alarm =
  (* The current view state.
   *)
  let vs	= ref vs in
  let ls        = ref ls in

  (* This is the buffer used to store typed input prior
   * to sending it.
   *)
  let buffer 	= ref "" in
  let leave     = ref false in

  (* This is an array of string names for every
   * member in the group.
   *)
  let names 	= ref [|my_name|] in

  (* This is the last member to have sent data to be output.
   * When another member sends data, we print a prompt for
   * the new source and update this val.
   *)
  let last_id 	= ref (-1) in

  (* This is set below in the handler of the same name.  Get_input
   * calls the installed function to request an immediate callback.
   *)
  let async = Appl.async (!vs.group,!ls.endpt) in

  (* Install handler to get input from stdin.
   *)
  let stdin = stdin () in
  let get_input () =
    let buf = String.create 1000 in
    if !verbose then (
      printf "MTALK:about to read\n"
    ) ;
    let len = read stdin buf 0 (String.length buf) in
    if len = 0 then (
      (* Mark leave, stopped reading from stdin, and
       * request to send an asynchronous event.
       *)
      leave := true ;
      Alarm.rmv_sock_recv alarm stdin ;
      async () ;
    ) else (
      (* Append data to buffer and request to send an
       * asynchronous event.
       *)
      buffer := !buffer ^ (String.sub buf 0 len) ;
      async () ;
      if !verbose then (
	printf "MTALK:got line\n"
      )
    )
  in
  Alarm.add_sock_recv alarm name stdin (Handler0 get_input) ;

  (* If there is buffered data, then return a Cast action to
   * send it.
   *)
  let check_buf () =
    let data = 
      if !buffer <> "" then (
	let send = !buffer in
	buffer := "" ;
	[|Cast(send)|]
      ) else (
	[||]
      )
    in
    if !leave then (
      leave := false ;
      Array.append data [|Control(Leave)|]
    ) else (
      data
    )
  in

  (* If the origin is not the same as that of the last message,
   * print a new prompt.
   *)
  let check_id origin =
    if !last_id <> origin then (
      let name = !names.(origin) in
      printf "(mtalk:from %s)\n" name ;
      last_id := origin
    )
  in

  (* Various application interface handlers.
   *)
  let recv_cast origin msg =
    if !last_id <> origin then (
      let name = !names.(origin) in
      printf "(mtalk:origin %s)\n" name ;
      last_id := origin
    ) ;
    printf "%s" msg ;
    check_buf ()

  and recv_send _ _ = failwith "error"
  and block () = [||]
  and heartbeat _ =
    check_buf ()
  and block_recv_cast origin msg =
    check_id origin ;
    print_string msg
  and block_recv_send _ _ = ()
  and block_view (ls,vs) =
    [ls.rank,my_name]
  and block_install_view (ls,vs) s = s
  and unblock_view (ls',vs') s =
    names := Array.of_list s ;
    ls := ls' ;
    vs := vs' ;
    let view_s = String.concat ":" s in
    printf "(mtalk:view change:%d:%s)\n" !ls.nmembers view_s ;

    check_buf ()
  and exit () =
    printf "(mtalk:got exit)\n" ;
    exit 0
  in {
    recv_cast           = recv_cast ;
    recv_send           = recv_send ;
    heartbeat           = heartbeat ;
    heartbeat_rate      = Time.of_int 10 ;
    block               = block ;
    block_recv_cast     = block_recv_cast ;
    block_recv_send     = block_recv_send ;
    block_view          = block_view ;
    block_install_view  = block_install_view ;
    unblock_view        = unblock_view ;
    exit                = exit
  }

(**************************************************************)

let run () =
  (*
   * Parse command line arguments.
   *)
  Arge.parse [
    (*
     * Extra arguments can go here.
     *)
  ] (Arge.badarg name) "mtalk: multiperson talk program" ;

  (*
   * Get default transport and alarm info.
   *)
  let view_state = Appl.default_info "mtalk" in
  let alarm = Elink.alarm_get_hack () in

  (*
   * Choose a string name for this member.  Usually
   * this is "userlogin@host".
   *)
  let name =
    try
      let host = gethostname () in

      (* Get a prettier name if possible.
       *)
      let host = string_of_inet (inet_of_string host) in
      sprintf "%s@%s" (getlogin ()) host
    with _ -> (fst view_state).name
  in

  (*
   * Initialize the application interface.
   *)
  let interface = intf view_state name alarm in

  (* Wrap it with marshalling code.
   *)
  let interface = (Elink.get_appl_old_full name) interface in

(*let interface = Appl_intf.debug interface in*)

  (*
   * Initialize the protocol stack, using the interface and
   * view state chosen above.  
   *)
  Appl.config interface view_state ;

  (*
   * Enter a main loop
   *)
  Appl.main_loop ()
  (* end of run function *)


(* Run the application, with exception handlers to catch any
 * problems that might occur.
 *)
let _ = Appl.exec ["mtalk"] run

(**************************************************************)
