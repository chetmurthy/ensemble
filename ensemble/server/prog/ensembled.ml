(**************************************************************)
(* ENSEMBLED.ML *)
(* Author:  Ohad Rodeh, 10/2003 *)
(* Based on code by Mark Hayden and Alexey Vaysburd *)
(**************************************************************)
open Ensemble
open Util
open Trans
open View
open Appl_intf
  open New
open Marsh
open Buf
(**************************************************************)
let name = Trace.file "ENSEMBLED"
let failwith s = Trace.make_failwith name s
let log = Trace.log name
let log2 = Trace.log (name^"2")
let log3 = Trace.log (name^"3")
let logc = Trace.log (name^"C")
(**************************************************************)
(* The type of an upcall *)
type upcall = 
  | UInstall of View.full
  | UReceive of origin * cast_or_send * Iovecl.t
  | UBlock
  | UExit

let string_of_upcall = function 
  | UInstall _ -> "UInstall"
  | UReceive _ -> "UReceive"
  | UBlock -> "UBlock"
  | UExit -> "UExit"

let string_of_dncall = function
  | 1 -> "Join"
  | 2 -> "Cast"
  | 3 -> "Send"
  | 4 -> "Send1"
  | 5 -> "Suspect"
  | 6 -> "Leave"
  | 7 -> "BlockOk"
  | _ -> failwith sanity

(**************************************************************)
(* Some type aliases.
 *)
type endpt = string
type msg = string
type c_view_id = int * string

let c_view_id_of_ml (ltime,endpt) = 
  (ltime, Endpt.string_of_id endpt)

(**************************************************************)

(* View state structure passed to the application. 
 *)
type c_view_state = {
  c_version : string ;
  c_group : string ;
  c_proto : string ;
  c_coord : rank ;
  c_ltime : ltime ;
  c_primary : bool ;
  c_groupd : bool ;
  c_xfer_view : bool ;
  c_key : string ;
  c_prev_ids : c_view_id array ; 
  c_params :   string ;
  c_uptime : float ;

  (* Per-member arrays.
   *)
  c_view : string array ;
  c_address : string array 
} 


type c_local_state = {
  c_endpt	: string ;
  c_addr	: string ;
  c_rank        : int ;
  c_name	: string ; 
  c_nmembers    : int ;
  c_view_id 	: c_view_id ;	
  c_am_coord    : bool ;  
}  

(* These options are passed with application's join()
 * downcalls.  
 *)
type jops = {
  jops_group_name	: string ;
  jops_properties	: string ;
  jops_params	        : string ;
  jops_princ            : string ;
  jops_secure           : bool
}

(**************************************************************)

(* Convert a param string into a param list.
 * Format of the param string: "name=val:type;...." 
 * (see Param.t for supported types).  The type of param list is Param.tl.
 *) 

let paraml_of_string s = 
  log2 (fun () -> sprintf "parameters=%s" s) ;
  let params = Util.string_split ";" s in
  List.map (fun param ->
    try
      match Util.string_split "=" param with
      | [param_name;rest] -> (
	  let value =
	    match Util.string_split ":" rest with
	    | [param_str;param_type] -> (
		match param_type with
		| "string" -> Param.String(param_str)
		| "int"    -> Param.Int(int_of_string param_str)
		| "float"  -> Param.Float(float_of_string param_str)
		| "bool"   -> Param.Bool(bool_of_string param_str)
		| "time"   -> Param.Time(Time.of_float(float_of_string param_str))
		| _ -> failwith "HOT_UTIL: bad parameter type"
	      )
	    | _ -> failwith "HOT_UTIL: bad parameter format"
	  in param_name,value
	)
      | _ -> failwith "HOT_UTIL: bad parameter format"
    with _ ->
      eprintf "HOT_UTIL: parameter parsing error\n" ;
      eprintf "  parameter='%s'\n" param ;
      eprintf "  sample format: 'integerparam=1:int;timeparam2=1.0:time'\n" ;
      exit 1
  ) params
   
(* Convert a param list into a param string.
 *)
let string_of_paraml p = 
  let p = List.map Param.to_string p in
  String.concat ";" p


(* Add an address my list of addresses.
 *)
