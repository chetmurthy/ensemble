(**************************************************************)
(* ARMADILLO.ML: Ensemble Security properties test *)
(* Author: Ohad Rodeh, 7/98 *)
(**************************************************************)
open Ensemble
open Trans
open Hsys
open Util
open View
open Appl_intf open New

open Arge 
open Security
open Shared  
(**************************************************************)
let name = Trace.file "ARMADILLO"
let failwith s = Trace.make_failwith name s
let log = Trace.log name
let log1 = Trace.log (name^"1")
let logk = Trace.log (name^"K")
(**************************************************************)
	    
type msg = 
  | Params of string
  | Done
      
let string_of_addrs addrs = 
  let addrs = Arrayf.to_array addrs in
  let addrs = Array.map (function set -> Addr.project set Addr.Pgp) addrs in
  let addrs = Array.map Addr.string_of_addr addrs in
  string_of_array ident addrs

(*    
let string_of_addrs addrs = 
  let addrs = Arrayf.to_array addrs in
  let addrs = 
    (*Array.map (function set -> Addr.project set Addr.Udp) addrs *)
    Array.map (function set -> Addr.project set Addr.Deering) addrs 
  in
  let addrs = Array.map (function 
    | Addr.DeeringA (inet,p) -> 
	let s = Hsys.string_of_inet inet in
	let i = String.index s '.' in
	String.sub s 0 i 
    | Addr.UdpA (inet,p) -> 
	let s = Hsys.string_of_inet inet in
	let i = String.index s '.' in
	String.sub s 0 i 
    | _ -> failwith "Sanity"
  ) addrs in
  (* Sort.array (<=) addrs;*)
  string_of_array ident addrs
    (*"[||]"*)
*)
(**************************************************************)
let real_pgp      = ref false
let net           = ref false
let pa            = ref false
let nmembers      = ref 5
let prog          = ref "rekey"
let group         = ref "pref"
let times         = ref 1000
let time_limit    = ref (Time.of_int 20)
let tests_doc     = Hashtbl.create 10
let scale         = ref false
let htb_rate      = ref 3
let debug         = ref false
let opt_rekey     = ref ""
let num_enc_loops = ref 1000
let init_key      = ref None
(**************************************************************)

(* Create an initial key, if one has not been inserted by hand. 
*)
let create_init_key () = 
  match !init_key with
    | None -> Prng.create_key () 
    | Some k -> 
	if String.length k >= 32 then 
	  Security.key_of_buf (Buf.of_string k)
	else failwith "Manual Key is not of the correct size (32)"

(* Sum the parameters so as to check if everyone has the same
 *)
let sum_params () = 
  sprintf "real_pgp=%b, net=%b, pa=%b, nmembers=%d, prog=%s, group=%s" !real_pgp !net !pa !nmembers !prog !group

