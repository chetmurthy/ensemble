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
(* ADDR.ML *)
(* Author: Mark Hayden, 12/95 *)
(**************************************************************)
open Util
open Trans
(**************************************************************)
let name = Trace.file "ADDR"
let failwith s = Trace.make_failwith name s
(**************************************************************)

type id =
  | Atm
  | Deering
  | Netsim
  | Tcp
  | Udp
  | Sp2
  | Krb5
  | Pgp
  | Fortezza
  | Mpi
  | Eth

(*let all = [|Atm;Deering;Netsim;Tcp;Udp;Sp2;Krb5;Pgp;Fortezza;Mpi|]*)

type t =
  | AtmA of inet
  | DeeringA of inet * port
  | NetsimA
  | TcpA of inet * port
  | UdpA of inet * port
  | Sp2A of inet * port
  | Krb5A of string
  | PgpA of string
  | FortezzaA of string
  | MpiA of rank
  | EthA of eth * pid

type set = t Lset.t

let id_of_addr = function
  | NetsimA    -> Netsim
  | TcpA     _ -> Tcp
  | UdpA     _ -> Udp
  | DeeringA _ -> Deering
  | AtmA     _ -> Atm
  | Sp2A     _ -> Sp2
  | Krb5A    _ -> Krb5
  | PgpA     _ -> Pgp
  | FortezzaA _ -> Fortezza
  | MpiA     _ -> Mpi
  | EthA     _ -> Eth

let ids_of_set s = Arrayf.map id_of_addr (Lset.project s)

let mapping = [|
  "ATM", Atm ;
  "DEERING", Deering ;
  "NETSIM", Netsim ;
  "TCP", Tcp ;
  "UDP", Udp ;
  "SP2", Sp2 ;
  "PGP", Pgp ;
  "FORTEZZA", Fortezza ;
  "KRB5", Krb5 ;
  "MPI", Mpi ;
  "ETH", Eth
|] 

let id_of_string s = Util.id_of_string name mapping s
let string_of_id i = Util.string_of_id name mapping i

let set_of_arrayf = Lset.inject
let arrayf_of_set = Lset.project

let string_of_id_short id =
  let id = string_of_id id in
  try String.sub id 0 1 with
  | _ -> failwith "string_of_id_short:sanity"

let string_of_inet_port ip = 
  string_of_pair Hsys.string_of_inet string_of_int ip

let string_of_addr = function
  | NetsimA        -> "Netsim"
  | TcpA     (i,p) -> sprintf "Tcp%s" (string_of_inet_port (i,p))
  | UdpA     (i,p) -> sprintf "Udp%s" (string_of_inet_port (i,p))
  | DeeringA (i,p) -> sprintf "Deering%s" (string_of_inet_port (i,p))
  | AtmA     i     -> sprintf "Atm(%s)" (Hsys.string_of_inet i)
  | Sp2A     (i,p) -> sprintf "Sp2%s" (string_of_inet_port (i,p))
  | PgpA         a -> sprintf "Pgp(%s)" a
  | Krb5A        _ -> sprintf "Krb5(_)"
  | FortezzaA    _ -> sprintf "Fortezza(_)"
  | MpiA      rank -> sprintf "Mpi(%d)" rank
  | EthA     (a,p) -> sprintf "Eth(%s,%d)" (string_of_eth a) p

let string_of_set a = Arrayf.to_string string_of_addr (Lset.project a)

let has_mcast = function
  | Udp
  | Deering 
  | Mpi					(*BUG*)
  | Eth
  | Netsim -> true
  | _ -> false

let has_pt2pt = function
  | Udp
  | Deering
  | Tcp
  | Atm
  | Netsim 
  | Mpi
  | Eth
  | Sp2 -> true
  | _ -> false

let has_auth = function
  | Pgp
  | Krb5
  | Fortezza -> true
  | _ -> false
      
let all_trans = Arrayf.of_array [|Atm;Deering;Sp2;Udp;Tcp;Netsim;Mpi|]

let default_ranking = function
  | Eth -> 7
  | Atm -> 6
  | Deering -> 5
  | Mpi -> 4
  | Sp2 -> 3
  | Udp -> 2
  | Tcp -> 1
  | Netsim -> 0
  | _ -> -1

let init = ((-1),None)

