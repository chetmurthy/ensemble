(**************************************************************)
(*
 *  Ensemble, (Version 1.00)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
(**************************************************************)
(* ACTUAL.ML *)
(* Author: Mark Hayden, 11/96 *)
(* Designed with Roy Friedman *)
(**************************************************************)
(* BUGS:
 
 *  Orders members in views lexicographicly

 *)
(**************************************************************)
open Trans
open Util
open View
open Mutil
open Appl_intf open Old
(**************************************************************)
let name = Trace.file "ACTUAL"
let failwith s = Trace.make_failwith name s
let log = Trace.log name
(**************************************************************)

let list_split4 l =
  List.fold_left (fun (la,lb,lc,ld) (a,b,c,d) ->
    (a::la,b::lb,c::lc,d::ld)
  ) ([],[],[],[]) l

let list_join l =
  let l = Lset.sort l in
  let l = 
    List.fold_left (fun cur (k,d) ->
      match cur with
      | [] -> [k,[d]]
      | (k',l) :: tl ->
          if k = k' then 
            (k',(d::l)) :: tl
          else
            (k,[d]) :: cur
    ) [] l
  in
  l

(**************************************************************)

type 'g message = 
  | ToCoord of group * endpt * rank(*of coord*) * member_msg
  | ToMembers of group * coord_msg
  | Announce of group * 'g
  | Destroy of group

type ('m,'g) t = {
  async : unit -> unit ;
  mutable ls : View.local ;
  mutable vs : View.state ;
  mutable announce : (group -> 'g -> unit) option ; (* hack! *)
  mutable blocking : bool ;
  ops : ('g message,'g message) Appl_intf.action Queuee.t ;
  members : (group, Member.t list) Hashtbl.t ;
  coords : (group, Coord.t) Hashtbl.t ;
  groups : (group, 'g) Hashtbl.t
}

(**************************************************************)
(**************************************************************)

let string_of_msg = function
  | ToMembers(_,msg) ->
      let msg = string_of_coord_msg msg in
      sprintf "ToMembers(%s)" msg
  | ToCoord(_,_,rank,msg) -> 
      let msg = string_of_member_msg msg in
      sprintf "ToCoord(%s)" msg
  | Announce _ -> "Announce"
  | Destroy _ -> "Destroy"

(**************************************************************)
(**************************************************************)

let coord s group f =
  let coord = 
    try Hashtbl.find s.coords group with Not_found ->
(*
      if s.vs.rank <> 0 then 
        failwith "non-coord is default" ;
*)
      let cast msg =
	if not (s.blocking) then (
	  log (fun () -> sprintf "coord:cast:%s" (string_of_coord_msg msg)) ;
	  let msg = ToMembers(group,msg) in
	  Queuee.add (Cast msg) s.ops ;
	  s.async ()
	)
      in

      let coord = Coord.create s.vs.primary cast in
      Hashtbl.add s.coords group coord ;
      coord
  in
  f coord
  
let members s group f = 
  let members = 
    try Hashtbl.find s.members group
    with Not_found -> []
  in List.iter f members

(**************************************************************)

let join s group endpt ltime to_client =
  (* BUG: there is a dependency below on having the coordinator
   * manage all the groups.
   *)
  let coord = 0 in

  let to_coord msg =
    let msg = ToCoord(group,endpt,coord,msg) in
    Queuee.add (Send([|coord|],msg)) s.ops ;        (*BUG:PERF*)(* CAREFUL!! *)
    s.async ()
  in

  let disable () =
    log (fun () -> sprintf "disable:removing member") ;
    let members = 
      try Hashtbl.find s.members group with Not_found ->
	eprintf "ACTUAL:join:disable:uncaught Not_found\n" ;
	exit 1
    in
    Hashtbl.remove s.members group ;
    let members = List.filter (fun m -> Member.endpt m <> endpt) members in
    Hashtbl.add s.members group members ;
  in
  
  let m = Member.create endpt to_client to_coord disable coord ltime in
  
  let members =
    try 
      let ret = Hashtbl.find s.members group in
      Hashtbl.remove s.members group ;
      ret
    with Not_found -> []
  in
  let members = m :: members in
  Hashtbl.add s.members group members ;
  log (fun () -> sprintf "#groups=%d" (hashtbl_size s.members)) ;
  Member.receive_client m
  
(**************************************************************)
  
let create alarm (ls_init,vs_init) =
  Util.disable_sigpipe () ;
  
  (* Ensure that we are using Total protocol.
   * Need local delivery.
   *)
  let properties = 
(*
    if vs_init.groupd then
      Property.Total :: Property.fifo
    else
*)
      Property.Total :: Property.vsync
  in

  let vs_init = View.set vs_init [
    Vs_groupd false ;
    Vs_proto_id (Property.choose properties)
  ] in
  let ls_init = View.local name ls_init.endpt vs_init in
  
  (* Create the state of the group.
   *)
  let s = {
    vs = vs_init ;
    ls = ls_init ;
    announce = None ;
    async = Async.find (Alarm.async alarm) (vs_init.group,ls_init.endpt) ;
    blocking = true ;
    ops = Queuee.create () ;
    coords = Hashtbl.create 10 ;
    members = Hashtbl.create 10 ;
    groups = Hashtbl.create 10
  } in
  
  let announce group prop =
    try 
      (* BUG: should check that properties are the same. *)
      Hashtbl.find s.groups group ; ()
    with Not_found ->
      Hashtbl.add s.groups group prop ;
      if_some s.announce (fun handler ->
        handler group prop
      ) 
  in

  (* Handle a message receipt.
   *)
  let handle_msg msg = 
(*
    eprintf "got:%s\n" (string_of_msg msg) ;
*)
    match msg with
    | Announce(group,prop) ->
        announce group prop
    | Destroy(group) ->
        (try Hashtbl.remove s.groups group with Not_found -> ())
    | ToMembers(group,msg) ->
        (* Just pass message directly to the member.
         *)
        members s group (fun m -> Member.receive_coord m msg)
    | ToCoord(group,endpt,rank,msg) ->
        (* Only handle message if I'm the requested rank.
         *)
        if s.ls.rank = rank then
          coord s group (fun c -> Coord.receive c (endpt,msg))
  in

  let clean_ops () =
    let msgs = Queuee.to_list s.ops in
    Queuee.clear s.ops ;
    Array.of_list msgs
  in
  
  let recv_cast _ msg       = handle_msg msg ; clean_ops ()
  and recv_send _ msg       = handle_msg msg ; clean_ops ()
  and block ()              =
    s.blocking <- true ;
    clean_ops ()
  and heartbeat time        =                  clean_ops ()
  and block_recv_cast _ msg = handle_msg msg
  and block_recv_send _ msg = handle_msg msg
    
  and block_view (ls,vs) =
    (* Remove all membership messages from the send
     * queue.  The data we're sending now should replace them.
     * We leave in failure notifications, however.
     *)
    let l = Queuee.to_list s.ops in
    let l = List.filter (fun msg -> 
      match msg with
      |	Cast(ToCoord(_,_,_,Fail(_))) -> true
      |	Send(_,ToCoord(_,_,_,Fail(_))) -> true

      | Cast(ToCoord _) | Cast(ToMembers _)
      | Send(_,ToCoord _) | Send(_,ToMembers _) -> false
      | _ -> true
    ) l in
    Queuee.clear s.ops ;
    List.iter (fun m -> Queuee.add m s.ops) l ;

    let members = hashtbl_to_list s.members in
    let members = 
      List.map (fun (group,members) ->
        let members = List.map (fun m -> Member.summary m) members in
        (group, members)
      ) members
    in

    (* Collect all the group properties.
     *)
    let groups = hashtbl_to_list s.groups in
    let groups = Lset.sort groups in

    [ls.rank, (members, groups)]

  and block_install_view (ls,vs) comb =
    let (members,groups) = List.split comb in

    (* Merge, sort, & organize the group information.
     *)
    let members = List.flatten members in
    let members = 
      List.map (fun (group,members) -> 
        List.map (fun member -> group,member) members
      ) members 
    in
    let members = List.flatten members in
    let members = list_join members in

    (* Combine all the groups' property lists.
     *)
    let groups = List.fold_right Lset.union groups [] in

    (members,groups)

  and unblock_view (ls,vs) (info,groups) =
    s.ls <- ls ;
    s.vs <- vs ;
    s.blocking <- false ;
    if not !quiet then
      eprintf "ACTUAL:view:%d:%s\n" ls.nmembers (View.to_string s.vs.view) ;

    (* Strip all groups from the table.
     *)
    Hashtbl.clear s.coords ;
    (*hashtbl_clean s.coords ;*)

    (* Reconstruct coordinators.
     *)
    List.iter (fun (group,members) ->
      if ls.rank = 0 then (
        coord s group (fun c -> 
          let lists = list_split4 members in
          Coord.reconstruct c vs.primary lists ; ()
        )
      )
    ) info ;

    List.iter (fun (group,prop) ->
      announce group prop ; ()
    ) groups ;

    clean_ops ()
  and exit () = () in

  let interface = {
    recv_cast           = recv_cast ;
    recv_send           = recv_send ;
    heartbeat           = heartbeat ;
    heartbeat_rate      = Time.of_float 
(*      (if Arge.get Arge.aggregate then 0.05 else 10.0) ;*)10.0(* BUG *) ;
    block               = block ;
    block_recv_cast     = block_recv_cast ;
    block_recv_send     = block_recv_send ;
    block_view          = block_view ;
    block_install_view  = block_install_view ;
    unblock_view        = unblock_view ;
    exit                = exit
  } in

  let interface = Appl_old.full interface in
(*
  let interface =
    if Arge.get Arge.aggregate then aggr interface else full interface
  in
*)
  
  (s,(ls_init,vs_init(* BUG? *)),interface)
  
let set_properties s member handler =
  s.announce <- Some handler ;
  ()
  
let announce s group filter properties =
  let msg = Announce(group,properties) in
  Queuee.add (Cast msg) s.ops ;
  s.async ()
  
let destroy s group =
  let msg = Destroy(group) in
  Queuee.add (Cast msg) s.ops ;
  s.async
 ()
  
(**************************************************************)