(* [perf_default pname param opt] create an initial view_state with the 
 * principal name [pname] parameters [param] and with the optimized rekeying 
 * layers or not [opt].
*)
let perf_default principal_name param opt = 
  let default () = 
    let props = match param with 
      | None -> [
	    Property.Gmp ;
   	    Property.Sync ; 
   	    Property.Heal ; 
   	    Property.Migrate ; 
   	    Property.Frag ; 
   	    Property.Suspect ; 
   	    Property.Flow ; 
   	    Property.Slander ;
   	    Property.Auth ;
(*	    Property.Privacy*)
	  ] 
      |	Some props -> props
    in
    let props = 
      if !debug then Property.Debug :: props
      else props
    in
    let props = 
      match opt with 
	| "none" -> 
	    props
	| _ -> 
	    Property.Rekey :: props in
    let props = if !scale then Property.Scale :: props else props in
    let (ls,vs) = Appl.default_info !group in 
    let vs = 
      match !pa,!real_pgp with 
      |	false,false -> 
	  let proto = Property.choose props in
	  View.set vs [Vs_params [
	    "sec_sim", (Param.Bool true);
	  ];
	  Vs_proto_id proto
	  ] 
      |	true,false -> 
	  let props = Property.Drop :: props in
	  let proto = Property.choose props in
	  View.set vs [Vs_params [
	    "drop_partition", (Param.Bool true);
	    "drop_rate",      (Param.Float 0.0);
	    "suspect_max_idle", (Param.Int 3) ;
	    "merge_sweep", (Param.Time (Time.of_int 5));
	    "sec_sim", (Param.Bool true);
	  ];
	  Vs_proto_id proto;
	  ] 
      |	false,true -> 
	  let proto = Property.choose props in
	  View.set vs [Vs_proto_id proto] 
      |	true,true -> 
	  let props =  Property.Drop :: props in
	  let proto = Property.choose props in
	  View.set vs [Vs_params [
	    "drop_partition", (Param.Bool true);
	    "drop_rate",      (Param.Float 0.0);
	    "suspect_max_idle", (Param.Int 5) ;
	    "merge_sweep", (Param.Time (Time.of_int 5));
	  ];
	  Vs_proto_id proto;
	  ] 
    in 
    (ls,vs)
  in
  let (ls,vs) = default () in
  let reg = Addr.arrayf_of_set (Arrayf.get vs.address 0) in
  let pgp = Addr.PgpA(principal_name) in
  let pgp = Arrayf.singleton pgp in
  let addr = Arrayf.append reg pgp in
  let addr = Addr.set_of_arrayf addr in
  let addr = Arrayf.singleton addr in
  let vs = View.set vs [Vs_address addr] in
  let ls = View.local name ls.endpt vs in
  (ls,vs)
  
let create_intf htb rate viewfun = 
  let first_time = ref true in
  let sump = sum_params () in
  let time_limit = ref !time_limit in
  let install (ls,vs) =
    let log = Trace.log2 name (Endpt.string_of_id ls.endpt) in
    
    let receive origin bk cs m = 
      if cs=C then match m with 
      |	Params p -> 
	  if p <> sump then (
	    eprintf "Joining a member with bad parameters, Leaving\n";
	    [|Control Leave|]
	  ) else
	    [||]
      |	Done ->	[|Control Leave|]
      else
	failwith "Bad message"
    and heartbeat t = 
      if !first_time then (
	time_limit := Time.add t !time_limit ;
	log (fun () -> sprintf "base_time=%f" (Time.to_float !time_limit));
	first_time := false ;
	htb (ls,vs)
      ) else (
	if Time.ge t !time_limit then (
	  eprintf "time's up now=%f time_limit=%f\n" 
	  (Time.to_float t) (Time.to_float !time_limit);
	  exit 0 
	) else htb (ls,vs)
      )
    and block () = [||]	in
    
    let handlers = {
      flow_block = (fun _ -> ());
      receive = receive ;
      block = block ;
      heartbeat = heartbeat ;
      disable = Util.ident
    } in
    let msgs = viewfun (ls,vs) in
    if ls.rank = 0 then 
      (Array.append msgs [|Cast (Params sump)|]),handlers
    else
      msgs, handlers
	
    and exit () = 
      log (fun () -> "Exit"); 
      exit 0
	
    in full { 
  	heartbeat_rate      = Time.of_float rate ;
  	install             = install ;
  	exit                = exit 
      }
	 
(**************************************************************)
(* Policy test
 *)
let counter = ref 0
let policy me a = 
  let addr = Addr.arrayf_of_set a in
  let addr = Arrayf.to_list addr in
  let result = 
    incr counter;
    List.exists (function
    | Addr.PgpA x -> 
	let num = String.sub x 1 (String.length x -1) in
	let num = int_of_string num in
	(me - num) mod (1 + (!counter/200 mod 4)) = 0
    | _ -> false
    ) addr in
  logk (fun () -> sprintf "policy %d %s %b" me (Addr.string_of_set a) 
      result);
  result
    
    
