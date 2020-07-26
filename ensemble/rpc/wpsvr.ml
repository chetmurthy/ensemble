(**************************************************************)
(*
 *  Ensemble, 1.10
 *  Copyright 2001 Cornell University, Hebrew University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
(* This is the White Pages service.  It is a small (replicated), non-
 * persistent data base of locations of services.  This service itself
 * lives at a more or less static locations.  The locations in the pages
 * are timestamped.  Services are supposed to refresh their locations
 * regularly (say, once a minute).  Locations that haven't been refreshed
 * in over 10 minutes are no longer considered valid (unless there's no
 * other choice).
 *)
open Ensemble
open Hsys
open Util
open View
open Appl_intf
open Rpc
open Filerpc
(**************************************************************)
let name = Trace.source_file "WPSVR"
let failwith s = failwith (Util.failmsg name s)
(**************************************************************)

(* These are the pages themselves.
 *)
let pages = ref []

(* Usage: "merge t list1 list2".  List1 is an association list of locations
 * to time.  List2 is a list of locations.  Merge the second list into the
 * first one, using t as the associated time.  Overwrite anything that's
 * in list1 already.
 *)
let rec merge t list = function
  | hd :: tl ->
      let (_, rest) =
	try
	  Xlist.take hd list
	with Not_found ->
	  (t, list)
      in
      merge t ((hd, t) :: rest) tl
  | [] ->
      list

(* Update the white pages with this information.
 *)
let update name locs =
  let (curlocs, rest) =
    try
      Xlist.take name !pages
    with Not_found ->
      ([], !pages)
  in
  let now = Hsys.gettimeofday() in
  let locs = merge now curlocs locs in
  pages := (name, locs) :: rest

(* Get all the entries that are younger than old.
 *)
let rec filter old = function
  | (loc, t) :: tl ->
      if t > old then loc :: (filter old tl)
      else filter old tl
  | [] ->
      []

(* This function returns the interface record that defines
 * the callbacks for the application.
 *)
let intf vs my_name alarm =
  (* The current view state.
   *)
  let vs = ref vs in

  (* This is a queue of actions to be returned, for example, by the
   * next heartbeat, and some functions to manipulate it.
   *)
  let queue = ref [] in
  let enqueue x = queue := !queue @ [x] in
  let add_queue l = queue := !queue @ l in

  (* This is an association list of (endpt,string name) for every
   * member in the group.
   *)
  let names = ref [(!vs.endpt,my_name)] in

  (* This is set below in the handler of the same name.  Get_input
   * calls the installed function to request an immediate callback.
   *)
  let heartbeat_now = ref (fun () -> ()) in

  (* Evaluate a user command.
   *)
  let eval rid = function
    | Sockio.WP_UPDATE(name, locs) ->
	enqueue (Cast (name, locs));  (* TODO: not necessary with local delivery *)
	update name locs;
        Sockio.response rid ()
    | Sockio.WP_LOOKUP name ->
        try
	  let tlocs = List.assoc name !pages in
	  let now = Hsys.gettimeofday() in
	  let locs =
	    let flocs = filter (now -. 600.0) tlocs in
            if flocs = [] then List.map (fun (l,t) -> l) tlocs
	    else flocs
	  in
          Sockio.response rid locs
        with Not_found ->
	  Sockio.except rid "no such entry"
  in

  (* Like eval, but catch exceptions.
   *)
  let catch_eval rid cmd =
    try
      eval rid cmd
    with _ ->
      Sockio.except rid "something went wrong"
  in

  (* Start the service.
   *)
  begin
    try
      Sockio.start 2222 catch_eval
    with _ ->
      Sockio.start 2223 catch_eval
  end;

  (* Return the buffered actions.
   *)
  let check_buf () =
    let actions = !queue in
    queue := [];
    actions
  in

  let recv_cast origin (name, locs) =
    update name locs;
    check_buf()
  and recv_send origin msg =
    failwith "Got a SEND event"
  and block () = []
  and heartbeat _ =
    Sockio.sweep();
    check_buf ()

  and block_recv_cast origin (name, locs) =
    update name locs
  and block_recv_send origin msg =
    failwith "Got a BLOCK_SEND event"
  and block_request_merge _ =
    !names
  and block_accept_merge _ names' =
    names := !names @ names'
  and block_install_view _ =
    !names
  and unblock_view vs' names' =
    names := names' ;
    vs := vs' ;
    let view_s = List.map (fun e -> List.assoc e !names) !vs.view in
    let view_s = String.concat ":" view_s in
    printf "(wpsvr:view change:%s)\n" view_s ;
    check_buf ()

  and exit () =
    printf "(wpsvr:got exit)\n" ;
    exit 0

  and heartbeat_now f =
    heartbeat_now := f

  in {
    recv_cast           = recv_cast ;
    recv_send           = recv_send ;
    heartbeat           = heartbeat ;
    heartbeat_rate      = Time.of_float 10.00 ;
    block               = block ;
    block_recv_cast     = block_recv_cast ;
    block_recv_send     = block_recv_send ;
    block_request_merge = block_request_merge ;
    block_accept_merge  = block_accept_merge ;
    block_install_view  = block_install_view ;
    unblock_view        = unblock_view ;
    heartbeat_now	= heartbeat_now ;
    exit                = exit
  }

(**************************************************************)

let run () =
  (*
   * Parse command line arguments.
   *)
  Arg.parse ([
    (*
     * Extra arguments can go here.
     *)
  ] @ Harg.args) (Harg.badarg name) ;

  (*
   * Get default transport and alarm info.
   *)
  let view_state = Appl.default_info "wpsvr" in
  let alarm = Transport.alarm () in
  let endpt = view_state.endpt in

  Sockio.ensemble_register (Alarm.add_sock alarm) (Alarm.rmv_sock alarm) ;

  (*
   * Choose a string name for this member.  Usually
   * this is "userlogin@host".
   *)
  let name =
    try
      sprintf "%s@%s" (getlogin ()) (gethostname ())
    with _ ->
      Endpt.string_of_id endpt
  in

  (*
   * Initialize the application interface.
   *)
  let interface = intf view_state name alarm in

  (*
   * Initialize the protocol stack, using the interface and
   * view state chosen above.  
   *)
  Hstack.config_stack interface view_state ;

  (*
   * Enter a main loop
   *)
  Appl.main_loop 1
  (* end of run function *)

(* Run the application, with exception handlers to catch any
 * problems that might occur.
 *)
let _ = Appl.exec ["wpsvr"] run