let prefer ranking modes =
  match 
    Arrayf.fold_left (fun ((mx,_) as it) m ->
      let rank = ranking m in
      if rank >= 0 && rank > mx then (rank,Some m) else it
    ) init modes
  with
  | _,None ->
      eprintf "ADDR:modes=%s\n" (Arrayf.to_string string_of_id modes) ;
      failwith "no such transport available"
  | _,(Some mode) -> mode
(*
    printf "ADDR:modes=%s,cast=%b,res=%s\n"
      (string_of_list string_of_id modes) cast 
      (string_of_id (List.nth preferences rank)) ;
*)

let project addrs mode =
  let addrs = Lset.project addrs in
  let rec loop i =
    if i >= Arrayf.length addrs then
      failwith "project:mode not available"      
    else if id_of_addr (Arrayf.get addrs i) = mode then
      Arrayf.get addrs i
    else loop (succ i)
  in loop 0

let check _ a =
  let m = id_of_addr a in
  has_pt2pt m || has_mcast m

(* Check if two addresss sets are for the same process.
 * Netsim addresses are always for different processes.
 *)
let netsim = Lset.inject (Arrayf.singleton NetsimA)
let same_process a b =
  if a = netsim && b = netsim then false else (
    let i = Lset.intersecta a b in
    let i = Lset.project i in
    Arrayf.exists check i
  )

let project_eth addrs =
  let addrs = Lset.project addrs in
  let rec loop i =
    if i >= Arrayf.length addrs then
      None
    else (
      match Arrayf.get addrs i with
      | EthA(eth,pid) -> Some eth
      |	_ -> loop (succ i)
    )
  in loop 0

(* Same as same_process, but equal Eth addresses
 * will also match even if the pid's are different.
 *)
let same_dest a b =
  if same_process a b then true else (
    match project_eth a with
    | None -> false
    | Some a ->
	match project_eth b with
	| None -> false
	| Some b -> a = b
  )

let compress me addrs =
  let local,addrs = 
    Arrayf.fold_left (fun (local,remote) hd ->
      (* 1. If in same process, mark local and strip.
       * 2. If same dest already included, strip.
       * 3. Otherwise add to list
       *)
      if same_process hd me then
	(true,remote)
      else if List.exists (fun a -> same_dest hd a) remote then
	(local,remote)
      else
	(local, (hd :: remote))
    ) (false,[]) addrs
  in
  let addrs = Arrayf.of_list addrs in
  (local,addrs)
(*
let compress me o =
  let r = compress me o in
  eprintf "ADDR:compress:me=%s" (string_of_set me) ;
  eprintf "  input =%s\n" (string_of_list string_of_set o) ;
  eprintf "  output=%s,%b\n" 
    (string_of_list string_of_set (snd r)) (fst r) ;
  r
*)
(**************************************************************)

let modes_of_view addrs =
  let modes = Arrayf.map (fun addr -> Lset.inject (ids_of_set addr)) addrs in
  assert (not (Arrayf.is_empty modes)) ;(* fold only accepts non-empty arrays *)
  let modes = Arrayf.fold Lset.intersecta modes in
  let modes = Lset.project modes in
  if Arrayf.is_empty modes then (  
    eprintf "ADDR:modes_of_view:warning:empty:%s\n"
      (Arrayf.to_string string_of_set addrs)
  ) ;
  modes
  
(**************************************************************)

let error modes =
  let soms m = Arrayf.to_string string_of_id m in
  eprintf "

Error.  A group is being initialized with a bad set of
communication modes.

  Selected modes were: %s
  Of which, these modes support pt2pt: %s
  And these modes support multicast: %s

Each endpoint of a group must have at least one multicast and one
pt2pt mode ennabled.  In addition, all members must share at
least one common mode of both pt2pt and multicast type in order
to communicate.

  All Ensemble modes are: %s
  Of which, these have pt2pt: %s
  And these support multicast: %s

Note that not all modes may be available to every
application (for example, DEERING requires IP multicast).

Modes are selected through the ENS_MODES environment
variable and the -modes command-line argument, both of which
give a colon (':') separated list of modes to use (for
example, DEERING:UDP).

(exiting)
"
    (soms modes)
    (soms (Arrayf.filter has_pt2pt modes))
    (soms (Arrayf.filter has_mcast modes))

    (soms all_trans)
    (soms (Arrayf.filter has_pt2pt all_trans))
    (soms (Arrayf.filter has_mcast all_trans)) ;
  exit 1

(**************************************************************)
