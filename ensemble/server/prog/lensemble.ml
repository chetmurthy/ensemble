(**************************************************************)
(* LENSEMBLE.ML: text-based interface to Ensemble *)
(* Author: Mark Hayden, 8/95 *)
(**************************************************************)
open Ensemble
open Hsys
open Util
open View
open Appl_intf open New
open Trans
(**************************************************************)
let name = Trace.file "ENSEMBLE"
let failwith s = Trace.make_failwith name s
(**************************************************************)

type tcontrol = 
  | TLeave
  | TPrompt
  | TSuspect of rank list
  | TXferDone 
  | TRekey
  | TProtocol of Proto.id
  | TMigrate of Addr.set
  | TTimeout of Time.t
  | TDump
  | TBlock of bool

type taction =
  | TCast of string
  | TSend of string * string
  | TControl of tcontrol

let read_lines () =
  let stdin = Hsys.stdin () in
  let buf = String.create 10000 in
  let len = Hsys.read stdin buf 0 (String.length buf) in
  if len = 0 then raise End_of_file ;
  let buf = String.sub buf 0 len in
  let rec loop buf =
    try 
      let tok,buf = strtok buf "\n" in
      if tok = "" then (
	loop buf 
      ) else (
	tok :: loop buf
      )
    with Not_found -> []
  in
  loop buf

(* This function returns the interface record that defines
 * the callbacks for the application.
 *)
let intf endpt alarm sync =

  (* This is the buffer used to store typed input prior
   * to sending it.
   *)
  let buffer 	= ref [] in
  
  (* View_inv is a hashtable for mapping from endpoints to ranks.
   *)
  let view_inv	= ref (Hashtbl.create 10) in
  let view	= ref [||] in

  (* This is set below in the handler of the same name.  Get_input
   * calls the installed function to request an immediate callback.
   *)
  let async_r = ref (fun () -> ()) in
  let async () = !async_r () in

  let action act =
    buffer := act :: !buffer ;
    async ()
  in

  (* Handler to read input from stdin.
   *)
  let prev_buf = ref "" in
  let get_input () =
    let buf = String.create 4096 in
    let len = Hsys.read (stdin()) buf 0 (String.length buf) in
    if len = 0 then exit 0 ;
    let buf = String.sub buf 0 len in
    let lines =
      let rec loop buf =
	if not (String.contains buf '\n') then (
	  prev_buf := !prev_buf ^ buf ;
	  []
	) else (
	  let buf = !prev_buf ^ buf in
	  prev_buf := "" ;
	  try 
	    let line,buf = strtok buf "\n" in
	    line :: loop buf
	  with Not_found -> 
	    (* It must have been all '\n's.
	     *)
	    []
	)
      in loop buf
    in

    List.iter (fun line ->
      let com,rest = 
	try strtok line " \t" with
	  Not_found -> ("","")
      in
      match com with
      |	"" -> ()
      | "cast" ->
	  action (TCast(rest))
      | "send" -> 
	  let dest,rest = strtok rest " \t" in
	  begin try Hashtbl.find !view_inv dest with
	  | Not_found ->
	      eprintf "ENSEMBLE:bad endpoint name:'%s'\n" dest ;
	      failwith "bad endpoint name"
	  end ;
	  action (TSend(dest,rest))
      | "leave" ->
	  action (TControl TLeave)
      | "prompt" ->
	  action (TControl TPrompt)
      | "suspect" -> 
	  let susp,_ = strtok rest " \t" in
	  let susp = int_of_string susp in
	  action (TControl (TSuspect [susp]))
      | "xferdone" -> 
	  action (TControl TXferDone)
      | "rekey" -> 
	  action (TControl TRekey)
      | "protocol" -> 
	  let proto,_ = strtok rest " \t" in
	  let proto = Proto.id_of_string proto in
	  action (TControl (TProtocol proto))
      | "migrate" -> 
	  failwith "Currently not supported"
      | "timeout" -> 
	  let time,_ = strtok rest " \t" in
	  let time = float_of_string time in
	  let time = Time.of_float time in 
	  action (TControl (TTimeout time))
      | "block" ->
	  let blk,_ = strtok rest " \t" in
	  let blk = bool_of_string blk in
	  action (TControl (TBlock blk))
      | other -> 
	  eprintf "bad command '%s'\n" other;
	  eprintf "commands:\n" ;
	  eprintf "  cast <msg>           : Cast message\n" ;
	  eprintf "  send <dst> <msg>     : Send pt-2-pt message\n" ;
	  eprintf "  leave                : Leave the group\n" ;
	  eprintf "  prompt               : Prompt for a view change\n" ;
	  eprintf "  suspect <suspect>    : Suspect a member\n" ;
	  eprintf "  xferdone             : State transfer is complete\n" ;
	  eprintf "  rekey                : rekey the group\n" ;
	  eprintf "  protocol <proto_id>  : switch the protocol\n" ;
	  eprintf "  migrate <address>    : migrate to a new address\n" ;
	  eprintf "  timeout <time>       : request a timeout\n" ;
	  eprintf "  block   <true/false> : block (yes/no)\n" ;
	  ()
    ) lines
  in
  Alarm.add_sock_recv alarm name (Hsys.stdin()) (Handler0 get_input) ;

  (* If there is buffered data, then return a Cast action to
   * send it.
   *)
  let check_actions () =
    let actions = ref [] in
    List.iter (function
      | TCast msg -> 
      	  actions := Cast msg :: !actions
      | TSend(dest,msg) -> (
	  try 
      	    let dest = Hashtbl.find !view_inv dest in
	    actions := Send1(dest,msg) :: !actions
	  with Not_found -> ()
      	)
      | TControl tc -> 
	  let action = match tc with 
	    | TLeave -> Leave 
	    | TPrompt -> Prompt
	    | TSuspect rl -> Suspect rl
	    | TXferDone  -> XferDone
	    | TRekey -> Rekey false
	    | TProtocol p -> Protocol p
	    | TMigrate addr -> Migrate addr
	    | TTimeout t -> Timeout t
	    | TDump -> Dump
	    | TBlock b -> Block b
	  in
      	  actions := Control action :: !actions
    ) !buffer ;
    buffer := [] ;
    Array.of_list !actions
  in

  (* Print out the name.
   *)
  printf "endpt %s\n" (Endpt.string_of_id endpt) ;

  let install (ls,vs) =
    async_r := Appl.async (vs.group,ls.endpt) ;
    view := Array.map Endpt.string_of_id (Arrayf.to_array vs.view) ;
    view_inv := Hashtbl.create 10 ;
    printf "view %d %d %s\n"
      ls.nmembers ls.rank
      (String.concat " " (Array.to_list !view)) ;
    for i = 0 to pred ls.nmembers do
      Hashtbl.add !view_inv !view.(i) i
    done ;
    
    (* Various application interface handlers.
     *)
    let receive origin bk cs =
      match bk,cs with
      | U,C -> fun msg -> printf "cast %d %s\n" origin msg ; check_actions ()
      | U,S -> fun msg -> printf "send %d %s\n" origin msg ; check_actions ()
      | B,C -> fun msg -> printf "cast %d %s\n" origin msg ; [||]
      | B,S -> fun msg -> printf "send %d %s\n" origin msg ; [||]
    in

    let heartbeat _ =
      let num,lens = Iovec.debug () in
      printf "refcounts = %d,%d\n" num lens;
      check_actions ()
    in

    let block () = 
      if sync then (
	(* Disable blocking.
	 *)
	printf "block\n" ;
	Array.append [|Control (Block false)|] (check_actions ())
      ) else (
	check_actions ()
      )
    in
    
    let handlers = { 
      flow_block = (fun _ -> ());
      receive = receive ;
      block = block ;
      heartbeat = heartbeat ;
      disable = Util.ident
    } in

    let actions = check_actions () in

    actions,handlers
  in

  let exit () =
    printf "exit\n" ;
    exit 0
  in

  full { 
    heartbeat_rate      = Time.of_int 3 ;
    install             = install ;
    exit                = exit 
  }

