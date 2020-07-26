open Aux
open Coord
open Printf ;;

let base = 
  try Sys.getenv "ENS_ABSROOT"
  with Not_found ->
    printf "You must set the ENS_ABSROOT environment variable for this 
      program to work\n";
    exit 1

let perf = base ^ "bin/i386-linux/perf"

type kind = 
  | Reg
  | Auth
  | Secure
  
let options_of_kind = function
  | Reg -> ""
  | Auth -> "-key 0123456789abcdef0123456789abcdef"
  | Secure -> "-key 0123456789abcdef0123456789abcdef -add_prop Privacy"

let f size kind options= 
  rpc (fun i _ ->
    if i>=2 then Do_unit
    else 
      let s = 
	sprintf "%s -modes DEERING -prog latency -s %d %s %s" perf size options (options_of_kind kind) in
      Do_command (s)
  ) 10 [To_coord;Time]

let mach = ref []
let n = ref 2

let run () = 
  Arg.parse [
  ] (fun s -> mach := s :: !mach) "test script";

  printf "machines= %s\n" (string_of_string_list !mach);
  flush_out ();

  connect (!mach);
  let replys = rpc_uptime () in
  List.iter (fun (m,x) -> printf "%s: %1.2f\n" m x) replys;
  let live_machines = List.fold_left (fun m_l (m,x) -> 
    if x<0.3 then (m,x) :: m_l else m_l
  ) [] replys in
  let live_machines = List.map (function (m,_) -> m) live_machines in
  let dead_machines = set_live live_machines in
  printf "%d dead_machines=%s\n" (List.length dead_machines) 
    (string_of_list ident dead_machines);
  printf "%d live_machines=%s\n" (List.length live_machines) 
    (string_of_list ident live_machines);
  let num = List.length live_machines in
  if num < !n then failwith "Not enough live machines";
  


  printf "--------------------------------------------------------------------\n";
  printf "--------------------------------------------------------------------\n";
  printf "--------------------------------------------------------------------\n";
  printf "REG\n";
  for i=0 to 20 do
    let size = i/2*100 in
    printf "--------------------------------------------------------------------\n";
    printf "size= %d\n" size;
    f size Reg "" ;
    Unix.sleep 1
  done;
  ()

(*
  printf "--------------------------------------------------------------------\n";
  printf "--------------------------------------------------------------------\n";
  printf "--------------------------------------------------------------------\n";
  printf "AUTH\n";
  for i=0 to 20 do 
    let size = i/2*100 in
    printf "--------------------------------------------------------------------\n";
    printf "size= %d\n" size;
    f size Auth "" 
  done;

  printf "--------------------------------------------------------------------\n";
  printf "--------------------------------------------------------------------\n";
  printf "--------------------------------------------------------------------\n";
  printf "SECURE\n";
  for i=0 to 20 do
    let size = i/2*100 in
    printf "--------------------------------------------------------------------\n";
    printf "size= %d\n" size;
    f size Secure "" 
  done;

*)
