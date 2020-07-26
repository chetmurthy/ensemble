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
(* HSYS.ML *)
(* Author: Mark Hayden, 5/95 *)
(**************************************************************)
let name = "HSYS"
let failwith s = failwith (name^":"^s)
(**************************************************************)

let fprintf ch fmt =
  let f s = 
    output_string ch s ;
    flush ch
  in
  Printe.f f fmt

let ident a = a
let sprintf fmt = Printe.f ident fmt
let eprintf fmt = fprintf stderr fmt

(**************************************************************)

type debug = string
type buf = string
type ofs = int
type len = int
type port = int
type socket = Socket.socket
type md5_ctx = Socket.md5_ctx

type inet = Unix.inet_addr
type send_info = Socket.send_info
type sendto_info = Socket.sendto_info
type sock_info = ((socket array) * (bool array)) option
type select_info = Socket.select_info
type recv_info = Socket.recv_info
type eth = Socket.eth
type eth_sendto_info = Socket.eth_sendto_info

type timeval = Socket.timeval = {
  mutable sec10 : int ;
  mutable usec : int
} 

type 'a refcnt = 'a Socket.refcnt = { mutable count : int ; obj : 'a } 
type 'a iovec = 'a Socket.iovec = { rbuf : 'a ; ofs : ofs ; len : len }

type handler =
  | Handler0 of (unit -> unit)
  | Handler1

type socket_option =
  | Nonblock of bool
  | Reuse
  | Join of inet
  | Leave of inet
  | Ttl of int 
  | Loopback of bool
  | Sendbuf of int
  | Recvbuf of int
  | Bsdcompat of bool

(**************************************************************)

(* Handler defaults to nothing.
 *)
let error_log = ref (fun _ -> ())

let log f = !error_log f

(**************************************************************)

let full_error = ref (fun _ -> "Unknown Exception")

let install_error f = full_error := f

let error e =
  match e with
  | Out_of_memory  -> "Out_of_memory";
  | Stack_overflow -> "Stack_overflow";
  | Not_found      -> "Not_found"
  | Failure s      -> sprintf "Failure(%s)" s
  | Sys_error s    -> sprintf "Sys_error(%s)" s
  | Unix.Unix_error(err,s1,s2) ->
      let msg = 
	try Unix.error_message err 
      	with _ -> "Unix(unknown error)"
      in
      let s1 = if s1 = "" then "" else ","^s1 in
      let s2 = if s2 = "" then "" else ","^s2 in
      sprintf "Unix(%s%s%s)" msg s1 s2
  | Invalid_argument s -> 
      raise e
  | _ ->
      !full_error e

let catch f a =
  try f a with e ->
    eprintf "gorp\n\n" ;
    eprintf "Uncaught exception: %s\n" (error e) ;
    exit 2

(**************************************************************)

let rec unix_wrap_again debug f =
  try f () with Unix.Unix_error(err,s1,s2) as exc ->
    match err with 
    | Unix.EINTR
    | Unix.EAGAIN ->
	log (fun () -> sprintf "warning:%s:%s" debug (error exc)) ;
	unix_wrap_again debug f
    | Unix.ECONNREFUSED 
    | Unix.ECONNRESET 
    | Unix.EHOSTDOWN			(* This was reported on SGI *)
    | Unix.ENETUNREACH
    | Unix.ENOENT
    | Unix.EPIPE ->
	log (fun () -> sprintf "warning:%s:%s" debug (error exc)) ;
	0
    | _ ->
	eprintf "HSYS:%s:%s\n" debug (error exc) ;
	flush stderr ;
	raise exc
	  
(**************************************************************)

let bind sock inet port = Unix.bind sock (Unix.ADDR_INET(inet,port))
let close sock		= Unix.close sock
let connect sock inet port = Unix.connect sock (Unix.ADDR_INET(inet,port))
let eth_init            = Socket.eth_init
let eth_recv            = Socket.eth_recv
let eth_sendto_info     = Socket.eth_sendto_info
let eth_sendtovs        = Socket.eth_sendtovs
let eth_to_bin_string   = Socket.eth_to_bin_string
let eth_of_bin_string   = Socket.eth_of_bin_string
let eth_supported       = Socket.eth_supported
let getlogin 		= Unix.getlogin
let getpid              = Unix.getpid
let gettimeofdaya 	= Socket.gettimeofday
let has_ip_multicast 	= Socket.has_ip_multicast
let inet_any () 	= Unix.inet_addr_any
let int_of_socket 	= Socket.int_of_socket
(*let int_of_substring	= Socket.int_of_substring*)
let listen sock i	= Unix.listen sock i
let max_msg_len () 	= 9*1024	(* suggested by Werner Vogels *)
(*let pop_nint 		= Socket.pop_nint*)
(*let push_nint 	= Socket.push_nint*)
let read                = Socket.read
let recv s b o l 	= unix_wrap_again "recv" (fun () -> Socket.recv s b o l)
let recv_info           = Socket.recv_info
let select      	= Socket.select
let poll        	= Socket.poll
let send_info s         = Socket.send_info s []
let send s b o l 	= unix_wrap_again "send" (fun () -> Socket.send s b o l)
let sendp s b o l 	= unix_wrap_again "sendp" (fun () -> Socket.sendp s b o l)
let sendv s i    	= unix_wrap_again "sendv" (fun () -> Socket.sendv s i)
let sendto_info s a 	= Socket.sendto_info s [] (Array.map (fun (i,p) -> Unix.ADDR_INET(i,p)) a)
let sendto 		= Socket.sendto
let sendtov             = Socket.sendtov
let sendtosv            = Socket.sendtosv
let sendtovs            = Socket.sendtovs
let set_error_log f     = error_log := f ; Socket.set_error_log f
let socket_dgram () 	= Unix.socket Unix.PF_INET Unix.SOCK_DGRAM 0
let socket_stream () 	= Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0
let static_string       = Socket.static_string
let static_string_free  = Socket.static_string_free
let stdin 		= Socket.stdin
let string_of_inet_nums = Unix.string_of_inet_addr
let substring_eq        = Socket.substring_eq
let udp_recv            = Socket.udp_recv
let md5_init            = Socket.md5_init
let md5_init_full       = Socket.md5_init_full
let md5_update          = Socket.md5_update
let md5_final           = Socket.md5_final

(**************************************************************)

let getenv key =
  try Some(Sys.getenv key)
  with Not_found -> None

(**************************************************************)

let empty = ([||],[||])
let sihelp = function
  | None -> empty
  | Some a -> a

let select_info a b c = Socket.select_info (sihelp a) (sihelp b) (sihelp c)

(**************************************************************)

let getsockname sock =
  match Unix.getsockname sock with
  | Unix.ADDR_INET(inet,port) -> (inet,port)
  | _ -> raise Not_found

(**************************************************************)

let getpeername sock =
  match Unix.getpeername sock with
  | Unix.ADDR_INET(inet,port) -> (inet,port)
  | _ -> raise Not_found

(**************************************************************)

let gethostname () =
  let name = Unix.gethostname () in
  String.lowercase name

(**************************************************************)

let gettimeofday () =
  let tv = { sec10 = 0 ; usec = 0 } in
  Socket.gettimeofday tv ;
  tv

(**************************************************************)
(* The Nonblock option uses the socket library because the
 * Ocaml Unix library implements setsocket non-blocking
 * operations as no-ops.
 *)

let setsockopt sock = function
  | Reuse       -> Unix.setsockopt sock Unix.SO_REUSEADDR true
  | Nonblock f  -> Socket.setsockopt_nonblock sock f
  | Join inet   -> Socket.setsockopt_join sock inet
  | Leave inet  -> Socket.setsockopt_leave sock inet
  | Ttl i       -> Socket.setsockopt_ttl sock i
  | Loopback onoff -> Socket.setsockopt_loop sock onoff
  | Sendbuf len -> Socket.setsockopt_sendbuf sock len
  | Recvbuf len -> Socket.setsockopt_recvbuf sock len
  | Bsdcompat b    -> Socket.setsockopt_bsdcompat sock b

(**************************************************************)

let recvfrom s b o l = 
  let l,sa = Unix.recvfrom s b o l [] in
  match sa with 
  | Unix.ADDR_INET(i,p) -> (l,i,p)
  | _ -> failwith "recv_from:non-ADDR_INET"

(**************************************************************)

(* This version is wrapped below with a caching version.
 *)
let inet_of_string inet =
  try 
    Unix.inet_addr_of_string inet
  with _ ->
    try
      let hostentry = Unix.gethostbyname inet in
      if Array.length hostentry.Unix.h_addr_list < 1 then (
      	eprintf "HSYS:inet_of_string: got empty list for host %s, raising Not_found\n" inet ;
	raise Not_found
      ) ;
      hostentry.Unix.h_addr_list.(0)
    with Not_found ->
      if inet = gethostname () then (
      	eprintf "HSYS:inet_of_string: host %s not found; defaulting to localhost\n" inet ;
      	Unix.inet_addr_of_string "127.0.0.1"
      ) else (
      	raise Not_found
      )

(**************************************************************)
(* Hashtable for caching gethostbyname results.
 * And an int ref for keeping track of the size.
 *)
let inet_table = (Hashtbl.create 10 : (string, (int * Unix.inet_addr option) ref) Hashtbl.t)
let inet_table_size = ref 0

(* Time constants used below.  We use the gettimeofday directly.
 *)
let timeout_good = 15 * 60             (* 15 minutes *)
let timeout_bad = 12 * 60 * 60         (* 12 hours *)
let timeout_init = -1                  (* hack *)

(**************************************************************)

let inet_of_string name = 
  (* Get the current time and use this to check for expired
   * entries.  
   *)
  let now = ((gettimeofday ()).sec10 * 10) + ((gettimeofday ()).usec / 1000000) in
  if now < 0 then 
    failwith "sanity:gettimeofday < 0" ;

  let memo = 
    try
      Hashtbl.find inet_table name
    with Not_found ->
      (* If not in table already, create an entry and add it
       * to the table.  If size ever goes above 1000 then
       * clear the table to prevent a space leak.  
       *)
      incr inet_table_size ;
      if !inet_table_size > 1000 then (
	eprintf "HSYS:gethostbyname:size > 1000, clearing cache" ;
	Hashtbl.clear inet_table ;
	inet_table_size := 1
      ) ;
      let memo = ref (timeout_init,None) in
      Hashtbl.add inet_table name memo ;
      memo
  in
  let expir,entryopt = !memo in

  (* If the expiration time is still ok, then just use the
   * cached entry.  
   *)
  if now < expir then (
    match entryopt with
    | None -> raise Not_found
    | Some entry -> entry
  ) else (
    (* Print a warning when about to do a gethostbyname to
     * a bad entry.  This is because we may end up
     * blocking the process.  
     *)
    if entryopt = None && expir <> timeout_init then (
      eprintf "HSYS:gethostbyname:warning:trying gethostbyname for previously bad entry (%s)\n" name ;
      flush stderr
    ) ;
    
    (* Calculate the new entry and override the previous value.
     *)
    try
      let entry = inet_of_string name in
      let expir = now + timeout_good in
      memo := (expir,(Some entry)) ;
      entry
    with Not_found ->
      let expir = now + timeout_bad in
      memo := (expir,None) ;
      raise Not_found
  )

(**************************************************************)

let gethost () =
  try
    inet_of_string (gethostname ())
  with _ ->
    failwith "HSYS:gethost:unable to get IP address for this host"

(**************************************************************)

let getlocalhost () =
  try
    inet_of_string "127.0.0.1"
  with _ ->
    failwith "HSYS:getlocalhost:unable to get localhost IP address"

(**************************************************************)

let accept sock =
  match Unix.accept sock with
  | (fd,Unix.ADDR_INET(inet,port)) -> (fd,inet,port)
  | _ -> failwith "accept:non-ADDR_INET"

(**************************************************************)

let deering_prefix = "239.255.0."

let deering_addr i =
  let i = (abs i) mod 248 in
  let inet_s = sprintf "%s%d" deering_prefix i in
  Unix.inet_addr_of_string inet_s

(**************************************************************)

let string_of_inet inet =
  try
    let {Unix.h_name=long_name} =
      Unix.gethostbyaddr inet 
    in
    let name = String.lowercase long_name in
    name
  with _ ->
    let inet_s = Unix.string_of_inet_addr inet in
    let ofs = String.length deering_prefix
    and len = String.length inet_s in
    if deering_prefix = String.sub inet_s 0 (min ofs len) then
      sprintf "IPM.%s" (String.sub inet_s ofs (len-ofs))
    else
      inet_s

let string_of_inet_short inet =
  let inet = string_of_inet inet in
  try
    let i = String.index inet '.' in
    String.sub inet 0 i
  with Not_found ->
    inet

(**************************************************************)

(* Ohad 
 *)
let inet_of_unix_inet_addr inet = inet
let unix_inet_addr_of_inet inet = inet

(* These simply returns the text readable value the
 * inet (XXX.YYY.ZZZ.TTT). Used for safe marshaling routines.
*)
let simple_string_of_inet inet = Unix.string_of_inet_addr inet
let simple_inet_of_string inet = Unix.inet_addr_of_string inet 

(**************************************************************)

let fork = Unix.fork

(**************************************************************)

(* Bind to any port.  This causes the kernel to select an
 * arbitrary open port to bind to.  We then call getsockname
 * to find out which port it was.  
 *)
let bind_any debug sock host =
  begin 
    try bind sock host 0 with _ ->
      try bind sock host 0 with _ ->
      	try bind sock host 0 with e ->
  	  eprintf "HSYS:error:binding socket to port 0 (tried 3 times):%s\n" (error e) ;
  	  eprintf "  (Note: this should not fail because binding to port 0 is\n" ;
  	  eprintf "   a request to bind to any available port.  However, on some\n" ;
  	  eprintf "   platforms (i.e., Linux) this occasionally fails and trying\n" ;
  	  eprintf "   again will often work)\n" ;
  	  exit 1
  end ;

  let port =
    try
      let (_,port) = getsockname sock in
      port
    with e ->
      eprintf "HSYS:error:getsockname:%s\n" (error e) ;
      exit 1
  in

  port

(**************************************************************)

let heap = Socket.heap
let addr_of_obj = Socket.addr_of_obj
let minor_words = Socket.minor_words
let frames = Socket.frames

(**************************************************************)

let read_ch ch =
  let l = ref [] in
  begin 
    try while true do
      let buf = String.create 10000 in
      let len = input ch buf 0 (String.length buf) in
      if len = 0 then 
      	raise End_of_file ;
      l := (String.sub buf 0 len) :: !l
    done with End_of_file -> () 
  end ;
  String.concat "" (List.rev !l)

let open_process cmd env input =
  let ((in_read,out_write,in_err) as handle) = 
    Unix.open_process_full cmd env in
  output_string out_write input ; 
  close_out out_write ;

  let output = read_ch in_read in
  let error = read_ch in_err in
  close_in in_read ;
  close_in in_err ;

  let stat = Unix.close_process_full handle in
  let stat = stat = Unix.WEXITED(0) in
  (stat,output,error)


let background_process cmd env input =
  let ((in_read,out_write,in_err) as handle) = 
    Unix.open_process_full cmd env in
  output_string out_write input ; 
  close_out out_write ;
      
  (* sockets to listen for replies on.
   *)
  (handle,
   Unix.descr_of_in_channel in_read, 
   Unix.descr_of_in_channel in_err)

(**************************************************************)
