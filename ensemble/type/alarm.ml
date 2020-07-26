(**************************************************************)
(*
 *  Ensemble, 1.10
 *  Copyright 2001 Cornell University, Hebrew University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
(**************************************************************)
(* ALARM.ML *)
(* Author: Mark Hayden, 4/96 *)
(**************************************************************)
open Util
open Trans
(**************************************************************)
let name = Trace.file "ALARM"
let failwith s = Trace.make_failwith name s
(**************************************************************)

type gorp = Unique.t * Sched.t * Async.t * Route.handlers * Mbuf.t

type alarm = {
  disable : unit -> unit ;
  schedule : Time.t -> unit
}

type poll_type = SocksPolls | OnlyPolls

type t = {
  name		: string ;		(* name *)
  gettime	: unit -> Time.t ;	(* get current time *)
  alarm		: (Time.t -> unit) -> alarm ;
  check		: unit -> bool ;	(* check the timers *)
  min		: unit -> Time.t ;	(* get next timer *)
  add_sock_recv	: debug -> Hsys.socket -> Hsys.handler -> unit ;
  rmv_sock_recv	: Hsys.socket -> unit ;
  add_sock_xmit : debug -> Hsys.socket -> (unit->unit) -> unit ;
  rmv_sock_xmit : Hsys.socket -> unit ;
  block		: unit -> unit ;	(* block until next alarm *)
  add_poll	: debug -> (bool -> bool) -> unit ;
  rmv_poll	: debug -> unit ;
  poll		: poll_type -> unit -> bool ;
  handlers      : Route.handlers ;
  mbuf          : Mbuf.t ;
  sched         : Sched.t ;
  unique        : Unique.t ;
  async         : Async.t ;
  local_xmits   : Route.xmits
}

(**************************************************************)

let local_xmits sched handlers mbuf debug =
  let debug = Refcnt.info2 name "local" debug in
  let debug1 = Refcnt.info2 name "local(xv)" debug in
  let debug2 = Refcnt.info2 name "local(xsv)" debug in
  let x buf ofs len =
    let iov = Mbuf.alloc debug mbuf buf ofs len in
    Sched.enqueue_2arg sched debug Route.deliver_iov handlers iov
  and xv iovl =
    let iovl = Iovecl.take debug1 iovl in
    Sched.enqueue_3arg sched debug1 Route.deliver_iovl handlers mbuf iovl
  and xsv iovl s =
    let iovl = Iovecl.take debug2 iovl in
    let slen = Buf.length s in
    let iovs = Mbuf.alloc debug2 mbuf s Buf.len0 slen in
    let iovl = Iovecl.appendi debug2 iovl iovs in
    Sched.enqueue_3arg sched debug2 Route.deliver_iovl handlers mbuf iovl
  in
  (x,xv,xsv)

(**************************************************************)

let c_alarm dis sch = {
  disable = dis ;
  schedule = sch
}

let disable a = a.disable ()
let schedule a = a.schedule

let create
  name
  gettime
  alarm
  check
  min
  add_sock_recv
  rmv_sock_recv
  add_sock_xmit
  rmv_sock_xmit
  block
  add_poll
  rmv_poll
  poll
  (unique,sched,async,handlers,mbuf)
= {
    name	= name ;
    gettime     = gettime ;
    check       = check ;
    alarm       = alarm ;
    min         = min ;
    add_sock_recv = add_sock_recv ;
    rmv_sock_recv = rmv_sock_recv ;
    add_sock_xmit = add_sock_xmit ;
    rmv_sock_xmit = rmv_sock_xmit ;
    add_poll	= add_poll ;
    rmv_poll	= rmv_poll ;
    poll	= poll ;
    block	= block ;
    handlers    = handlers ;
    sched       = sched ;
    mbuf        = mbuf ;
    async       = async ;
    unique      = unique ;
    local_xmits = (local_xmits sched handlers mbuf name)
  }

(**************************************************************)

let gettime t = t.gettime ()
let alarm t = t.alarm
let check t = t.check
let min t = t.min ()
let add_sock_recv t = t.add_sock_recv
let rmv_sock_recv t = t.rmv_sock_recv
let add_sock_xmit t = t.add_sock_xmit
let rmv_sock_xmit t = t.rmv_sock_xmit
let block t = t.block ()
let add_poll t = t.add_poll
let rmv_poll t = t.rmv_poll
let poll t = t.poll
let name t = t.name
let handlers t = t.handlers
let sched t = t.sched
let mbuf t = t.mbuf
let unique t = t.unique
let async t = t.async
let local_xmits t = t.local_xmits

(**************************************************************)

let poll_f = ref None

let update_polls polls =
  let pa = Resource.to_array polls in
  let n = Arrayf.length pa in
  match n with
  | 0 -> poll_f := None
  | 1 -> poll_f := Some (Arrayf.get pa 0)
  | 2 ->
      let p0 = Arrayf.get pa 0 in
      let p1 = Arrayf.get pa 1 in
      poll_f := Some (fun b -> p1 (p0 b))
  | 3 ->
      let p0 = Arrayf.get pa 0 in
      let p1 = Arrayf.get pa 1 in
      let p2 = Arrayf.get pa 2 in
      poll_f := Some (fun b -> p2 (p1 (p0 b)))
  | _ ->
      let rec loop i rm =
	if i >= n then rm else (
	  loop (succ i) ((Arrayf.get pa i) rm)
        ) 
      in
      poll_f := Some (fun b -> loop 0 b)

let polls =
  Resource.create "ALARM:polls" 
    ignore2
    ignore2
    update_polls
    ignore

let alm_add_poll name poll = 
  Resource.add polls name name poll ;
  !poll_f

let alm_rmv_poll name =
  Resource.remove polls name ;
  !poll_f

(*
let alm_poll b = 
  match !poll_f with
  | Some f -> f b
  | None -> b
*)

(**************************************************************)

(* For bypass stuff.
 *)
let wrap wrapper alarm =
  let enable callback =
    alarm.alarm (wrapper callback)
  in { alarm with alarm = enable }

(**************************************************************)
