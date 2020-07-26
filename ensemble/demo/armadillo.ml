(**************************************************************)
(*
 *  Ensemble, (Version 0.70p1)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
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
    
(**************************************************************)
let limit    = ref 100
let real_pgp = ref false
let net      = ref false
let pa       = ref false
let nmembers = ref 5
let prog     = ref "armadilo"
let group    = ref "pref"
let times    = ref 1000
let time_limit = ref (Time.of_int 20)
let tests_doc = Hashtbl.create 10
let scale    = ref false
let htb_rate = ref 3
let debug    = ref false
let opt_rekey = ref false

(* Sum the parameters so as to check if everyone has the same
 *)
let sum_params () = 
  sprintf "limit=%d, real_pgp=%b, net=%b, pa=%b, nmembers=%d, prog=%s, group=%s" !limit !real_pgp !net !pa !nmembers !prog !group

(* [perf_default pname param opt] create an initial view_state with the 
 * principal name [pname] parameters [param] and with the optimized rekeying 
 * layers or not [opt].
*)
let perf_default principal_name param opt= 
  let default () = 
    let props = match param with 
      | None -> 
	  let layers = [
	    Property.Gmp ;
   	    Property.Sync ; 
   	    Property.Heal ; 
   	    Property.Migrate ; 
   	    Property.Frag ; 
   	    Property.Suspect ; 
   	    Property.Flow ; 
   	    Property.Slander ;
   	    Property.Auth ;
	    Property.Privacy
	  ] in
	  if !debug then Property.Debug :: layers
	  else layers
      |	Some props -> props
    in
    let props = if opt then Property.OptRekey :: props else Property.Rekey :: props in
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
let policy me (e,a) = 
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
	]) false
    else
      let (ls,vs) = perf_default principal None false in
      let key = Prng.create () in
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
    let log = Trace.log2 name (Endpt.string_of_id ls.endpt) in
    let next = (succ ls.rank) mod ls.nmembers 
    and pre = (pred (ls.rank + ls.nmembers)) mod ls.nmembers 
    and first_time = ref true 
    and init_time = ref Time.zero
    and count = ref 0 in

    let measure () = 
      incr count;
      if ls.am_coord then eprintf "Done %d rounds\n" !count;
    in

    let receive origin bk cs m = match cs with
      | C -> 
	  if origin = m then (
	    log (fun () -> sprintf "%d OK, got message %d from <pre=%d>" ls.rank pre pre);
	    [||]
	  ) else
	    failwith "Got bad message"
      | S -> 
	  measure ();
	  if origin=pre 
	     && m = pre then (
	       log (fun () -> sprintf "%d OK, got message %d from <pre=%d>" ls.rank pre pre);
	       [| Send([|next|],ls.rank); (Cast ls.rank) |]
	     ) else 
	       failwith "Got bad message"
		 
    and heartbeat t = 
      if ls.nmembers > 1 
	&& !first_time 
	&& ls.am_coord then (
	    first_time := false ;
	  [| Send([|next|],ls.rank) |] 
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
	Property.Privacy
	]) false
  in
  let vs = View.set vs [Vs_key (Security.Common (Buf.pad_string "0123456701234567"))] in
  Appl.config_new interface (ls,vs)

(**************************************************************)
(* Rekey test 
 *)

let _ = Hashtbl.add tests_doc "rekey" "rekeying multiple times"
let _ = Hashtbl.add tests_doc "prompt" "changing views using the Prompt action"

let create_stack_rekey opt prompt i = 
  let action = 
    if prompt then Prompt
    else Rekey true
  in
  let (ls,vs) = perf_default ("o"^(string_of_int i)) None opt in 
  let alarm = Elink.alarm_get_hack () in
  
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
      eprintf "[%d] view=%d %b %f key=%s.\n" 
	!num_view ls.nmembers (*(string_of_addrs vs.address) *)
	vs.new_key diff (Security.string_of_key vs.key);
      if ls.nmembers = !nmembers then incr num_view;
      first_time := true;
      rekeying := false;
      time := time2;
      if !num_view = !limit then 
	[|Cast Done; Control Leave|]
      else
	[||]
    ) else 
      [||]
  in
  eprintf "RUN\n";
  let interface = create_intf htb (float_of_int !htb_rate) viewfun in
  let vs = View.set vs [Vs_key (Prng.create ())] in
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
	ls.nmembers (*(string_of_addrs vs.address)*) 
	(string_of_list Endpt.string_of_id (Arrayf.to_list vs.view))
	(Security.string_of_key vs.key);
    [||]
  in 
  let interface = create_intf htb 10.0 viewfun in
  let (ls,vs) = perf_default ("o"^(string_of_int i)) None false in
  let vs = View.set vs [Vs_key (Prng.create ())] in
  Appl.config_new interface (ls,vs)
    
(**************************************************************)
let _ = Hashtbl.add tests_doc "reg" "Use a regular stack"