(**************************************************************)

let run () =
  let nice = ref false in
  let sync = ref false in
  let endpt = ref None in

  (*
   * Parse command line arguments.
   *)
  Arge.parse [
    (*
     * Extra arguments go here.
     *)
    "-nice", Arg.Set(nice), ": use minimal resources" ;
    "-sync", Arg.Set(sync), ": synchronize on view changes" ;
    "-endpt", Arg.String(fun s -> endpt := Some s), "set the endpoint name"
  ] (Arge.badarg name) "line based ascii interface to ensemble" ;

  (*
   * Get default transport and alarm info.
   *)
  let (ls,vs) = Appl.default_info (Arge.get Arge.group_name) in

  let vs =
    if not !nice then vs else 
      View.set vs [
        Vs_params [
	  "suspect_sweep",Param.Time(Time.of_int 1) ;
	  "suspect_max_idle",Param.Int(5)
        ]
      ]
  in

  (* Recompute the view state info if command line specifies
   * a particular endpoint name.
   *)
  let (ls,vs) = 
    match !endpt with
    | None -> (ls,vs)
    | Some endpt ->
	let endpt = Endpt.extern endpt in
	let vs = View.set vs [Vs_view (Arrayf.of_array [|endpt|])] in
	let ls = View.local name endpt vs in
	(ls,vs)
  in

  let alarm = Appl.alarm "ensemble" in

  (*
   * Initialize the application interface.
   *)
  let interface = intf ls.endpt alarm !sync in

  (*
   * Initialize the protocol stack, using the interface and
   * view state chosen above.  
   *)
  Appl.config_new interface (ls,vs) ;

  (*
   * Enter a main loop
   *)
  Appl.main_loop ()
  (* end of run function *)


(* Run the application, with exception handlers to catch any
 * problems that might occur.
 *)
let _ = Appl.exec ["ensemble"] run

(**************************************************************)
