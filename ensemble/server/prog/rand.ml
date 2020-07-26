(**************************************************************)
(* RAND.ML: Randomly multicast/send messages and fail *)
(* Author: Mark Hayden, 6/95 *)
(**************************************************************)
open Ensemble
open Trans
open Util
open Arge
open View
open Buf
open Appl_intf open New
(**************************************************************)
let name = Trace.file "RAND"
let failwith s = Trace.make_failwith name s
let log = Trace.log name
(**************************************************************)
let size = ref 100
let max_time = ref Time.zero

type program = With_iov | No_iov

type state = {
  mutable max_ltime     : ltime ;
  mutable next_action 	: Time.t ;
  mutable last_view	: Time.t
}
    
(**************************************************************)
    
let dump (ls,vs) s =
  eprintf "RAND:dump:%s\n" ls.name ;
  eprintf "  last_view=%s\n" (Time.to_string s.last_view) ;
  eprintf "  rank=%d, nmembers=%d\n" ls.rank ls.nmembers
    
(**************************************************************)
    (* A test that uses only meta-data and sends no iovectors. 
     *)
module NO_IOV = struct
  type action = | ALeave | ASuspect | ANone
      
  let string_of_action = function
    | ALeave -> "ALeave"
    | ASuspect-> "ASuspect"
    | ANone -> "ANone"
        
  let policy my_rank nmembers thresh =
    let next = Random.int 10000000 * nmembers in
    let p = Random.int 100 in
    let action =
      if nmembers >= thresh then (
        if p*nmembers < 10 then ALeave
        else if p*nmembers < 20 then ASuspect
        else ANone
      ) else 
        ANone
    in 
    log (fun () -> string_of_action action);
    (action,(Time.of_ints 0 next))
    
  let interface alarm thresh on_exit time primary_views local_send =
    log (fun () ->  "NO_IOV.interface");
    let s = {
      max_ltime   = 0 ;
      last_view	= time ;
      next_action = Time.zero
    } in
    
    let install ((ls,vs) as vf) =
      let rec choose_dest ()  =
        if ls.nmembers = 1 then None
        else
          let r = Random.int ls.nmembers in
	  if r = ls.rank then choose_dest ()
	  else Some r
      in
      
      let heartbeat time =
        max_time := max time !max_time ;
        let acts = ref [] in
        if Param.bool vs.params "top_dump_linger"
	  && s.last_view <> Time.invalid
          && time >= Time.add s.last_view (Time.of_int 1000) 
        then (
	  printf "RAND: Error, the view lingered more than 1000 simulated seconds";
	  dump vf s ;
	  s.last_view <- time ;
	  acts := Control Dump :: !acts
        ) ; 
        (**)
        if Time.ge time s.next_action then (
	  let (action,next) = policy ls.rank ls.nmembers thresh in
	  s.next_action <- Time.add time next ;
          
	  match action with
	    | ALeave ->
	        acts := Control Leave :: !acts ;
	        if !verbose then (
	          printf "RAND:%s:Leaving(nmembers=%d)\n" ls.name ls.nmembers
	        )
            | ASuspect -> 
                begin match choose_dest () with 
                  | None -> () 
                  | Some x -> acts := (Control(Suspect [x])) :: !acts 
                end
	    | ANone -> ()
        ) ;
        Array.of_list !acts
      in
      
      let receive o bk cs msg = failwith "should not receive messages in this test"
      in
      
      let block () = [||]
      in
      
      let handlers = { 
        flow_block = (fun _ -> ());
        receive = receive ;
        block = block ;
        heartbeat = heartbeat ;
        disable = Util.ident
      } in
      
      s.last_view   <- !max_time ;
      s.max_ltime   <- max s.max_ltime vs.ltime ;
      s.next_action <- Time.zero ;
      
      if (not !quiet) 
        && (!verbose || ls.rank = 0) then
          printf "RAND:%s:(time=%s) View=(xfer=%s;prim=%s)%s\n"
	    ls.name 
	    (Time.to_string !max_time)
 	    (string_of_bool vs.xfer_view)
 	    (string_of_bool vs.primary)
	    (View.to_string vs.view);

      [||],handlers
    in
    
    let exit () =
      on_exit (succ s.max_ltime)
    in
    { 
      heartbeat_rate      = Time.of_int 1 ;
      install             = install ;
      exit                = exit 
    }