let _ = Hashtbl.add tests_doc "policy" "Testing polices authenticated stack"
let _ = Hashtbl.add tests_doc "policy_reg" "Testing polices for the regular stack"
    
let create_stack_policy prompt i = 
  let action = 
    if prompt then Prompt
    else Rekey false
  in
  let first_time = ref true 
  and rekeying = ref false in
  
  let htb (ls,vs) = 
    if ls.am_coord then (
      log (fun () -> sprintf "heartbeat first_time=%b" !first_time);
      if !first_time then (
	first_time := false;
	[||]
      ) else 
	if not !rekeying then (
	  log (fun () -> "Rekey");
	  rekeying := true;
	  [|Control action|] 
	) else
	  [||] 
    ) else [||]
      
  and viewfun (ls,vs) = 
    if ls.rank=vs.coord then (
      printf "Addresses=%s\n" (string_of_addrs vs.address);
      first_time := true;
      rekeying := false
    );
    [||]
  in
  let interface = create_intf htb 10.0 viewfun in
  let principal = "o"^(string_of_int i) in
  let (ls,vs) = 
    if prompt then
      perf_default principal (Some
	[Property.Gmp ;
   	Property.Sync ; 
   	Property.Heal ; 
   	Property.Migrate ; 
   	Property.Frag ; 
   	Property.Suspect ; 
   	Property.Flow ; 
   	Property.Slander 
	]) ""
    else
      let (ls,vs) = perf_default principal None "" in
      let key = create_init_key () in
      let vs = View.set vs [Vs_key key] in
      (ls,vs)
  in
  let state = Layer.new_state interface in
  let state = Layer.set_exchange (Some (policy i)) state in 
  Appl.config_new_full state (ls,vs)
    
(**************************************************************)
let _ = Hashtbl.add tests_doc "encrypt_sanity" "Testing the sanity of the Encrypt layer"

let create_stack_encrypt_sanity i = 

  let install (ls,vs) =
    eprintf "view (nmembers=%d)\n" ls.nmembers;
    let log = Trace.log2 name (Endpt.string_of_id ls.endpt) in
    let next = (succ ls.rank) mod ls.nmembers 
    and pre = (pred (ls.rank + ls.nmembers)) mod ls.nmembers 
    and first_time = ref true 
    and init_time = ref Time.zero
    and count = ref 0 in
    let rounds = !times in

    let measure () = 
      incr count;
      if ls.am_coord 
	&& !count mod 10 = 0 then eprintf ".";
      if !count = rounds then (
	eprintf "\nSanity test for encryption layer completed. %d successful communication rounds.\n" rounds;
	exit 0
      )
    in

    let receive origin bk cs m = match cs with
      | C -> 
	  measure ();
	  if origin = m then 
	    if ls.rank = 0 then (
	      log (fun () -> sprintf "%d OK, got message %d from <pre=%d>" ls.rank pre pre);
	      [|Cast ls.rank|]
	    ) else 
	      [||]
	  else
	    failwith "Got bad message"
      | S -> 
	  measure ();
	  if origin=pre 
	     && m = pre then (
	       log (fun () -> sprintf "%d OK, got a message %d from <pre=%d>" ls.rank pre pre);
	       [| Send1(next, ls.rank)|]
	     ) else 
	       failwith "Got bad message"
		 
    and heartbeat t = 
      if ls.nmembers > 1 
	&& !first_time 
	&& ls.am_coord then (
	    first_time := false ;
	  [| Send1(next,ls.rank); Cast(ls.rank)|]   
	) else
	  [||]
	    
    and block () = [||]	in
    let handlers = {
      flow_block = (fun _ -> ());
      receive = receive ;
      block = block ;
      heartbeat = heartbeat ;
      disable = Util.ident
    } in
    [||],handlers
    in
    let exit () = 
      log (fun () -> "Exit"); 
      exit 0
    in 
    let interface = full { 
      heartbeat_rate      = Time.of_float 1.0;
      install             = install ;
      exit                = exit 
    } in

  let (ls,vs) = 
      perf_default ("o"^(string_of_int i)) (Some
	[Property.Gmp ;
   	Property.Sync ; 
   	Property.Heal ; 
   	Property.Migrate ; 
   	Property.Frag ; 
   	Property.Suspect ; 
   	Property.Flow ; 
   	Property.Slander ;
(*	Property.Privacy ;*)
	Property.Auth 
	]) ""
  in
  let vs = View.set vs [Vs_key (Security.key_of_buf (Buf.of_string "01234567012345670123456701234567"))] in
  Appl.config_new interface (ls,vs)