let add_principal princ (ls,vs) = 
  log2 (fun () -> "add_principal"); 
  if String.length princ = 0 then (
    (ls,vs)
  ) else if String.length princ <= 5 then 
    failwith (sprintf "principal name is too short (%s)" princ)
  else (
    let sub = String.sub princ 0 4 in
    match sub with
      | "Pgp(" -> 
	  let princ = String.sub princ 4 (String.length princ - 5) in
	  let base = Addr.arrayf_of_set (Arrayf.get vs.address ls.rank) in
	  let pgp = Addr.PgpA(princ) in
	  let pgp = Arrayf.singleton pgp in
	  let addr = Arrayf.append base pgp in
	  let addr = Addr.set_of_arrayf addr in
	  let addr = Arrayf.singleton addr in
	  let vs = View.set vs [Vs_address addr] in
	  let ls = View.local name ls.endpt vs in
	  (ls,vs)
      | _ -> 
	  failwith "Only Pgp is currently supported"
  )
(**************************************************************)

(* Initialize a group member and return the initial singleton view 
 *)
let init_view_full jops = 
  let properties = 
    let props_l = Util.string_split ":" jops.jops_properties in
    List.map Property.id_of_string props_l
  in      
  let group_name = jops.jops_group_name in
  let protocol = Property.choose properties in
  let params = jops.jops_params in
  let params = paraml_of_string params in
  
  let endpt =
    let alarm = Appl.alarm name in
    Endpt.id (Alarm.unique alarm)
  in
  
  let princ = jops.jops_princ in
  let secure = jops.jops_secure in

  let modes = Arge.get Arge.modes in
  let (ls,vs) =
    Appl.full_info group_name endpt (*groupd*) false (*Protos*) false 
      protocol modes Security.NoKey
  in
  let vs = View.set vs [
    View.Vs_params params ;
  ] in
  let (ls,vs) = add_principal princ (ls,vs) in
  let (ls,vs) = 
    if secure then
      let key = match Arge.get Arge.key with
	| None -> Security.NoKey
	| Some s -> Security.key_of_buf (Buf.of_string s)
      in
      let vs = View.set vs [
	View.Vs_key key ;
      ] in
      Appl.set_secure (ls,vs) properties
    else (ls,vs)
  in
  (ls,vs)
  
(**************************************************************)

(* Convert a view state into a structure in the C
 * application format.
 *)
let c_view_full (ls,vs) = 
  let key = match vs.key with 
    | Security.NoKey -> ""
    | Security.Common _ -> Buf.string_of (Security.buf_of_key vs.key)
  in    
  let c_prev_ids = Array.of_list (List.map c_view_id_of_ml vs.prev_ids) in
  let c_vs = { 
    c_version = Version.string_of_id vs.version ;
    c_group = Group.string_of_id vs.View.group ;
    c_coord = vs.coord;
    c_ltime = vs.View.ltime ;
    c_primary = vs.View.primary ;
    c_proto = Proto.string_of_id vs.View.proto_id ;
    c_groupd = vs.View.groupd ;
    c_xfer_view = vs.View.xfer_view ;
    c_key  =  key ;
    c_prev_ids = c_prev_ids ;
    c_params = string_of_list Param.to_string vs.params ;
    c_uptime = Time.to_float vs.uptime ;
    c_view = Array.map Endpt.string_of_id (Arrayf.to_array vs.View.view) ;
    c_address = Array.map Addr.string_of_set (Arrayf.to_array vs.address)
  } in
  let c_ls = {
    c_endpt = Endpt.string_of_id ls.endpt ;
    c_addr = Addr.string_of_set ls.addr ;
    c_rank = ls.rank ;
    c_name = ls.name ;
    c_nmembers = ls.nmembers ;
    c_view_id = c_view_id_of_ml ls.view_id ;
    c_am_coord = ls.am_coord
  } in
  (c_ls,c_vs)

(**************************************************************)
(* Marshalling and unmarshalling.  These functions are using
 * the Ensemble Marsh module.  For marshalling, we first write
 * into a "marshaller", then convert that to a string, and
 * finally write the string out preceded by its length.
 *)

let write_init = Marsh.marsh_init

