(**************************************************************)
(* APPL_COMPAT.ML: conversion from old to new interfaces *)
(* Author: Mark Hayden, 12/98 *)
(**************************************************************)
open Appl_intf open New
open Util
open View
(**************************************************************)
let name = Trace.file "APPL_COMPAT"
let failwith s = Trace.make_failwith name s
let log = Trace.log name
(**************************************************************)

let make_marsh name =
  Iovecl.make_marsh name

type ('a,'b) header = ('a,'b) appl_compat_header

let string_of_header = function
  | TCast _ -> "TCast(_)"
  | TSend _ -> "TSend(_)"
  | TMerge -> "TMerge()"
  | TView -> "TView()"

(**************************************************************)

let problem cs bk origin msg =
  log (fun () -> sprintf "cs=%s, bk=%s, origin=%d, hdr=%s"
      (string_of_cs cs) (string_of_blocked bk) origin (string_of_header (fst msg))) ;
  failwith "compat:do_receive:sanity"

let gencompat splitcast combcast splitsend combsend 
    merge_ma merge_um view_ma view_um copier intf =
  let debug = "APPL_INTF.New.gencompat" in
  let al = action_array_map splitcast splitsend in
  let marsh,unmarsh = make_marsh debug in

  let install (ls,vs) =
    let xfering = ref true in
    let delayed = Queuee.create () in
    let delayed = delayed in

    let do_receive cs bk origin =
      let recv_cast = intf.Old.recv_cast in
      let recv_send = intf.Old.recv_send in
      let block_recv_cast = intf.Old.block_recv_cast in
      let block_recv_send = intf.Old.block_recv_send in

      (* This is yucky.  I'll be happy when we can do array
       * with the old interface.
       *)

      (* Interesting combinations:
       * C,B,TView happens with totally ordered protocol stacks.
       * S,B,TMerge happens when there are more merge messages than necessary. 
       *)
      match cs,bk with
      |	C,U -> (function
	  | TCast m,iov -> al (recv_cast origin (combcast m iov))
	  | TView,_ -> [||]
	  | msg -> problem cs bk origin msg
	)

      |	S,U -> (function
	  | TSend m,iov -> al (recv_send origin (combsend m iov))
	  | TMerge,_ -> [||]
	  | msg -> problem cs bk origin  msg
	)

      |	C,B -> (function
	  | TCast m ,iov -> block_recv_cast origin (combcast m iov) ; [||]
	  | TView,_ -> [||]
	  | msg -> problem cs bk origin  msg
	)

      |	S,B -> (function
	  | TSend m,iov -> block_recv_send origin (combsend m iov) ; [||]
	  | TMerge,_ -> [||]
	  | msg -> problem cs bk origin  msg
	)
    
    in

    let do_delayed () =
      let delayed = 
	let tmp = Queuee.to_list delayed in
      	Queuee.clear delayed ;
	tmp
      in

      let actions =
 	List.map (fun (cs,mk,origin,msg) ->
	  do_receive cs mk origin msg
	) delayed
      in
      Array.concat actions
    in
    
    let check_merge =
      let merging = Array.create ls.nmembers None in
      fun add ->
	List.iter (fun (rank,info) ->
	  merging.(rank) <- Some(info)
	) add ;
	if not (array_mem None merging) then (
	  let merge_save = merging in
	  let merging = Array.to_list merging in
	  let merging = List.map (some_of name) merging in
	  for i = 0 to pred ls.nmembers do merge_save.(i) <- None done ;
	  let view = intf.Old.block_install_view (ls,vs) merging in
	  let view_local = copier view in
	  let actions = intf.Old.unblock_view (ls,vs) view_local in
	  let view = view_ma view in
	  xfering := false ;
	  Array.append [|Cast(TView,view)|] (al actions)
	) else [||]
    in

    let heartbeat time =
      if not !xfering then
	al (intf.Old.heartbeat time)
      else [||]
    in

    let block () =
      al (intf.Old.block ())
    in

    let receive origin bk cs msg =
      if not !xfering then (
   	do_receive cs bk origin msg
      ) else if bk = U then (
      	match msg with
      	| TMerge,iovl -> 
	    if ls.rank <> 0 then failwith sanity ;
	    let states = unmarsh iovl in
	    let states = 
	      List.map (fun (rank,state) -> 
		let state = Iovec.of_string debug state in
		let statei = Iovecl.of_iovec debug state in
		let state = merge_um statei in
	        Iovecl.free debug statei ;
		(rank,state)
	      ) states 
	    in
	    check_merge states
	| TView,view ->
	    let view = view_um view in
	    let actions = al (intf.Old.unblock_view (ls,vs) view) in
	    xfering := false ;
 	    Array.append actions (do_delayed ())
	| (TCast _,_ | TSend _,_) as m ->
	    Queuee.add (cs,bk,origin,m) delayed ; [||]
      ) else (
	[||]
      )
    in
    
    let merge = intf.Old.block_view (ls,vs) in
    let actions = 
      if ls.rank = 0 then (
	check_merge merge
      ) else (
	let states =
	  List.map (fun (rank,state) -> 
	    let iovl = merge_ma state in
	    let iov = Iovecl.flatten debug iovl in
	    let state = Iovec.to_string debug iov in
	    Iovecl.free debug iovl ;
	    Iovec.free debug iov ;
	    (rank,state)
	  ) merge in
	let states = marsh states in
      	[|Send([|0|],(TMerge,states))|]
      )
    in

    actions,{
		  flow_block = (fun _ -> ()) ; (* Old is not aware of this feature *)
      heartbeat = heartbeat ;
      receive = receive ;
      block = block ;
      disable = Util.ident
    } 

  in
    
  let exit () = intf.Old.exit () in

  { heartbeat_rate = intf.Old.heartbeat_rate ;
    install = install ;
    exit = exit }

(**************************************************************)

let pcompat intf =
  let merge_ma,merge_um = Iovecl.make_marsh "APPL_INTF.New.compat(merge)" in
  let view_ma,view_um = Iovecl.make_marsh "APPL_INTF.New.compat(view)" in
  let splitcast (m,iov) = TCast(m),iov in
  let splitsend (m,iov) = TSend(m),iov in
  let combcast m iov = (m,iov) in
  let combsend m iov = (m,iov) in
  let copier = ident in
  gencompat splitcast combcast splitsend combsend 
    merge_ma merge_um view_ma view_um copier intf

let compat intf =
  let splitcast iov = TCast(),iov in
  let splitsend iov = TSend(),iov in
  let combcast () iov = iov in
  let combsend () iov = iov in
  let copier iov = Iovecl.copy name iov in
  gencompat splitcast combcast splitsend combsend ident ident ident ident copier intf

let _ =
  Elink.put Elink.appl_compat_compat compat ;
  Elink.put Elink.appl_compat_pcompat pcompat