(**************************************************************)
(* Rekey test 
 *)

let _ = Hashtbl.add tests_doc "rekey" "rekeying multiple times"
let _ = Hashtbl.add tests_doc "prompt" "changing views using the Prompt action"

let create_stack_rekey opt prompt i = 
  let action = 
    if prompt then Prompt
    else Rekey false
  in
  let (ls,vs) = perf_default ("o"^(string_of_int i)) None opt in 
  let alarm = Appl.alarm  "armadillo" in
  
  let num_view = ref 0 in
  let first_time = ref true 
  and rekeying = ref false 
  and time = ref 0.0 in
  
  let htb (ls,vs) = 
    if ls.am_coord && ls.nmembers = !nmembers then (
      log (fun () -> sprintf "heartbeat first_time=%b" !first_time);
      if !first_time then (
	first_time := false;
	[||]
      ) else 
	if not !rekeying then (
	  log (fun () -> "Rekey");
	  rekeying := true;
	  time := Time.to_float (Alarm.gettime alarm);
	  [|Control action|]  
	) else
	  [||] 
    ) else [||]
  and viewfun (ls,vs) = 
    if ls.am_coord && ls.nmembers = !nmembers then (
      let time2 = Time.to_float (Alarm.gettime alarm) in
      let diff = time2 -. !time in
      eprintf "[%d] view=%d %f key=%s.\n" 
	!num_view ls.nmembers (*(string_of_addrs vs.address) *)
	diff (Security.string_of_key vs.key);
      if ls.nmembers = !nmembers then incr num_view;
      first_time := true;
      rekeying := false;
      time := time2;
    );
    [||]
  in
  eprintf "RUN\n";
  let interface = create_intf htb (float_of_int !htb_rate) viewfun in
  let vs = View.set vs [Vs_key (create_init_key ())] in
  Appl.config_new interface (ls,vs)
    
(**************************************************************)
(* Exchange test
 *)

let _ = Hashtbl.add tests_doc "exchange" "Checking that partitions merge in the authenticated stack"

let create_stack_exchange i = 
  let htb (ls,vs) = [||]
  and viewfun (ls,vs) = 
    if ls.am_coord then
      eprintf "nmembers=%d view=%s key=%s.\n" 
	ls.nmembers 
	(string_of_addrs vs.address)
	(*(string_of_list Endpt.string_of_id (Arrayf.to_list vs.view))*)
	(Security.string_of_key vs.key);
    [||]
  in 
  let interface = create_intf htb 10.0 viewfun in
  let (ls,vs) = perf_default ("o"^(string_of_int i)) (Some
	[Property.Gmp ;
   	Property.Sync ; 
   	Property.Heal ; 
   	Property.Migrate ; 
   	Property.Frag ; 
   	Property.Suspect ; 
   	Property.Flow ; 
   	Property.Slander ;
	Property.Auth
	]) "" in
  let vs = View.set vs [Vs_key (create_init_key ())] in
  Appl.config_new interface (ls,vs)
    
(**************************************************************)
let _ = Hashtbl.add tests_doc "reg" "Use a regular stack"