let write_endpt = write_string
let write_msg m buf ofs len = write_string m (String.sub buf ofs len)
let write_gctx = write_int
let write_cbtype = write_int
let write_endpt_array m = write_array m (write_endpt m)
let write_string_array m = write_array m (write_string m)
let write_bool_array m = write_array m (write_bool m)
let write_view_id m (ltime,endpt) = 
  write_int m ltime;
  write_endpt m endpt
let write_view_id_array m = write_array m (write_view_id m)

(**************************************************************)

let up_view      = 1
and up_cast      = 2 
and up_send      = 3 
and up_block     = 4
and up_exit      = 5 

(* Pre-allocated buffer for the ML header
*)
let prealloc_send_buf = Buf.create len12

let marsh_upcall id msg send_f = 
  log3 (fun () -> string_of_upcall msg);
  match msg with
    | UInstall vf ->
	let c_ls,c_vs = c_view_full vf in
	
	let m = write_init () in
	write_gctx m id ;
  	write_cbtype m up_view ;
	
	(* First, write the number of members in the view.
	*)
        log (fun () -> sprintf "nmembers=%d" c_ls.c_nmembers);
	write_int m c_ls.c_nmembers;
        
	(* The rest of the data
	*)
  	write_string m c_vs.c_version ;
  	write_string m c_vs.c_group ;
  	write_string m c_vs.c_proto ;
	write_int m c_vs.c_ltime;
	write_bool m c_vs.c_primary;
	log (fun () -> sprintf "params=%s" c_vs.c_params);
  	write_string m c_vs.c_params ;
	log (fun () -> sprintf "address (%s)" (string_of_array ident c_vs.c_address));
	write_string_array m c_vs.c_address;
	log (fun () -> sprintf "view (%s)" (string_of_array ident c_vs.c_view));
	write_string_array m c_vs.c_view;
	
	write_endpt m c_ls.c_endpt;
	write_string m c_ls.c_addr;
	write_int m c_ls.c_rank;
	write_string m c_ls.c_name;
	write_view_id m c_ls.c_view_id;
	
	let buf = Marsh.marsh_done m in
	send_f buf len0 (Buf.length buf) Iovecl.empty
	  
    | UReceive(origin,cs,iovl) -> (
	let buf = prealloc_send_buf in
	write_int32 buf len0 id ;
	let typ = 
	  match cs with
	    | Appl_intf.New.C -> up_cast
	    | Appl_intf.New.S -> up_send
	in
	write_int32 buf len4 typ ;
	write_int32 buf len8 origin ;
	send_f buf len0 len12 iovl
      )
    | UBlock ->
	let buf = prealloc_send_buf in
	write_int32 buf len0 id ;
	write_int32 buf len4 up_block;
	send_f buf len0 len8 Iovecl.empty
    | UExit ->
	let buf = prealloc_send_buf in
	write_int32 buf len0 id ;
	write_int32 buf len4 up_exit;
	send_f buf len0 len8 Iovecl.empty
	  
(**************************************************************)
	  
(* Process input from socket.  
*)

(* Helper variables for reading destinations *)
type local_help = {
  mutable len : len ;
  mutable dests : int list;
  mutable suspects : int list
}

let g = {
  len = len0 ;
  dests = [] ;
  suspects = []    
}


