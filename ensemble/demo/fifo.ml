(**************************************************************)
(* FIFO.ML *)
(* Randomly multicast/send messages, but in a way that will cause
 * group to deadlock if FIFO is not live. *)
(* Author: Mark Hayden, 7/95 *)
(**************************************************************)
open Ensemble
open Trans
open Util
open Arge
open View
open Appl_intf open New
(**************************************************************)
let name = "FIFO"
let failwith = Trace.make_failwith name
let log = Trace.log name
(**************************************************************)

type tree = 
    Node 
  | Br of tree * int * tree

type message = 
  | NoMsg
  | Token of rank * int
  | Spew
  | Ignore of string
  | Tree of tree


(**************************************************************)

let nrecd = ref 0
and nsent = ref 0

(**************************************************************)
(* Create a random tree
*)
let rec gen_tree () = 
  log (fun () -> "gen_tree");
  let i = Random.int 5 in
  if i < 3 then Node
  else Br (gen_tree (), i, gen_tree ())

let rec sum_tree = function 
    Node -> 0
  | Br (l,x,r) -> sum_tree l + x + sum_tree r

let interface nopt2pt nocast =
  let time     = ref Time.zero in
  let last_msg = ref Time.zero in

  let rec random_member ls =
    let rank = Random.int ls.nmembers in
    if rank = ls.rank then
      random_member ls
    else (
(*    eprintf "RANDOM_MEMBER:%d->%d\n" ls.rank rank ;*)
      rank
    )
  in

  let install (ls,vs) =
    eprintf "FIFO:time=%s view=%s\n" (Time.to_string !time) (View.to_string vs.view) ;

    let receive origin bk cs msg =
      let from = Arrayf.get vs.view origin in
      let act = ref [] in
      last_msg := !time ;
      incr nrecd ;
      if !verbose & (!nrecd mod 113) = 0 then (
	eprintf "FIFO:nsent=%d, nrecd=%d\n" !nsent !nrecd
  (*    if !nrecd = 10000 then
	  exit 0
  *)
      ) ;

      (match msg with
      | Token(next,seqno) -> (
(*
	  eprintf "TOKEN:%s -> %s (me=%s)\n" 
	    (Endpt.string_of_id from) 
	    (Endpt.string_of_id next) ls.name ;
*)

	  if next = ls.rank then (
	    if Random.float 1.0 < 0.1 then (
	      nsent := !nsent + pred ls.nmembers ;
	      act := Cast(Tree (gen_tree ())) :: Cast(Spew) :: !act
	    ) ;
	    let next = random_member ls in
	    let dest = next in

	    let do_cast =
	      if nopt2pt then true
	      else if nocast then false
	      else Random.int 10 < 5
	    in

	    let kind = 
	      if do_cast then (
	      	nsent := !nsent + pred ls.nmembers ;
	      	act := Cast(Token(dest,succ seqno)) :: !act ; "cast"
     	      ) else (
	      	incr nsent ;
	      	act := Send1(next,Token(dest,succ seqno)) :: !act ; "send"
	      ) 
	    in

	    if (seqno mod 23) = 0 then (
	       eprintf "FIFO:token=%d, %d->%d->%d (%s)\n"
	       seqno origin ls.rank next kind
	    )
	  )
	)
      | Spew -> (
	  for i = 1 to Random.int 5 + 5 do
	      let msg = "" (*String.create (Random.int 100)*) in
	    if Random.float 1.0 < 0.5 then (
	      incr nsent ;
	      act := Send1((random_member ls),(Ignore msg)) :: !act
	    ) else (
	      nsent := !nsent + pred ls.nmembers ;
	      act := Cast(Ignore msg) :: !act
	    )
	  done
	)
      | Ignore _ -> ()
      | Tree t -> 
	  log (fun () -> sprintf "tree=%d" (sum_tree t));
	  ()

      | _ -> ()
      ) ;
      if bk=U then 
	Array.of_list !act
      else [||]
    in

    let block () = [||] in
    let heartbeat time' = 
      let old_time = !time in
      time := time' ;
  (*
      eprintf "FIFO:heartbeat:time=%s, last_msg=%s\n" (Time.to_string !time) (Time.to_string !last_msg) ;
  *)
  (*
      if Time.sub old_time !last_msg > Time.of_int 100 then (
	last_msg := time' ;
	[Dump]
      ) else
  *)
      [||]
    in

    let handlers = { 
      flow_block = (fun _ -> ());
      receive = receive ;
      block = block ;
      heartbeat = heartbeat ;
      disable = Util.ident
    } in

    let actions =
      if ls.am_coord && ls.nmembers > 1 then (
      	nsent := !nsent + pred ls.nmembers ;
      	[|Cast(Token(1,0))|]
      ) else [||]
    in 

    actions,handlers
  in

  let exit () = exit 0 in


  { heartbeat_rate      = Time.of_int 1 ;
    install             = install ;
    exit                = exit }

(**************************************************************)

let nmembers = ref 5
let nopt2pt = ref false
let nocast = ref false

let run () =
  let props = Property.Drop :: Property.Debug :: Property.vsync in

  Arge.set alarm "Netsim" ;
  Arge.set modes [Addr.Netsim] ;
  Arge.set properties props ;
  Arge.set short_names true ;

  let undoc = ": undocumented" in
  Arge.parse [
    "-n",	Arg.Int(fun i -> nmembers := i),undoc ;
    "-nopt2pt", Arg.Set nopt2pt,undoc ;
    "-nocast", Arg.Set nocast,undoc 
  ] (Arge.badarg name)
  "fifo: fifo ordering test program" ;

  if !nocast && !nopt2pt then
    failwith "bad command-line args: -nopt2pt and -nocast" ;

(*
  let instance () =
    let (ls,vs) = Appl.default_info "fifo" in
    let a0 = interface !nopt2pt !nocast in
    let a1 = interface !nopt2pt !nocast in
    let e0 = Endpt.id () in
    let e1 = Endpt.id () in
    Appl.config_new interface (ls,vs) ;
  in
*)

  let alarm = Appl.alarm name in

  if Arge.get Arge.modes = [Addr.Netsim] then (
    Alarm.install_port (-2) ;
  ) ;

  let instance () =
    let (ls,vs) = Appl.default_info "fifo" in
    let interface = interface !nopt2pt !nocast in
    let interface = full interface in
    Appl.config_new interface (ls,vs) ;
  in

  for i = 1 to !nmembers do
    instance ()
  done ;

  Appl.main_loop ()

let _ = Appl.exec ["fifo"] run

(**************************************************************)