let create_stack_reg i = 
  let first_time = ref true 
  and rekeying = ref false in
  
  let htb (ls,vs) = 
    if ls.am_coord then eprintf "nmembers=%d\n" ls.nmembers;
    if ls.am_coord && ls.nmembers = !nmembers then (
      log (fun () -> sprintf "heartbeat first_time=%b" !first_time);
      if !first_time then (
	first_time := false;
	[||]
      ) else 
	if not !rekeying then (
	  log (fun () -> "Rekey");
	  rekeying := true;
	  [|Control Prompt|]  
	) else
	  [||] 
    ) else [||]
  and viewfun (ls,vs) = 
    if ls.am_coord && ls.nmembers = !nmembers then (
      eprintf "view=%d\n" ls.nmembers;
      first_time := true;
      rekeying := false;
    );
    [||]
  in
  eprintf "RUN\n";
  let interface = create_intf htb 10.0 viewfun in
  let (ls,vs) = perf_default ("o"^(string_of_int i)) (Some [
    Property.Gmp ;
    Property.Sync ; 
    Property.Heal ; 
    Property.Migrate ; 
    Property.Frag ; 
    Property.Suspect ; 
    Property.Flow ; 
    Property.Slander ;
  ])  "none" in
  Appl.config_new interface (ls,vs)
    


(**************************************************************)
(* This stack kills all the processes in the group
 *)
let _ = Hashtbl.add tests_doc "quit" "kills this group"

let create_stack_quit _ = 
  let htb (ls,vs) = [||]
  and viewfun (ls,vs) = 
    eprintf "View n=%d" ls.nmembers;
    if ls.nmembers = succ !nmembers then 
      [|Cast Done; Control Leave|]
    else
      [||]
  in
  let interface = create_intf htb 10.0 viewfun in
  let (ls,vs) = Appl.default_info "armadilo" in
  Appl.config_new interface (ls,vs)
    

(**************************************************************)
(* Generate a new key.
 *)

let _ = Hashtbl.add tests_doc "DH_key" "Create new Diffie-Hellman parameters key"

let dh_key () = 
  eprintf "Createing a new Diffie-Hellman key, size=\n" ;
  let s = read_line () in
  let len = int_of_string s in
  Shared.DH.generate_parameters_into_file len;
  ()

(**************************************************************)
(* PGP test
 *)

let _ = Hashtbl.add tests_doc "pgp" "Test the pgp interface"