end  


(**************************************************************)
module WITH_IOV = struct
  type action = ACast | ASend1 | ASend | ALeave | ANone
      
  let string_of_action = function
    | ACast -> "ACast"
    | ASend1 -> "ASend1"
    | ASend -> "ASend"
    | ALeave -> "ALeave"
    | ANone -> "ANone"
        
  let policy my_rank nmembers thresh =
    let next = Random.int 10000000 * nmembers in
    let p = Random.int 100 in
    let action =
      if nmembers >= thresh then (
        if p*nmembers*2 < 10 then ALeave
        else if p < 40 then ACast
        else if p < 70 then ASend 
        else ASend1 
      ) else 
        ANone
    in 
    (*  if p < 10 then *)
    log (fun () -> string_of_action action);
    (action,(Time.of_ints 0 next))
    
  (**************************************************************)
    
  let digest iovl =
    let md5 = Hsys.md5_init () in
    Hsys.md5_update_iovl md5 iovl ;
    Hsys.md5_final md5
      
  let gen_msg () = 
    let len = 
      if !size > 0 then Random.int !size
      else 0
    in
    let send_pool = Iovec.get_send_pool () in
    log (fun () -> sprintf "gen_msg: len=%d" len );
    let len = Buf.len_of_int len in
    let iov = Iovec.alloc send_pool len in
    let iov = Iovecl.of_iovec iov in
    let d = digest iov in
    let d = Iovec.of_buf send_pool (Buf.of_string d) len0 md5len in
    let iovl = Iovecl.prependi d iov in
    iovl
      
  let check iovl =
    let len = Iovecl.len iovl in
    assert (len >= md5len) ;
    let d_iovl = Iovecl.sub iovl len0 md5len in
    let d_iov = Iovecl.flatten d_iovl in
    let d = Iovec.buf_of d_iov in
    Iovec.free d_iov ;
    Iovecl.free d_iovl ;
    let iovl = Iovecl.sub iovl md5len (len -|| md5len) in
    let d' = Buf.of_string (digest iovl) in
    Iovecl.free iovl ;
    if d <> d' then 
      failwith "bad message"
        
  (**************************************************************)
        
  let interface alarm thresh on_exit time primary_views local_send =
    log (fun () ->  "WITH_IOV.interface");

    let s = {
      max_ltime   = 0 ;
      last_view	= time ;
      next_action = Time.zero
    } in
    
    
    let install ((ls,vs) as vf) =
      let msg () = gen_msg () in
      
      let rec choose_dest ()  =
        if ls.nmembers = 1 then None
        else
	  let r = Random.int ls.nmembers in
	  if local_send then Some r
	  else
	    if r = ls.rank then choose_dest ()
	    else Some r
      in
      
      let block_msg () = 
        if Random.int 2 = 0 then (
	  Cast(gen_msg ())
        ) else (
	  match choose_dest () with 
	    | Some dest -> Send1(dest,gen_msg())
	    | None -> failwith "Sanity: could not choose a peer in the group, group size must be 1."
        )
      in
      
      let heartbeat time =
        max_time := max time !max_time ;
        let acts = ref [] in
        if Param.bool vs.params "top_dump_linger"
	  && s.last_view <> Time.invalid
          && time >= Time.add s.last_view (Time.of_int 10000) 
        then (
	  printf "RAND: Error, the view lingered more than 10000 simulated seconds";
	  dump vf s ;
	  s.last_view <- time ;
	  acts := Control Dump :: !acts
        ) ; 
        (**)
        if Time.ge time s.next_action then (
	  let (action,next) = policy ls.rank ls.nmembers thresh in
	  s.next_action <- Time.add time next ;
          
	  match action with
	    | ACast ->
                (*
	          eprintf "RAND:%s:casting\n" ls.name ;
                *)
	        acts := [Cast(msg())] @ !acts;
	    | ASend1 -> (
	        match choose_dest () with 
		    None -> ()
	          | Some dest -> 
		      acts := [Send1(dest, msg())] @ !acts;
	      )
	    | ASend -> (
	        let dest1 = choose_dest () in
	        let dest2 = choose_dest () in
	        match dest1,dest2 with 
	          | Some dest1, Some dest2 -> 
		      log (fun () -> sprintf "Send([%d;%d])" dest1 dest2);
		      acts := [Send([|dest1; dest2|], msg())] @ !acts;
	          | _ -> ()
	      )
	    | ALeave ->
	        acts := [Cast(msg()); Cast(msg()); Cast(msg()); Control(Leave)] @ !acts ;
	        if !verbose then (
	          printf "RAND:%s:Leaving(nmembers=%d)\n" ls.name ls.nmembers
	        )
	    | ANone -> ()
        ) ;
        Array.of_list !acts
      in
      
      let receive o bk cs =
        let handle msg = 
	  if vs.ltime <> s.max_ltime then (
	    eprintf "RAND:received non-synchronized message\n" ;
	    eprintf "RAND:origin=%d blocked=%s type=%s\n"
	      o (string_of_blocked bk) (string_of_cs cs) ;
	    dump vf s ;
	    failwith "non-synchronized message"
	  ) ;
          
	  check msg ; 
	  Iovecl.free msg;
	  [||] 
        in handle
      in
      
      let block () =
        if ls.nmembers > 1 then (
      	  (*Array.init 5 (fun _ -> block_msg ())*) [||]
        ) else [||]
      in
      
      let handlers = { 
        flow_block = (fun _ -> ());
        receive = receive ;
        block = block ;
        heartbeat = heartbeat ;
        disable = Util.ident
      } in
      
      s.last_view	  <- !max_time ;
      s.max_ltime   <- max s.max_ltime vs.ltime ;
      s.next_action <- Time.zero ;
      
      if (not !quiet) 
        && (!verbose || ls.rank = 0) then
          printf "RAND:%s:(time=%s) View=(xfer=%s;prim=%s)%s\n"
	    ls.name 
	    (Time.to_string !max_time)
 	    (string_of_bool vs.xfer_view)
 	    (string_of_bool vs.primary)
	    (View.to_string vs.view) ;
      
      if vs.primary then (
        let ltime = vs.ltime in
        begin
      	  try
      	    let vs' = Hashtbl.find primary_views ltime in
	    if vs <> vs' then (
	      printf "Previous view state:\n%s\n" (View.string_of_state vs') ;
	      printf "Current view state:\n%s\n" (View.string_of_state vs) ;
              (*
	        printf "Previous view state:%s"  (View.string_of_id vs'.view_id) ;
	        printf "Current view state:%s" (View.string_of_id vs.view_id) ;
              *)
	      failwith "Two primary partitions have the same logical time !!" ;
	    )
      	  with Not_found ->
	    Hashtbl.add primary_views ltime vs
        end
      ) ;
      
      let actions =
        if vs.xfer_view then 
	  [|Control XferDone|] 
        else 
	  [|Cast (msg ())|]
      in
      actions,handlers
    in
    
    let exit () =
      on_exit (succ s.max_ltime)
    in
    { 
      heartbeat_rate      = Time.of_int 1 ;
      install             = install ;
      exit                = exit 
    }
end

(**************************************************************)
    
let thresh   	= ref 5
let nmembers    = ref 7
let groupd_local = ref false
let ngroupds    = ref 3
let local_send    = ref false
let prog        = ref "with_iov"
(**************************************************************)

let run () =
  let primary_views = Hashtbl.create 503 in

  let props = Property.Drop :: Property.Debug  :: Property.vsync in

  Param.default "top_dump_linger" (Param.Bool true) ;
  Param.default "top_dump_fail" (Param.Bool true) ;
  Arge.set alarm "Netsim" ;
  Arge.set modes [Addr.Netsim] ;
  Arge.set properties props ;
  Arge.set short_names true ;

  let undoc = ": undocumented" in
  Arge.parse [
    "-n",	Arg.Int(fun i -> nmembers := i),undoc ;
    "-t",	Arg.Int(fun i -> thresh := i),undoc ;
    "-s",	Arg.Int(fun i -> size := i),undoc ;
    "-groupd_local", Arg.Set(groupd_local),undoc ;
    "-quiet",	Arg.Set(quiet),undoc ;
    "-ngroupds", Arg.Int (fun i -> ngroupds := i), "number of group-daemons" ;
    "-local_send", Arg.Set(local_send), "test sends from an endpoint to itself";
    "-prog",    Arg.String (fun s -> prog :=s ), "which program: [with_iov|no_iov]"
  ] (Arge.badarg name) 
      "rand: random failure generation test program" ;
  
  let prog = match !prog with 
    | "with_iov" -> With_iov
    | "no_iov" -> No_iov
    | _ -> failwith "no such program. Available: [with_iov|no_iov]"
  in

  (* Clear the iovec system for the No_iov test *)
  begin match prog with 
    | With_iov -> ()
    | No_iov -> Iovec.shutdown ()
  end;
  let alarm = Appl.alarm name in
  if Arge.get Arge.modes = [Addr.Netsim] then (
    Alarm.install_port (-2) ;
  ) ;

  let gettime () = 
    let time = Alarm.gettime alarm in
    if Time.is_zero !max_time then 
      max_time := time ;
    time
  in

  let interface = match prog with 
    | With_iov -> WITH_IOV.interface
    | No_iov -> NO_IOV.interface
  in

  let instance =
    if not !groupd_local then (
      let rec instance (ls,vs) ltime =
    	(*let (ls,vs) = Appl.default_info "rand" in*)
    	let vs = View.set vs [Vs_ltime ltime] in
	let ls = View.local name ls.endpt vs in
    	let time = gettime() in
        let interface = interface alarm !thresh (instance (ls,vs)) time 
          primary_views !local_send
        in
    	Appl.config_new interface (ls,vs)
      in instance
    ) else (
      (* Start up some number of local groupd daemons.
       *)
      let ngroupds = !ngroupds in
      let groupds = 
	Arrayf.init ngroupds (fun _ ->
	  let vf = Appl.default_info "groupd" in
	  let handle,vf,interface = Manage.groupd_create alarm vf in
	  Appl.config_new interface vf ;
	  handle
        )
      in

      (* Set this here so that the groupd endpoints don't
       * use it.
       *)
      Arge.set groupd true ;
      let rec instance (ls,vs) ltime =
    	let (ls,vs) = Appl.default_info "rand" in
    	let vs = View.set vs [Vs_ltime ltime] in
	let ls = View.local name ls.endpt vs in
    	let time = gettime() in
    	let interface = WITH_IOV.interface alarm !thresh (instance (ls,vs)) time primary_views !local_send in
	let groupd = Arrayf.get groupds (Random.int ngroupds) in
  	let glue = Arge.get Arge.glue in
	let state = Layer.new_state interface in
    	let member = Stacke.config_full glue alarm Addr.default_ranking state in
    	let res = groupd (ls,vs) member in
	res
      in instance
    )
  in

  for i = 1 to !nmembers do
    let (ls,vs) = Appl.default_info name in
    instance (ls,vs) 0
  done ;

  Sys.catch_break true ;
  Appl.main_loop ()

let _ = Appl.exec ["rand"] run

(**************************************************************)

