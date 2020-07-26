(**************************************************************)
(*
 *  Ensemble, 1.10
 *  Copyright 2001 Cornell University, Hebrew University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
(**************************************************************)
(* DB.ML: Distributed Database System *)
(* Author: Zhen Xiao, Mark Hayden, 7/97 *)
(**************************************************************)
open Dbm
(**************************************************************)
open Ensemble
open Trans
open Hsys
open Util
open View
open Appl_intf open Old
(**************************************************************)
exception Exit_DB
exception Cmd_Error
(**************************************************************)
let name = Trace.source_file "DB"
let failwith s = failwith (Util.failmsg name s)
(**************************************************************)

type ('key,'data) msg =
  | Close
  | Quit
  | Add of 'key * 'data
  | Find of 'key
  | Remove of 'key
  | Replace of 'key * 'data
  | Firstkey
  | Nextkey
  | All
      
let parse l =
  let com = List.hd l in
  match l with
  | ["close"] -> Close
  | ["quit"] -> Quit
  | ["add";key;data] -> 
      Add(key,data)
  | ["find";key] -> 
      Find(key)
  | ["remove";key] -> 
      Remove(key)
  | ["replace";key;data] ->
      Replace(key,data)
  | ["firstkey"] -> Firstkey
  | ["nextkey"] -> Nextkey
  | ["all"] -> All
  |  _ -> raise Cmd_Error
	

let apply db com =
  try
    match com with
    | Close -> 
	printf "Save changes to DB\n";
	Dbm.close db;
	raise Exit_DB
    | Quit -> raise Exit_DB
    | Add(key,data) -> Dbm.add db key data
    | Find(key) -> 
	let data = find db key in
	printf "%s\n" data
    | Remove(key) -> remove db key
    | Replace(key,data) -> replace db key data
    | Firstkey -> 
	let data = firstkey db in
	printf "%s\n" data
    | Nextkey ->
	let data = nextkey db in
	printf "%s\n" data
    | All ->
	printf "key\tdata\n";
	printf "--------------\n";
	let f key data = 
	  printf "%s\t%s\n" key data 
	in
	Dbm.iter f db
  with 
  | Not_found -> printf "Not found\n"
  | Dbm_error s -> printf "Dbm_error: %s\n" s
  | Exit_DB -> raise Exit_DB


(* This function returns the interface record that defines
 * the callbacks for the application.
 *)
let intf (ls,vs) db alarm =
  (* The current view state.
   *)
  let vs	= ref vs in
  let ls        = ref ls in

  (* This is the buffer used to store typed input prior
   * to sending it.
   *)
  let buffer 	= ref [] in

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
      printf "DB:about to read\n"
    ) ;
    let len = read stdin buf 0 (String.length buf) in
    if len = 0 then 
      exit 0 ;				(* BUG: should leave group *)
    if len > 1 then (
      let s = String.sub buf 0 (len - 1) in
      let l = Str.split (Str.regexp "[ \t]+") s in
      begin
      	try
      	  let msg = parse l in
      	  buffer := msg :: !buffer ; 
      	with
      	| Cmd_Error -> printf "Unknown command or too few arguments\n"
      	| Failure "nth" -> printf "Too few Arguments\n"
      end ;
      async () ;
      if !verbose then (
      	printf "DB:got line\n"
      )
    )
  in
  Alarm.add_sock_recv alarm name stdin (Handler0 get_input) ;

  (* If there is buffered data, then return a Cast action to
   * send it.
   *)
  let check_buf () =
    if !buffer <> [] then (
      let msgs = ref (List.map (fun com -> Cast(com)) !buffer) in
      begin
      	try
      	  List.iter (fun com -> apply db com) !buffer
      	with Exit_DB -> msgs := !msgs @ [Leave]
      end ;
      buffer := [] ;
      Array.of_list !msgs
    ) else (
      [||]
    )
  in

  (* Various application interface handlers.
   *)
  let recv_cast origin com =
    try
      apply db com ;
      check_buf ()
    with Exit_DB -> [|Leave|]

  and recv_send _ _ = failwith "error"
  and block () = [||]
  and heartbeat _ =
    check_buf ()
  and block_recv_cast origin msg =
    try
      apply db msg ; (* update DB locally *)
    with Exit_DB -> ()
  and block_recv_send _ _ = ()
  and block_view (ls,vs) =
    [ls.rank,()]
  and block_install_view (ls,vs) s = s
  and unblock_view (ls',vs') _ =
    ls := ls' ;
    vs := vs' ;
    printf "(DB:view change)\n" ;
    check_buf ()
  and exit () =
    printf "(DB:got exit)\n" ;
    exit 0
  in full {
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
  let filename = ref "database" in

  (*
   * Parse command line arguments.
   *)
  Arge.parse [
    "-database", Arg.String(fun s -> filename := s), "set the database name"
  ] (Arge.badarg name) "DB: database demo program" ;

  let db = opendbm !filename [Dbm_create;Dbm_rdwr] 511 in
 
  (*
   * Get default transport and alarm info.
   *)
  let view_state = Appl.default_info "DB" in
  let alarm = Alarm.get () in

  (*
   * Initialize the application interface.
   *)
  let interface = intf view_state db alarm in

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
(*
let _ = 
  Appl.exec ["DB"] run
*)

let _ =   run ()
(**************************************************************)
