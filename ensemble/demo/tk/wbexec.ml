(**************************************************************)
(* WBEXEC.ML *)
(* Authors: Mark Hayden, Robbert vanRenesse, 3/96 *)
(**************************************************************)
open Ensemble
open Util
open Hsys
(**************************************************************)
let name = Trace.file "WBEXEC"
(**************************************************************)

let wrap dbg f a =
  try
    f a
  with e ->
    failwith (sprintf "WBEXEC:error:%s:%s\n" dbg (Hsys.error e)) ;
    exit 0

let do_migrate host_name =
  let cin,cout = wrap "dm:op" Unix.open_process "wbml -migrated" in
  let addr = wrap "dm:iv" input_value cin in
(*
  wrap "dm:cin" close_in cin ;
*)
  let addr = ( addr : Addr.set ) in
  let got_vs vs =
    let vs = ( vs : View.state ) in
    wrap "dm:ov" (fun () -> output_value cout vs) () ;
    wrap "dm:fout" flush cout ;
    wrap "dm:exit" exit 0
  in
  (addr,got_vs)

let run () =
  let migrated = ref false in

  (* Set defaults for domain and alarm.
   *)
  Arge.set_string Arge.alarm "Tk" ;
  Param.default "stable_sweep" (Param.Time (Time.of_float 0.5)) ;
  Param.default "suspect_sweep" (Param.Time (Time.of_float 0.5)) ;
  Param.default "suspect_max_idle" (Param.Int 4) ;
  Param.default "merge_timeout" (Param.Time (Time.of_float 8.0)) ;

  (* Parse command line arguments.
   *)
  Arge.parse [
    "-migrated",Arg.Set(migrated),""
  ] (Arge.badarg name) "" ; 

  (* Choose a string name for this member.  Usually
   * this is "userlogin@host".
   *)
  let username =
    try
      (Hsys.getlogin ()) ^ "@" ^ (Hsys.gethostname ())
    with _ ->
      ("unknown")
  in

  let top = Tk.openTk () in
  let (ls,vs) = Appl.default_info "wb" in

  let vs =
    if !migrated then (
      let addr = Arrayf.get vs.View.address ls.View.rank in
      let addr = ( addr : Addr.set ) in
      wrap "run:ov" (fun () -> output_value stdout addr) () ;
      wrap "run:cout" close_out stdout ;
      let vs = wrap "run:iv" input_value Pervasives.stdin in
      wrap "run:cin" close_in Pervasives.stdin ;
      let vs = ( vs : View.state ) in
      vs
    ) else vs
  in

(*
  let prop = [Property.Rekey;Property.Auth] @ Property.vsync in
  let prop = [Property.Rekey] @ Property.vsync in
*)
  let prop = Property.vsync in
  let proto = Property.choose prop in
  let vs = View.set vs [View.Vs_proto_id proto] in

  Wb.init top (ls,vs) username do_migrate ;
  Elink.get name Elink.htk_init (Elink.alarm_get_hack ()) ;
  Tk.mainLoop ()

(**************************************************************)
(* Run the application, with exception handlers to catch any
 * problems that might occur.
 *)
let _ = Printexc.catch run ()

(* Flush output and exit the process.
 *)
let _ = exit 0

(**************************************************************)
