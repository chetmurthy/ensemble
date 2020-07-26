(**************************************************************)
(* GROUPD.ML *)
(* Author: Mark Hayden, 8/95 *)
(**************************************************************)
open Ensemble
open Util
open View
(**************************************************************)
let name = Trace.file "GROUPD"
let failwith s = Trace.make_failwith name s
(**************************************************************)

let nice = ref false

let init alarm =
  (*
   * Get default transport and alarm info.
   *)
  let (ls,vs) = Appl.default_info "groupd" in
  let vs =
    if not !nice then vs else 
      View.set vs [
        Vs_params([
	  "pr_stable_sweep",Param.Time(Time.of_int 3) ;
	  "pr_stable_fanout",Param.Int(5) ;
	  "pr_suspect_sweep",Param.Time(Time.of_int 3) ;
	  "pr_suspect_max_idle",Param.Int(20) ;
	  "pr_suspect_fanout",Param.Int(5) ;
	  "merge_sweep",Param.Time(Time.of_int 3) ;
	  "merge_timeout",Param.Time(Time.of_int 150) ;
	  "top_sweep",Param.Time(Time.of_int 10)
        ])]
  in

  (* Get the port number to use from the argument module.
   *)
  let port = Arge.check name Arge.groupd_port in

  (* Initialize the Maestro stack.
   *)
  let vf, interface = 
    Manage.create_proxy_server alarm port (ls,vs)
  in
  Appl.config_new interface vf
  (* end of init function *)


let run () = 
  (* Set the default pollcount value to 0.  This makes the
   * application somewhat more efficient.  
   *)
  Arge.set Arge.pollcount 0 ;

  (*
   * Parse command line arguments.
   *)
  Arge.parse [
    (*
     * Extra arguments can go here.
     *)
    "-nice", Arg.Set(nice), "use minimal resources"
  ] (Arge.badarg name) "groupd server" ;

  (* Get the application state.
   *)
  let alarm = Appl.alarm name in

  (* Do initialization.
   *)
  init alarm ;

  (*
   * Enter a main loop
   *)
  Appl.main_loop ()
  (* end of run function *)


(* Run the application, with exception handlers to catch any
 * problems that might occur.
 *)
let _ = Appl.exec ["groupd"] run

(**************************************************************)
