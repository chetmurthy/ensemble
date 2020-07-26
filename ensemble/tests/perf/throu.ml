open Auxl
open Coord
open Printf ;;

(*
perf -quiet -modes DEERING -prog 1-n -s 1000 -rate 0.0012 -terminate_time 10 -n 2

dir ../def/obj/i386-linux ../appl ../util ../infr ../socket ../trans ../buffer ../route

perf -refcount -modes DEERING -prog 1-n -s 1000 -rate 0.0012  -key 0123456789abcdef0123456789abcdef

*)

let base = 
  try Sys.getenv "ENS_ABSROOT"
  with Not_found ->
    printf "You must set the ENS_ABSROOT environment variable for this 
      program to work\n";
    exit 1

let perf = base ^ "bin/i386-linux/perf"
let num_live = ref 100

type kind = 
  | Reg
  | Auth
  | Secure
  
let options_of_kind = function
  | Reg -> ""
  | Auth -> "-key 0123456789abcdef0123456789abcdef"
  | Secure -> "-key 0123456789abcdef0123456789abcdef -add_prop Privacy -pbool encrypt_inplace=true"

let f n terminate_time kind options= 
  if n > !num_live then 
    failwith (sprintf "Not enough members. There are %d, when %d are requested" 
      !num_live n);
  rpc (fun i _ ->
    if i>=n then Do_unit
    else 
      let s = 
	sprintf "%s -quiet -modes DEERING -prog 1-n -s 1000 -rate 0.0012 -terminate_time %d %s -n %d %s" perf  terminate_time options n (options_of_kind kind) in
      Do_command (s)
  ) (terminate_time + 30) [To_coord;Time]


let mach = ref []
let n = ref 2
let lo = ref 2
let hi = ref 2
let step = ref 1

let run () = 
  Arg.parse [
    "-lo", Arg.Int (fun i -> lo:=i), "Start with [lo] members";
    "-hi", Arg.Int (fun i -> hi:=i), "End with [hi] members";
    "-step", Arg.Int (fun i -> step:=i), "steps";
  ] (fun s -> mach := s :: !mach) "test script";

  printf "machines= %s\n" (string_of_string_list !mach);
  printf "from %d to %d step=%d\n" !lo !hi !step;
  flush_out ();

  connect (!mach);
  let replys = rpc_uptime () in
  List.iter (fun (m,x) -> printf "%s: %1.2f\n" m x) replys;
  let live_machines = List.fold_left (fun m_l (m,x) -> 
    if x<1.0 then (m,x) :: m_l else m_l
  ) [] replys in
  let live_machines = List.map (function (m,_) -> m) live_machines in
  let dead_machines = set_live live_machines in
  printf "%d dead_machines=%s\n" (List.length dead_machines) 
    (string_of_list ident dead_machines);
  printf "%d live_machines=%s\n" (List.length live_machines) 
    (string_of_list ident live_machines);
  num_live := List.length live_machines;


  printf "--------------------------------------------------------------------\n";
  printf "--------------------------------------------------------------------\n";
  printf "--------------------------------------------------------------------\n";
  printf "REG\n";

  let nmembers = ref !lo in
  while !nmembers <= !hi do 
    printf "--------------------------------------------------------------------\n";
    printf "nmembers=%d\n" !nmembers;
    f !nmembers 10 Reg "" ;
    nmembers := !nmembers + !step;
    Unix.sleep 1
  done;
  ()

(*
  printf "--------------------------------------------------------------------\n";
  printf "--------------------------------------------------------------------\n";
  printf "--------------------------------------------------------------------\n";
  printf "AUTH\n";
  for i=1 to 7 do 
    let nmembers = 3*i in
    printf "--------------------------------------------------------------------\n";
    printf "nmembers=%d\n" nmembers;
    f nmembers 10 Auth "" ;
  done;
  
  printf "--------------------------------------------------------------------\n";
  printf "--------------------------------------------------------------------\n";
  printf "--------------------------------------------------------------------\n";
  printf "SECURE\n";
  for i=1 to 7 do 
    let nmembers = 3*i in
    printf "--------------------------------------------------------------------\n";
    printf "nmembers=%d\n" nmembers;
    f nmembers 10 Secure ""; 
  done;
*)
