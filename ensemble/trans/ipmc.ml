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
(* IPMC.ML *)
(* Author: Mark Hayden, 5/95 *)
(**************************************************************)
open Util
(**************************************************************)
let name = Trace.file "IPMC"
let failwith s = Trace.make_failwith name s
let log = Trace.log name
(**************************************************************)
(* Check the installation and print warning messages if not
 * fully configured.  
 *)

let _ =
  if not (Hsys.has_ip_multicast ()) then (
    log (fun () -> sprintf "warning, not compiled with IP multicast") ;
    log (fun () -> sprintf "  (couldn't find header files)") ;
  )

(**************************************************************)

let addr () =
  let inet_rand = Random.int 248 + 7 in
  Hsys.deering_addr inet_rand

(**************************************************************)

let socks = Hashtbl.create (*name*) 10

let sock where port =
  try Hashtbl.find socks port with
  | Not_found -> (
      let msg = sprintf "illegal private reference to sock in '%s'" where
      in failwith msg
    )

(**************************************************************)

let very_first port () =
  if not (Hsys.has_ip_multicast ()) then (
    eprintf "IPMC:error:not compiled with IP multicast, exiting\n" ;
    exit 1
  ) ;

  let sock = Appl.udp_socket () in

  (* Make it reusable.
   *)
  begin try
    Hsys.setsockopt sock Hsys.Reuse
  with e ->
    eprintf "IPMC:error:setsockopt:Reuse:%s\n" (Hsys.error e) ;
    exit 1
  end ;

  (* Do any other initialization required.  Enable loopback.
   *)
  begin try
    Hsys.setsockopt sock (Hsys.Multicast true)
  with e ->
    eprintf "IPMC:error:setsockopt:Multicast:%s\n" (Hsys.error e) ;
    exit 1
  end ;
      
  (* Bind it to the port.
   *)
  log (fun () -> sprintf "port=%d" port) ;
  
  begin try
    Hsys.bind sock (Hsys.inet_any ()) port ;
  with e ->
    eprintf "IPMC:error:binding to port %d:%s\n" port (Hsys.error e) ;
    exit 1
  end ;
    
  (* Save this reference.
   *)
  Hashtbl.add socks port sock
  
let very_last port _ =
  let sock = sock "very_last" port in
    
  Hsys.close sock ;

  (* Remove sock from table.
   *)
  (try
    Hashtbl.remove socks port
  with Not_found -> failwith "very_last:sanity")

let sockets = Resource.create 
  "IPMC:sockets" 
  very_first 
  very_last
  ignore
  ignore

(**************************************************************)

let first_join (inet,port) () =
  try
    log (fun () -> sprintf "joining:(%s,%d)" (Hsys.string_of_inet inet) port) ;
    Hsys.setsockopt (sock "first_join" port) (Hsys.Join inet)
  with e ->
    eprintf "IPMC:joining multicast group:%s, exiting\n" (Hsys.error e) ;
    eprintf "  (this probably means this host does not support IP multicast)\n" ;
    exit 1

let last_leave (inet,port) _ =
  try
    log (fun () -> sprintf "leaving:(%s,%d)" (Hsys.string_of_inet inet) port) ;
    Hsys.setsockopt (sock "last_leave" port) (Hsys.Leave inet)
  with e ->
    eprintf "IPMC:leaving multicast group:%s\n" (Hsys.error e) ;
    exit 1

(**************************************************************)

let groups = Resource.create 
  "IPMC:groups" 
  first_join 
  last_leave
  ignore
  ignore

let join inet port =
  Resource.add sockets name port () ;
  Resource.add groups name (inet,port) () ;
  sock "join" port

let leave inet port =
  let sock = sock "leave" port in
  Resource.remove groups (inet,port) ;
  Resource.remove sockets port ;
  sock

(**************************************************************)
