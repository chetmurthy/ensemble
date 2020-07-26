open Auxl
open Coord
open Printf

let f = "/cs/phd/orodeh/zigzag/lang/caml/viewperf/f"
let mtalk = "/cs/phd/orodeh/zigzag/e/ensemble/demo/mtalk"
let armadillo = "/cs/phd/orodeh/zigzag/e/ensemble/demo/armadillo"
  (*let f = "f"*)
  
type proto = Dwgl | Dyntree | Diam 
    
let view_n proto n terminate_time s opts = 
  let default = sprintf "-pbool sec_sim=true -pgp_addr 1 -trace PERFREKEYM -pint secchan_key_len=1024" in
  let times = "-timeout 30" in
  let rekey_layer = match proto with
    | Dwgl -> "-trace OPTREKEYM -trace REALKEYSM"
    | Dyntree -> "-remove_prop OptRekey -add_prop Rekey"
    | Diam -> "-remove_prop OptRekey -add_prop DiamRekey -trace REKEY_DIAMM"
  in
  let kind = "-modes DEERING" in
  let prog = "-prog flip_flop" in
  let base_cmd = f ^ " " ^ default ^ " " ^ times ^ " " ^ rekey_layer ^ 
    " " ^ kind ^ " " ^ prog ^ s in 
  let base_cmd = base_cmd ^ 
    (sprintf " -n %d -terminate_time %d" n terminate_time) in
  print (base_cmd ^ "\n");
  rpc (fun i _ -> 
    if i=n-1 then Do_command (sprintf "%s -trace PROPERTY" base_cmd)
    else Do_command base_cmd)
    (terminate_time+10) ([To_coord; Time; Num n] @ opts)

let regular_stack n terminate_time opts= 
  let base_cmd = sprintf "%s -modes DEERING -refcount -scale -net -prog reg -n %d -terminate_time %d -trace CONFIG_TRANS" armadillo n terminate_time in
  rpc (fun i _ -> 
    if i=n-1 then Do_command (sprintf "%s -trace PROPERTY" base_cmd)
    else Do_command base_cmd)
    (terminate_time+10) ([To_coord; Time; Num n] @ opts)

let just_mtalk n terminate_time = 
  let base_cmd = sprintf "%s -modes DEERING -refcount -add_prop Scale" mtalk in
  rpc (fun i _ -> 
    if i=n-1 then Do_command (sprintf "%s -trace PROPERTY" base_cmd)
    else Do_command base_cmd)
    (terminate_time+10) [To_coord; Time; Num n]


(* We count down from m to n, in steps of size [size]
*)
let for_step n m step f = 
  let k = ref m in 
  while (!k >= n) do 
    f !k;
    k := !k - step;
  done

module type Test = sig
  val run : int (*time in seconds *) -> int (*number of machines*)-> int -> int -> unit 
end


module TestFlipFlop : Test = struct
  let run time m n step= 
(*
    printf "---------------------------------------------------------------\n";
    printf "Testing Dwgl algorithm, program flip_flop\n";
    for_step m n step (function i -> 
      printf "\n**********************************\n";
      printf "Membership=%d\n" i;
      view_n Dwgl i time "" [File "test_dwgl_60_1"];
      flush stdout
    );
*)
    printf "---------------------------------------------------------------\n";
    printf "Testing Dyntree algorithm, program join_leave\n";
    for_step m n step (function i -> 
      printf "\n**********************************\n";
      printf "Membership=%d\n" i;
      view_n Dyntree i time "" [File "test_dyntree_50"];
      flush stdout
    );
(*
    printf "---------------------------------------------------------------\n";
    printf "Testing Diamond algorithm, program flip_flop \n";
    for_step m n step (function i ->
      printf "\n**********************************\n";
      printf "Membership=%d\n" i;
      view_n Diam i time "" [File "test_diam_60_1"];
      flush stdout
    );
*)

end

let mach = ref []
let n = ref 6

let run () = 
  Arg.parse [
  ] (fun s -> mach := s :: !mach) "test script";

  printf "machines= %s\n" (string_of_string_list !mach);
  flush_out ();

  connect !mach ;
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
  let num = List.length live_machines in
  (*if num < !n then failwith "Not enough live machines";*)
  let ciel = (num*3/5) * 5 in

  (*
    let run_time time m n step = ((n-m) /step + 1) * time * 3 in
    let to_hours time = sprintf "%d:%d" (time / 3600) (time mod 3600 / 60) in
    
    printf "Total running time=%s\n" (to_hours (run_time 1000 5 20 5)) ;
  *)
  
  (*TestAllOne.run        500  20 30  5;*)
  (*TestJoinLeaveLeader.run  500 30 30 5;*)
  (*TestJoinLeaveRandom.run     500 !n !n  5;*)
  
  TestFlipFlop.run     1000 35 50 5;
  (*regular_stack 80 1000 [];*)
  (*just_mtalk num 500;*)

  exit 0