let dncall_unmarsh create_new recv_action buf len iovl =
  let id = Buf.read_int32 buf len0 in
  let dntype = Buf.read_int32 buf len4 in
  log3 (fun () -> sprintf "id=%d dntype=%s buf_len=%d iov_len=%d" id 
    (string_of_dncall dntype)
    (Buf.int_of_len len) (Buf.int_of_len (Iovecl.len iovl))
  );
  begin match dntype with
    | 1 ->
	let m = Marsh.unmarsh_init buf len8 (len -|| len8) in
	let group_name = Marsh.read_string m in
	let properties = Marsh.read_string m in
	let params = Marsh.read_string m in
	let princ = Marsh.read_string m in
	let secure = Marsh.read_bool m in
	Marsh.unmarsh_check_done_all m ;
	
	let jops = {
	  jops_group_name = group_name;
	  jops_properties = properties;
	  jops_params = params;
	  jops_princ  = princ;
	  jops_secure = secure
	} in
	let _,vs = init_view_full jops in
	(* We aren't using heartbeats here, however, it turns out that we sometime
	 * need them to ensure liveness of the Protos code. 
	 *)
	let modes = Arge.get Arge.modes in
	create_new id vs modes
    | 2 ->				(* Cast *)
	recv_action id (Cast(iovl))
    | 3 ->				(* Send*)
	let size = Buf.read_int32 buf len8 in
	g.len <- len8;
	g.dests <- [];
	for i = 1 to size do
	  g.len <- g.len +|| len4;
	  let dest = Buf.read_int32 buf g.len in 
	  g.dests <- dest :: g.dests
	done;
	let dests = Array.of_list (List.rev g.dests) in
	g.dests <- [];
	recv_action id (Send(dests,iovl))
    | 4 ->				(* Send1*)
	let dest = Buf.read_int32 buf len8 in
	log (fun () -> sprintf "Send, dest=%d" dest);
	recv_action id (Send1(dest,iovl))
    | 5 ->				(* Suspect *)
	let size = Buf.read_int32 buf len8 in
	g.len <- len8;
	g.suspects <- [];
	for i = 1 to size do
	  g.len <- g.len +|| len4;
	  let suspect = Buf.read_int32 buf g.len in 
	  g.suspects <- suspect :: g.suspects
	done;
	let suspects = List.rev g.suspects in
	g.suspects <- [];
	recv_action id (Control (Suspect suspects))
    | 6 ->				(* Leave *)
	recv_action id (Control Leave)
    | 7 ->				(* Block *)
	recv_action id (Control(Block true))
    | _ -> failwith (sprintf "bad message id in dncall_unmarsh (id=%d" dntype)
  end;
  ()

(**************************************************************)
(* A fast Protos-like server
*)
module Server = struct
  type intf_state = {
    mutable got_leave  : bool; 
    mutable am_blocked : Appl_intf.New.blocked;
    mutable disabled   : bool;
  }

  let init_intf_s () = {
    got_leave = false;
    am_blocked = U;
    disabled = false
  }

  (* Create an interface for a new member. *)
  let interface send_up exited id intf_s =
    let write_upcall msg = marsh_upcall id msg send_up in
      
    let transl_dncall = function
      | Control Leave ->
	  intf_s.got_leave <- true ;
      | Control (Block true) ->
	  intf_s.am_blocked <- B ;
      | _ -> ()
    in
    
    (* Got a new view, prepare the message handlers.
    *)
    let install ((ls,vs) as vf) =
      let need_block_ok = ref false in
      intf_s.am_blocked <- U;
      
      (* Deliver the view state to the application.
      *)
      write_upcall (UInstall vf) ;
      
      (* Got a message. Send the message up to the client through a
       * socket.
       * 
       * This gets handled in two stages.  First, we take the origin,
       * blocked, cast_or_send arguments and do some preprocessing.
       * Second, we generate functions taking the last argument -- the
       * actual message.  This improves performance because the first
       * arguments are applied by Ensemble at the view change and in
       * the normal case we only deal with the last argument.  
       *)
      let receive origin blocked cast_or_send =
	let handler iovl =
	  (* The following check is not valid because of the
	   * stuff we do with Control(Block(_)).
	   *)
	  (*assert (blocked = !am_blocked) ;*)
	  write_upcall (UReceive(origin,cast_or_send,iovl)) ;
	  [||]
	in handler
      in
      
      (* Got a heartbeat callback.  *)
      let heartbeat time = 
	(* If the connection was disabled, we need to continue
	 * the blocking protocol for the (failed) client so that
	 * the stack will be released.
	 *)
	if intf_s.disabled && !need_block_ok then (
	  need_block_ok := false ;
	  [|Control(Block true)|]
	) else (
	  [||]
	)
      in
      
      (* The group is about to block.  Tell the application it
       * should not request Ensemble's attention until the
       * next view is installed.  Return the list of pending
       * actions.  
       *)
      let block () =
	write_upcall UBlock ;
	
	(* Add a Block(false) action, unless already disabled.
	*)
	if intf_s.disabled then (
	  [||]
	) else (
	  need_block_ok := true ;
	  [|Control(Block false)|]
	)
      in
      
      let handlers = {
	flow_block = (fun _ -> ());
	heartbeat = heartbeat ;
	receive = receive ;
	block = block ;
	disable = ident
      } in
      
      ([||],handlers)
    in
    
    (* We have left the group.  Notify the C application.
     * The id is invalidated.
     *)
    let exit () =
      write_upcall UExit ;
      exited ()