let create_stack_reg i = 
  let htb (ls,vs) = [||]
  and viewfun (ls,vs) = 
    if ls.am_coord then
      eprintf "addresses=%s\n" (string_of_addrs vs.address);
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
  ])  false in
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
(* PGP test
 *)

let _ = Hashtbl.add tests_doc "pgp" "Test the pgp interface"


let pgp () = 
  let principal_name = "Tim Clark" in
  let pgp = Addr.PgpA(principal_name) in
  let pgp = Arrayf.singleton pgp in
  let addr = Addr.set_of_arrayf pgp in
  let original = (Buf.pad_string "0123456701234567") in
  
  let check_background () = 
    let alarm = Elink.alarm_get_hack () in
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
		exit 0
	      )
	  )
    ) 
  and check_foreground () = 
    let cipher = Auth.ticket addr addr original in
    begin match cipher with 
      | None -> failwith "could not encrypt"
      | Some cipher -> 
	  let clear  = Auth.check addr addr cipher in
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
      check_foreground () ;
      printf "check_background\n";
      check_background () ;
      
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
(* Performance test for RC4
 *)
let _ = Hashtbl.add tests_doc "perf" "performace and simple test of the crypto library."
	  
let perf () = 
  log (fun () -> "Cipher.lookup RC4");
  let shared = Cipher.lookup "RC4" in
  let key = Security.Common (Buf.pad_string "0123456701234567") in
  let len = 100  in
  let buf0 = String.create len in
  let buf = Buf.of_string name (String.copy buf0) in 
  let len = Buf.len_of_int len in
  
  eprintf "Testing Encrypt sanity.\n";
  for i=1 to 10 do
    let context = Cipher.init shared (Common(Buf.pad_string "0123456701234567")) true in
    let res = Cipher.encrypt shared context buf Buf.len0 len in
    let context = Cipher.init shared (Common(Buf.pad_string "0123456701234567")) true in
    let res = Cipher.encrypt shared context res Buf.len0 len in
    if res <> buf then
      failwith ("Bad encryption " ^ (Buf.to_string res) ^ " <> " ^ 
      (Buf.to_string buf))
  done;
  eprintf "OK.\n";

  eprintf "Testing Encrypt_inplace sanity.\n";
  for i=1 to 10 do
    let context = Cipher.init shared key true in
    Cipher.encrypt_inplace shared context buf Buf.len0 len;
    let context = Cipher.init shared key true in
    Cipher.encrypt_inplace shared context buf Buf.len0 len;
    if  buf <> (Buf.of_string name buf0) then
      failwith ("Bad encryption " ^ (Buf.to_string buf) ^ " <> " ^ buf0)
  done;
  eprintf "OK.\n";

  eprintf "Testing PRNG, creating random keys.\n";
  for i=1 to 10 do
    let s = Prng.create () in 
    let s = Security.str_of_key s in
    printf "\t";
    for j=0 to (String.length s -1) do
      printf "%d " (Char.code (s.[j]));
    done;
    printf "\n" 
  done;

  eprintf "Testing encryption performance.\n";
  let time0 = Time.gettimeofday () in
  let len = 1000  in
  let buf = Buf.of_string name (String.create len ) in 
  let len = Buf.len_of_int len in
  for i=1 to !times do
    let context = Cipher.init shared key true in
    Cipher.encrypt_inplace shared context buf Buf.len0 len;
  done;
  let time1 = Time.gettimeofday () in
  let diff = Time.sub time1 time0 in
  let diff = Time.to_string diff in
  printf "time for encryption (%d * %d) bytes = %s\n" !times (Buf.int_of_len len)
    diff;
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
    Property.Privacy ;
    Property.Debug 
  ]) false in  
  let vs = View.set vs [Vs_key (Prng.create ())] in
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
    "-limit",Arg.Int(fun i -> limit:=i), "number of views to run";
    "-terminate_time",Arg.Float(fun x -> time_limit:= Time.of_float x), "Time to run";
    "-times",Arg.Int(fun i -> times:=i), "encrypt rounds";
    "-scale", Arg.Set(scale), "scaleable protocols" ;
    "-htb_rate", Arg.Int(fun i -> htb_rate := i), "heartbeart rate" ;
    "-debug", Arg.Set(debug), "debugging layers" ;
    "-opt", Arg.Set(opt_rekey), "optimized rekey stack" ;
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
  

  (* Exchange_stack will not work properly if n>100
   *)
  if (!nmembers > 100) then
    failwith "Too many members";
  
  if !pa then 
    printf "Using partitions\n";
  if not !net && not !real_pgp then (
    Arge.set short_names true; 
    Arge.set alarm "Netsim" ;
    Arge.set modes [Addr.Netsim]
  );
  if !prog <> "perf" && !prog <> "pgp" then (
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
	  create_stack_rekey false true
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
      | _ -> failwith "unknown security test"
  );
  
  log (fun () -> "2");
  Appl.main_loop ()
    
let _ = Appl.exec ["armadillo"] run
(**************************************************************)
	  
	  
	  
	  
	  
	  
	  
	  