let pgp () = 
  print_string "PGP test\n"; flush stdout;
  let principal_name = "o1" in
  let pgp = Addr.PgpA(principal_name) in
  let pgp = Arrayf.singleton pgp in
  let addr = Addr.set_of_arrayf pgp in
  let original = "0123456701234567" in

  (* Measure how long function f takes to complete.
     *)
  let measure () = 
    let time0 = Time.gettimeofday () in
    let alarm = Appl.alarm "armadillo" in
    let rec check i f = 
      if i<=0 then f ()
      else (
	Auth.bckgr_ticket false addr addr original alarm (function
	  | None -> failwith "could not background encrypt"
	  | Some ticket -> 
	      Auth.bckgr_check false addr addr ticket alarm (function
		| None -> failwith "could not background decrypt"
		| Some clear -> 
		    check (i-1) f
	      )
	) 
      )
    in
    let f () = 
      let time1 = Time.gettimeofday () in
      let diff = Time.sub time1 time0 in
      eprintf "Time for 10*sign + 10*verify with PGP= %s\n" 
	(Time.to_string diff); 
      exit 0;
      ()
    in
    check 10 f ;
    ()
    
  and check_background () = 
    let alarm = Appl.alarm "armadillo" in
    Auth.bckgr_ticket false addr addr original alarm (function
      | None -> failwith "could not background encrypt"
      | Some ticket -> 
	  eprintf "got a ticket\n" ;
	  Auth.bckgr_check false addr addr ticket alarm (function
	    | None -> failwith "could not background decrypt"
	    | Some clear -> if clear <> original then 
		failwith "background clear<>original"
	      else (
		printf "background PGP works\n" ;
	      )
	  )
    ) 
  and check_foreground () = 
    let cipher = Auth.ticket false addr addr original in
    begin match cipher with 
      | None -> failwith "could not encrypt"
      | Some cipher -> 
	  let clear  = Auth.check false addr addr cipher in
	  begin match clear with  
	    | None -> failwith "could not decrypt"
	    | Some clear -> 
		if clear <> original then failwith "clear<>original"
		else printf "PGP works\n"
	  end
    end
  in

  let intf () = 
    let install (ls,vs) = 
      (*check_foreground () ;*)
      printf "check_background\n";
      check_background () ;
      measure ();

      let handlers = {
	flow_block =  (fun _ -> ()) ;
	block      =  (fun () -> [||]) ;
	heartbeat  =  (fun _ -> [||]) ;
	receive    =  (fun _ _ _ _ -> [||]) ;
	disable    =  (fun _ -> ()) 
      } in
      [||], handlers
	
    in full {
	heartbeat_rate = Time.of_float 3.0 ;
	install = install ;
	exit  = (fun _ -> ())
      } 
  in       
  let (ls,vs) = Appl.default_info name in
  let i = intf () in 
  Appl.config_new i (ls,vs)

(**************************************************************)
(* Performance test for security library
 *)
let _ = Hashtbl.add tests_doc "perf" "performace and simple test of the crypto library."
	  
let perf () = 
  eprintf "Testing PRNG, creating random keys.\n";
  for i=1 to 10 do
    let s = Prng.create_key () in 
    let s = Buf.string_of (Security.buf_of_key s) in
    printf "\t";
    for j=0 to (String.length s -1) do
      printf "%d " (Char.code (s.[j]));
    done;
    printf "\n" 
  done;

  eprintf "**************************************\n";
  eprintf "<RC4>\n";
  Shared.Cipher.sanity_check "OpenSSL/RC4"  !num_enc_loops 1000;
  eprintf "**************************************\n";
  eprintf "<Diffie-Hellman>\n";
  Shared.DH.sanity_check "OpenSSL/DH" !num_enc_loops 1024;
  eprintf "**************************************\n";
  ()
    
(**************************************************************)
(* Encrypt test
 *)

let _ = Hashtbl.add tests_doc "debug" "Testing the soundness of the security layers"

let create_stack_debug i = 
  let htb (ls,vs) = [||]
  and viewfun (ls,vs) = 
    eprintf "my_rank=%d nmembers=%d %s\n" ls.rank ls.nmembers (string_of_addrs vs.address);
    [||]
  in 
  let interface = create_intf htb 10.0 viewfun in
  let (ls,vs) = perf_default ("o"^(string_of_int i)) (Some [
    Property.Gmp ;
    Property.Sync ; 
    Property.Heal ; 
    Property.Migrate ; 
    Property.Frag ; 
    Property.Suspect ; 
    Property.Flow ; 
    Property.Slander ;
    Property.Auth ;
    Property.Rekey ;
(*    Property.Privacy ;*)
    Property.Debug 
  ]) "" in  
  let vs = View.set vs [Vs_key (create_init_key ())] in
  Appl.config_new interface (ls,vs)


(**************************************************************)

