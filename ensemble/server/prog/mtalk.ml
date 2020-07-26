(**************************************************************)
(* MTALK.ML: multiperson talk program. *)
(* Author: Mark Hayden, 8/95 *)
(**************************************************************)
open Ensemble
open Trans
open Hsys
open Util
open View
open Appl_intf open New
(**************************************************************)
let name = Trace.file "MTALK"
let failwith s = Trace.make_failwith name s
(**************************************************************)
type name = string

type msg = 
    Reg of string
  | Name of name
  | NameArray of name array

type state = {
  my_name         : string ;
  mutable async   : unit -> unit;
  mutable buffer  : string ;
  mutable leave   : bool ;
  mutable blocked : bool ;
  mutable names   : name array ;
  mutable last_id : int ;
  mutable accu    : name array ;
  mutable n_name  : int
}


let state my_name = {
  my_name = my_name ;
  async = (fun _ -> failwith "");

  (* This is the buffer used to store typed input prior
   * to sending it.
   *)
  buffer = "" ;
  leave  = false;
  
  (* Are we blocked?
   *)
  blocked = false ;
  
  (* This is an array of string names for every
   * member in the group.
   *)
  names = [|my_name|];
  
  (* This is the last member to have sent data to be output.
   * When another member sends data, we print a prompt for
   * the new source and update this val.
   *)
  last_id = (-1);

  accu = [||] ;
  n_name = 0
}

(* This function returns the interface record that defines
 * the callbacks for the application.
 *)
let intf my_name alarm = 
  let s = state my_name in
  
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
      s.leave <- true ;
      Alarm.rmv_sock_recv alarm stdin ;
      s.async () ;
    ) else (
	(* Append data to buffer and request to send an
	 * asynchronous event.
	 *)
      s.buffer <- s.buffer ^ (String.sub buf 0 len) ;
      s.async () ;
      if !verbose then (
	printf "MTALK:got line\n"
      )
    )
  in
  Alarm.add_sock_recv alarm name stdin (Handler0 get_input) ;
  
  
  (* This handler gets invoked when a new view is installed.
    *)
  let install (ls,vs) = 
    (*printf "(mtalk: beginning of view change %d)\n" ls.nmembers;*)

    (* This is set below in the handler of the same name.  Get_input
     * calls the installed function to request an immediate callback.
     *)
    s.async <- Appl.async (vs.group,ls.endpt);
    s.blocked <- false;

    (* Called when the state-transfer protocol is complete, 
     * and all group-member names are known. 
     *)
    let final name_a = 
      let view_s = String.concat ":" (Array.to_list name_a) in
      printf "(mtalk:view change:%d:%s)\n" ls.nmembers view_s;
      s.names <- name_a;
      s.accu <- [||] ;
      s.n_name <- 0
    in
    
    (* If there is buffered data, then return a Cast action to
     * send it.
     *)
    let check_buf () =
      let data = 
	if not s.blocked 
	  && ls.nmembers > 1 then 
	    if s.buffer <> "" then (
	      let send = s.buffer in
	      s.buffer <- "" ;
	      [|Cast(Reg send)|]
	    ) else (
	      [||]
	    )
	else [||]
      in
      
      if s.leave then (
	s.leave <- false ;
	Array.append data [|Control(Leave)|]
      ) else (
	data
      )
    in
    
    (* If the origin is not the same as that of the last message,
     * print a new prompt.
     *)
    let check_id origin =
      if s.last_id <> origin then (
	let name names_array = 
    if origin < Array.length names_array then
      "???"
    else
      names_array.(origin) in
	  printf "(mtalk:from %s)\n" (name s.names);
	  s.last_id <- origin
      )
    in
    
    
    let receive origin _ cs msg = 
      match msg with 
	  (* The regular case: 
	   * A string message from another user.
	   *)
	  Reg msg -> 
	    if s.last_id <> origin then (
	      let name names_array= 
          if origin < Array.length names_array then
            "???"
          else
            names_array.(origin) in
	      printf "(mtalk:origin %s)\n" (name s.names) ;
	      s.last_id <- origin
	    ) ;
	    printf "%s" msg ;
	    check_buf ()
	| Name rmt_name -> 
	    assert (ls.rank = 0);
      assert (origin < Array.length s.accu);
	    s.accu.(origin) <- rmt_name;
	    s.n_name <- succ s.n_name;
	    if s.n_name = ls.nmembers then (
	      let copy_accu = Array.of_list (Array.to_list s.accu) in
	      final s.accu;
	      if not s.blocked then [|Cast (NameArray copy_accu)|] else [||]
	    ) else
	      [||]
	| NameArray accu -> 
	    final accu;
	    [||]

    and block () = 
      s.blocked <- true;
      [||]
      
    and heartbeat _ =
      check_buf ()
    in

    let handlers = { 
      flow_block = (fun _ -> ());
      receive = receive ;
      block = block ;
      heartbeat = heartbeat ;
      disable = Util.ident
    } in

    let actions = 
      if ls.nmembers > 1 then (
	if ls.rank = 0 then (
	  s.accu <- Array.create ls.nmembers "";
	  s.accu.(0) <- s.my_name;
	  s.n_name <- succ s.n_name;
	  [||]
	) else (
	  printf "Sending name\n";
	  [|Send1(0, Name s.my_name)|]
	)
      ) else (
	final  [|s.my_name|];
	check_buf ()
      )
    in
    
    (* The set of actions and handlers given to the system
     * upon startup. 
     *)
    actions,handlers
  in

  let exit () =
    printf "(mtalk:got exit)\n" ;
    exit 0
  in
  
  full { 
    heartbeat_rate      = Time.of_int 3 ;
    install             = install ;
    exit                = exit 
  }
    
(**************************************************************)
    
let run () =
  (* Minimize memory usage *)
  Arge.set Arge.chunk_size (32*1024);
  Arge.set Arge.max_mem_size (1024*1024);

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

  let alarm = Appl.alarm "mtalk" in

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
  let interface = intf name alarm in

  (*
   * Initialize the protocol stack, using the interface and
   * view state chosen above.  
   *)
  Appl.config_new interface view_state ;

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