(*      Pervasives.exit 0*)
    in
    
    { heartbeat_rate = Time.of_float 1.0 ; 
      install = install ;
      exit = exit }, transl_dncall
      
      
  let f debug alarm send_up = 
    let table = (Hashtbl.create 10 : 
      (int, (Iovecl.t, Iovecl.t) action ->unit) Hashtbl.t) in
    
    let get_handler id msg =
      try (Hashtbl.find table id) msg
      with Not_found -> 
	match msg with
	  | Control(Block _) ->
	      log (fun () -> "PROTOS:ignoring BlockOk for id not found in table (should not be a problem)")
	  |  _ ->
	       eprintf "PROTOS:id=%d ids=%s msg=%s\n"
		id (string_of_int_list (List.map fst (hashtbl_to_list table))) 
		(string_of_action msg) ;
	       failwith "unknown id"
    in
    
    let intf_s = init_intf_s () in
    
    let disable () = 
      intf_s.disabled <- true ;
      Hashtbl.iter (fun id handler ->
	handler (Control(Leave))
      ) table
    in

    let create_new id vs modes = 
      if Arrayf.length vs.view <> 1 then 
	failwith (sanityn 6) ;

      let exited () =
        (* Ensure that the link was in the table.
	*)
	if not (Hashtbl.mem table id) then
    	  failwith "exited:not found in table" ;
    	
        (* Then remove it.
	*)
    	Hashtbl.remove table id ;
	logc (fun () -> sprintf "removed id=%d #=%d" id (hashtbl_size table)) ;
      in
      
      (* Unset the protos bit. Create a new address
       * that is local to this process.
       *)
      let addr = Appl.addr modes in
      let vs = View.set vs [
	Vs_protos (Arrayf.singleton false) ;
	Vs_address (Arrayf.singleton addr)
      ] in
      
      let endpt = Arrayf.get vs.view 0 in
      let ls = View.local name endpt vs in
      let interface, transl_dncall = interface send_up exited id intf_s in
      let layer_state = Appl.config_new_hack interface (ls,vs) in
      
      
      (* Add the new stack to the the hash-table 
      *)
      if Hashtbl.mem table id then
	failwith "initialize:already in table" ;
      Hashtbl.add table id (function dncall -> 
	transl_dncall dncall;
	!(layer_state.Layer.handle_action) dncall;
      );
      logc (fun () -> sprintf "added id=%d #=%d" id (hashtbl_size table)) ;
      ()
	
    (* Dispatch the message to the handler corresponding
     * to the group context.  
     *)
    and recv_action id action = get_handler id action
    in

    (* Precompute part of the dncall_unmarsh function. This will make it take only 
     * three arguments in the normal case
    *)
    let recv = dncall_unmarsh create_new recv_action in
    (recv,disable,())
end
  
(**************************************************************)
  
let run () =
  (* Set the default pollcount value to 0.  This makes the
   * application somewhat more efficient.  
   *)
  Arge.set Arge.pollcount 0 ;
  let set_ident name v = v in
  let tcp_port = ref 5002 in

  Arge.parse [
    "-tcp_port", Arg.Int(fun i -> tcp_port:=i), "set daemon TCP channel"
  ] (Arge.badarg name) "Ensemble daemon";

  let alarm = Appl.alarm name in

  (* Force linking of the Udp mode.  This causes
   * a port number to be installed in the 
   * Unique generator.
   *)
  let _ = Domain.of_mode alarm Addr.Udp in

  let chan = Hsyssupp.server name alarm !tcp_port in
  chan (Server.f alarm) ;

  eprintf "ENSEMBLED:starting the Ensemble server\n";
  Appl.main_loop ()

(* Run the application, with exception handlers to catch any
 * problems that might occur.
 *)
let _ = Appl.exec ["ensembled"] run

(**************************************************************)