let run ()  = 
  
  let t_docs = 
    let s = ref "" in
    Hashtbl.iter (fun tname doc -> 
      let len = String.length tname in
      let pad = String.make (16-len) ' ' in
      s := !s ^"\n"^ "\t"^tname^pad^doc ) 
      tests_doc;
    !s
  in

  Arge.parse [
    "-n",Arg.Int(fun i -> nmembers:=i), "nmembers";
    "-prog",Arg.String(fun s -> prog:=s), "which security test?";
    "-pa",Arg.Set(pa),"partitions";
    "-net",Arg.Set(net),"use the real network";
    "-real_pgp",Arg.Set(real_pgp),"use pgp or simulate it";
    "-group",Arg.String(fun s -> group:=s),"set group name";
    "-terminate_time",Arg.Float(fun x -> time_limit:= Time.of_float x), "Time to run";
    "-times",Arg.Int(fun i -> times:=i), "encrypt rounds";
    "-scale", Arg.Set(scale), "scaleable protocols" ;
    "-htb_rate", Arg.Int(fun i -> htb_rate := i), "heartbeart rate" ;
    "-debug", Arg.Set(debug), "debugging layers" ;
    "-opt", Arg.Unit(fun () -> opt_rekey := "opt"), "optimized rekey stack" ;
    "-key", Arg.String(fun s -> init_key:=Some s), "Optional key, inserted by hand";
    "-num_enc_loops", Arg.Int(fun i -> num_enc_loops:=i), "Number of encryption loops";
    "-help",Arg.Unit(fun () -> print_string (
      "-n          nmembers\n" ^
      "-terminate_time   Time to run\n" ^
      "-prog       which security test?" ^ t_docs ^ "\n" ^
      "-pa         partitions\n" ^ 
      "-net        network version\n" ^ 
      "-real_pgp   use pgp or simulate it\n" ^ 
      "-limit      number of views to run\n" ^
      "-group      set group name\n" ^
      "-times      encrypt rounds\n" ^ 
      "-htb_rate   heartbeart rate\n" ^
      "-debug      debugging layers\n" ^
      "-opt        optimized rekey stack\n"
    ); exit 0), "help"
  ] (Arge.badarg name) "armadilo";
  

  (* Install handler to get input from stdin.
   * This obscure function allows killing the process using 
   * Unix.close_process commands
   *)
  let stdin = Hsys.stdin () in
  let get_input () =
    let buf = String.create 1 in
    let len = Hsys.read stdin buf 0 1 in
    if len = 0 then (
      exit 0
    ) else ()
  in
  Alarm.add_sock_recv (Appl.alarm name) name stdin (Hsys.Handler0 get_input) ;


  (* Exchange_stack will not work properly if n>100
   *)
  if (!nmembers > 100) then
    failwith "Too many members";
  
  if !prog = "pgp" then real_pgp := true;
  if !pa then 
    printf "Using partitions\n";
  if not !net && not !real_pgp then (
    Arge.set short_names true; 
    Arge.set alarm "Netsim" ;
    Arge.set modes [Addr.Netsim]
  );
  if !prog <> "perf" && !prog <> "pgp" && !prog <> "DH_key" then (
    let f = match !prog with
      | "policy" -> 
	  create_stack_policy false
      | "policy_reg" -> 
	  create_stack_policy true
      | "rekey" -> 
	  create_stack_rekey !opt_rekey false 
      | "exchange" -> 
	  create_stack_exchange
      | "reg" -> 
	  create_stack_reg
      | "prompt" -> 
	  create_stack_rekey "" true
      | "quit" -> 
	  create_stack_quit
      | "encrypt_sanity" -> 
	  create_stack_encrypt_sanity
      | "debug" -> 
	  create_stack_debug
      |  _ -> failwith "unknown security test"
    in

    if !net then 
      f 1
    else
      for i=1 to !nmembers do
	f i ;
      done
  ) else (
    match !prog with 
      | "perf" -> 
	  perf ();
	  exit 0
      | "pgp" -> 
	  pgp ()
      | "DH_key" -> 
	  dh_key ();
	  exit 0
      | _ -> failwith "unknown security test"
  );
  
  Appl.main_loop ()
    
let _ = Appl.exec ["armadillo"] run
(**************************************************************)
	  
	  
	  
	  
	  
	  
	  
	  
