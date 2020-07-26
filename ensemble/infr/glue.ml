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
(* GLUE.ML *)
(* Author: Mark Hayden, 10/96 *)
(**************************************************************)
open Util
open Event 
open Layer
open View
(**************************************************************)
let name = Trace.file "GLUE"
let failwith s = Trace.make_failwith name s
(**************************************************************)

(* Called to inject the EInit event into a stack.
 *)
let inject_init debug sched up bot_nomsg =
  (* MH:disabled the sched_enqueue because of race condition
   * with messages coming off of the network.
   *)
  (*Sched.enqueue_2arg sched up (create "init_protocol" EInit[]) bot_nomsg ;*)
  up (create "init_protocol" EInit[]) bot_nomsg ;
 
(**************************************************************)

module type S =
  sig
    type ('state,'a,'b) t
    val convert : ('a,'b,'state) Layer.basic -> ('state,'a,'b) t
    val revert  : ('state,'a,'b) t -> ('a,'b,'state) Layer.basic
    val wrap_msg : ('a -> 'b) -> ('b -> 'a) -> ('c, 'd, 'a) t -> ('c, 'd, 'b) t
    val compose : ('s1,'a,'b) t -> ('s2,'b,'c) t -> ('s1*'s2,'a,'c) t
    type ('state,'top,'bot) init = 
      ('state,'top,'bot) t -> 
      'top -> 'bot ->
      Alarm.t ->
      (Addr.id -> int) ->
      Layer.state ->
      View.full ->
      (Event.up -> unit) -> 
      (Event.dn -> unit)
    val init : ('state,'top,('a,'b,'c)Layer.msg) init
  end

(**************************************************************)

module ImperativeOld : S = struct
  let name = Trace.file "ImperativeOld"
  let failwith s = Trace.make_failwith name s

  type ('s,'a,'b) t = 
    Layer.state ->
    View.full -> 
    Sched.t ->
    (('a,'b) handlers_lout -> ('a,'b) handlers_lin)

  type ('s,'top,'bot) init = 
    ('s,'top,'bot) t -> 
    'top -> 'bot ->
    Alarm.t ->
    (Addr.id -> int) ->
    Layer.state ->
    View.full ->
    (Event.up -> unit) -> 
    (Event.dn -> unit)

  let convert l state vs sched =
    let _,h = l state vs in
    let h out =
      let {up_lin=up;dn_lin=dn} = h out in
      let up ev msg = Sched.enqueue_2arg sched name up ev msg 
      and dn ev msg = Sched.enqueue_2arg sched name dn ev msg in
      {up_lin=up;dn_lin=dn}
    in h

  let revert _ = failwith "revert:not supported"
  let wrap_msg _ = failwith "wrap_msg:not supported"

  let compose top bot state vs sched =
    let l {up_lout=top_up;dn_lout=bot_dn} =
      let mid_dn_r = ref (fun e h -> failwith "compose:sanity") in
      let mid_dn e h = !mid_dn_r e h in

      let {up_lin=mid_up;dn_lin=top_dn} =
	top state vs sched {up_lout=top_up;dn_lout=mid_dn} in
      let {up_lin=bot_up;dn_lin=mid_dn} =
	bot state vs sched {up_lout=mid_up;dn_lout=bot_dn} in

      mid_dn_r := mid_dn ;
      {up_lin=bot_up;dn_lin=top_dn}

    in l

  let init l top_msg bot_nomsg alarm ranking state vs up_out =
    let dn_r = ref (fun _ _ -> failwith "premature event") in
    let dn ev msg = !dn_r ev msg in
    let up ev msg = up_out ev in
    
    let sched = Alarm.sched alarm in
    let {up_lin=up;dn_lin=dn} = l state vs sched {up_lout=up;dn_lout=dn} in
    dn_r := Config_trans.f alarm ranking bot_nomsg vs up ;
    inject_init name sched up bot_nomsg ;
    let dn ev = dn ev top_msg in
    dn
end

(**************************************************************)

module Imperative : S = struct
  let name = Trace.file "Imperative"
  let failwith s = Trace.make_failwith name s

  type ('s,'a,'b) t = 
    Layer.state ->
    View.full -> 
    Sched.t -> 
    (('a,'b) handlers_lout -> ('a,'b) handlers_lin)

  type ('s,'top,'bot) init = 
    ('s,'top,'bot) t -> 
    'top -> 'bot ->
    Alarm.t ->
    (Addr.id -> int) ->
    Layer.state ->
    View.full ->
    (Event.up -> unit) -> 
    (Event.dn -> unit)

  let wrap sched count handler =
    let enqueued ev msg =
      handler ev msg ;
      decr count			(* matched in wrapped *)
    in
    let wrapped ev msg =
      if !count = 0 then (
        incr count ;
        handler ev msg ;
        decr count
      ) else (
        incr count ;			(* matched in enqueued *)
        Sched.enqueue_2arg sched name enqueued ev msg
      )
    in wrapped

  let convert l =
    let count = ref 0 in
    let l state vs sched out =
      let _,h = l state vs in
      let {up_lin=up;dn_lin=dn} = h out in
      let up = wrap sched count up
      and dn = wrap sched count dn in
      {up_lin=up;dn_lin=dn}
    in l

  let revert _ = failwith "revert:not supported"
  let wrap_msg _ = failwith "wrap_msg:not supported"

  let compose_sanity e h = failwith "compose:sanity"

  let compose top bot =
    let l state vs sched {up_lout=top_up;dn_lout=bot_dn} =
      let mid_dn_r = ref compose_sanity in
      let mid_dn e h = !mid_dn_r e h in

      let {up_lin=mid_up;dn_lin=top_dn} =
	top state vs sched {up_lout=top_up;dn_lout=mid_dn} 
      in
      let {up_lin=bot_up;dn_lin=mid_dn} =
	bot state vs sched {up_lout=mid_up;dn_lout=bot_dn} 
      in

      mid_dn_r := mid_dn ;
      {up_lin=bot_up;dn_lin=top_dn}
    in l

  let init l top_msg bot_nomsg alarm ranking state vs up_out =
    let dn_r = ref (fun _ _ -> failwith "premature event") in
    let dn ev msg = !dn_r ev msg in
    let up ev msg = up_out ev in

    let sched = Alarm.sched alarm in
    let {up_lin=up;dn_lin=dn} = l state vs sched {up_lout=up;dn_lout=dn} in
    dn_r := Config_trans.f alarm ranking bot_nomsg vs up ;
    inject_init name sched up bot_nomsg ;
    let dn ev = dn ev top_msg in
    dn
end

(**************************************************************)
(**************************************************************)

let lock_count = ref 0
let thread_create = ref 0
let context_count = ref 0

let stats () =
  eprintf "GLUE:stats\n" ;
  eprintf "  thread_create=%d" !thread_create ;
  eprintf "  lock_count=%d\n" !lock_count ;
  eprintf "  context_count=%d\n" !context_count

(*
module Thread = struct
  type t = Thread.t
  let create f a = 
    incr thread_create ;
    incr context_count ;
    Thread.create f a
  let exit = Thread.exit
  let critical_section = Thread.critical_section
  let self = Thread.self
  let sleep () = 
    incr context_count ;
    Thread.sleep ()
  let wakeup = Thread.wakeup
end

module Mutex = struct
  type t = { mutable locked: bool; mutable waiting: Thread.t list }

  let create () = { locked = false; waiting = [] }

  let rec lock m =
    if m.locked then begin                (* test and set atomic *)
      Thread.critical_section := true;
      m.waiting <- Thread.self() :: m.waiting;
      Thread.sleep();
      lock m
    end else begin
      incr lock_count ;
      m.locked <- true                    (* test and set atomic *)
    end

  let try_lock m =                        (* test and set atomic *)
    if m.locked then false else begin 
      incr lock_count ;
      m.locked <- true; true 
    end

  let unlock m =
    (* Don't play with Thread.critical_section here because of Condition.wait *)
    let w = m.waiting in                  (* atomic *)
    m.waiting <- [];                      (* atomic *)
    m.locked <- false;                    (* atomic *)
    List.iter Thread.wakeup w
end

module Condition = struct
  type t = { mutable waiting: Thread.t list }

  let create () = { waiting = [] }

  let wait cond mut =
    Thread.critical_section := true;
    Mutex.unlock mut;
    cond.waiting <- Thread.self() :: cond.waiting;
    Thread.sleep();
    Mutex.lock mut

  let signal cond =
    match cond.waiting with               (* atomic *)
      [] -> ()
    | th :: rem -> cond.waiting <- rem (* atomic *); Thread.wakeup th

  let broadcast cond =
    let w = cond.waiting in                  (* atomic *)
    cond.waiting <- [];                      (* atomic *)
    List.iter Thread.wakeup w
end
*)
(**************************************************************)
(**************************************************************)
(**************************************************************)

module Threader : S = struct
  let name = Trace.file "Threaded"
  let failwith s = Trace.make_failwith name s

  type ('s,'a,'b) t = 
    Layer.state ->
    View.full -> 
    (('a,'b) handlers_lout -> ('a,'b) handlers_lin)

    type ('s,'top,'bot) init = 
      ('s,'top,'bot) t -> 
      'top -> 'bot ->
      Alarm.t ->
      (Addr.id -> int) ->
      Layer.state ->
      View.full ->
      (Event.up -> unit) -> 
      (Event.dn -> unit)

  let convert l vs = failwith "convert:unimplemented"
  let revert _ = failwith "revert:unimplemented"
  let wrap_msg _ = failwith "wrap_msg:not supported"
  let compose l1 l2 = failwith "compose:unimplemented"
  let init _ _ _ _ _ _ = failwith "init:unimplemented"

(*
  let convert l vs =
    let _,h = l vs in
    let h out =
      let {empty_lin=empty;up_lin=up;dn_lin=dn} = h out in
      let seqno_r = ref 0 in
      let seqno_w = ref 0 in
      let seqno_rl = Mutex.create () in
      let seqno_rc = Condition.create () in
      let seqno_wl = Mutex.create () in

      let insert f =
	Mutex.lock seqno_wl ;
	let seqno = !seqno_w in
	incr seqno_w ;
	Mutex.unlock seqno_wl ;

	let opt = 
	  if Mutex.try_lock seqno_rl then
	    if !seqno_r = seqno then (
	      f () ;
	      incr seqno_r ;
	      Condition.broadcast seqno_rc ;(* Should not be necessary *)
	      Mutex.unlock seqno_rl ;
              true
	    ) else (
	      Mutex.unlock seqno_rl ;
	      false
	    )
	  else false
	in	      
	if not opt then (
	  let spawn () =
	    Mutex.lock seqno_rl ;
	    while !seqno_r <> seqno do
	      Condition.wait seqno_rc seqno_rl
	    done ;
	    f () ;
	    incr seqno_r ;
	    Condition.broadcast seqno_rc ;
	    Mutex.unlock seqno_rl ;
	    Thread.exit ()
	  in
	  Thread.create spawn () ; 
	  ()
	)
      in

      let up ev msg = 
        insert (fun () -> up ev msg)
      and dn ev msg = 
        insert (fun () -> dn ev msg)
      in

      {empty_lin=empty;up_lin=up;dn_lin=dn}
    in h

  let revert _ = failwith "revert:not supported"
  let wrap_msg _ = failwith "wrap_msg:not supported"

  let compose top bot vs =
    let l {empty_lout=top_empty;up_lout=top_up;dn_lout=bot_dn} =
      let mid_dn_r = ref (fun e h -> failwith "compose:sanity") in
      let mid_dn e h = !mid_dn_r e h in

      let {empty_lin=mid_empty;up_lin=mid_up;dn_lin=top_dn} =
	top vs {empty_lout=top_empty;up_lout=top_up;dn_lout=mid_dn} in
      let {empty_lin=bot_empty;up_lin=bot_up;dn_lin=mid_dn} =
	bot vs {empty_lout=mid_empty;up_lout=mid_up;dn_lout=bot_dn} in

      mid_dn_r := mid_dn ;
      {empty_lin=bot_empty;up_lin=bot_up;dn_lin=top_dn}
    in l

  let init l top_msg bot_nomsg sched vs up_out =
    let dn_r = ref (fun _ _ -> failwith "premature event") in
    let dn ev msg = !dn_r ev msg in
    let up ev msg = up_out ev in
    let {up_lin=up;dn_lin=dn} = l vs {empty_lout=top_msg;up_lout=up;dn_lout=dn} in
    dn_r := Config_trans.f bot_nomsg vs up ;
    inject_init name sched up bot_nomsg ;
    let dn ev = dn ev top_msg in
    dn
*)
end

(**************************************************************)

module Functional : S with
  type ('state,'b,'a) t = 
    Layer.state -> 
    View.full -> 
    'state * (('state * ('a,'b) Event.dirm) -> 
              ('state * ('b,'a) Event.dirm Fqueue.t))
= struct
  let name = Trace.file "Functional"
  let failwith = Trace.make_failwith name

  type ('state,'b,'a) t = 
    Layer.state -> 
    View.full -> 
    'state * (('state * ('a,'b) Event.dirm) -> 
              ('state * ('b,'a) Event.dirm Fqueue.t))

  type ('state,'top,'bot) init = 
    ('state,'top,'bot) t -> 
    'top -> 'bot ->
    Alarm.t ->
    (Addr.id -> int) ->
    Layer.state ->
    View.full ->
    (Event.up -> unit) -> 
    (Event.dn -> unit)

  (* For conversion, we need to use imperative queues.
   *)
  let convert l state vs = 
    let q = ref Fqueue.empty in
    let up ev msg = q := Fqueue.add (UpM(ev,msg)) !q in
    let dn ev msg = q := Fqueue.add (DnM(ev,msg)) !q in
    let (s,h) = l state vs in
    let {up_lin=up;dn_lin=dn} =
      h {up_lout=up;dn_lout=dn}
    in
    let hdlr (s,ev) = match ev with
    | UpM(ev,msg) ->
	up ev msg ;
	let evs = !q in
	q := Fqueue.empty ;
	(s,evs)
    | DnM(ev,msg) ->
	dn ev msg ;
	let evs = !q in
	q := Fqueue.empty ;
	(s,evs)
    in (s,hdlr)

  let revert f =
    let b state vf =
      let s,h = f state vf in
      let h {up_lout=up;dn_lout=dn} =
	let emit fq =
	  Fqueue.iter (function
	    | UpM(ev,msg) ->
		up ev msg
	    | DnM(ev,msg) ->
		dn ev msg
	  ) fq
	in
	let up ev msg =
	  let (_,evs) = h (s,(UpM(ev,msg))) in
	  emit evs ;
	and dn ev msg =
	  let (_,evs) = h (s,(DnM(ev,msg))) in
	  emit evs
	in
	{up_lin=up;dn_lin=dn} 
      in 
      (s,h)
    in b

  let wrap_msg compress expand l state vs =
    let (s,h) = l state vs in
    let emit (s,e) = 
      let e = 
	Fqueue.map (function
	  | UpM(ev,msg) -> UpM(ev,msg)
	  | DnM(ev,msg) ->
	      let msg = compress msg in
	      DnM(ev,msg)
	) e
      in
      (s,e)
    in
      
    let h (s,ev) =
      match ev with
      |	UpM(ev,msg) ->
	  let msg = expand msg in
	  emit (h (s,(UpM(ev,msg))))
      |	DnM(ev,msg) ->
	  emit (h (s,(DnM(ev,msg))))
    in
    (s,h)


  (* SPLIT: (up,dn) q adds the up and dn events
   * to the up and dn queues and returns the
   * resulting queues.
   *)
  let split updn b = 
    Fqueue.fold (fun (up,dn) ev ->
      match ev with
      | UpM(ev,msg) -> 
	  let up = Fqueue.add (UpM(ev,msg)) up in
	  (up,dn)
      | DnM(ev,msg) ->
	  let dn = Fqueue.add (DnM(ev,msg)) dn in
	  (up,dn)
    ) updn b

  (* SPLIT_TOP: splits the output events of the
   * upper layer, using the SPLIT function as
   * a helper.
   *)
  let split_top emit_midl q =
    split emit_midl q

  (* SPLIT_BOT: Same as split_top except this is for the
   * bottom layer, so emit and midl get reversed before and
   * after the call to SPLIT.  
   *)
  let split_bot (emit,midl) q = 
    let midl,emit = split (midl,emit) q in
    (emit,midl)

  (* A totally functional layer composition function.
   *)
  let compose top bot state vf =
    (* Initialize the two layers.
     *)
    let s1,top = top state vf in
    let s2,bot = bot state vf in

    let loop (s1,s2) (emit,midl) =
      Fqueue.loop (fun ((s1,s2),emit) midl ev ->
	match ev with
	| UpM(ev,msg) ->
	    let s1,evs = top (s1,UpM(ev,msg)) in
	    let (emit,midl) = split_top (emit,midl) evs in
	    (((s1,s2),emit),midl)
	| DnM(ev,msg) -> 
	    let s2,evs = bot (s2,DnM(ev,msg)) in
	    let (emit,midl) = split_bot (emit,midl) evs in
	    (((s1,s2),emit),midl)
      ) ((s1,s2),emit) midl
    in

    (* Outer handler takes a single event and then passes it to
     * appropriate layer and then splits the emitted events.
     *)
    let hdlr = function
      | ((s1,s2),DnM(ev,msg)) -> 
	  let s1,emitted = top (s1,DnM(ev,msg)) in
	  let (emit,midl) = split_top (Fqueue.empty,Fqueue.empty) emitted in
	  loop (s1,s2) (emit,midl)
      | ((s1,s2),UpM(ev,msg)) -> 
	  let s2,emitted = bot (s2,UpM(ev,msg)) in
	  let (emit,midl) = split_bot (Fqueue.empty,Fqueue.empty) emitted in
	  loop (s1,s2) (emit,midl)
    in
    ((s1,s2),hdlr)

  let init l top_msg bot_nomsg alarm ranking state vf up_out =
    let dn_r = ref (fun _ _ -> failwith "premature event") in
    let dn ev msg = !dn_r ev msg in
    let up ev msg = up_out ev in

    let s,hdlr = l state vf in

    let up ev msg =
      let emit = snd (hdlr (s,(UpM(ev,msg)))) in
      Fqueue.iter (function
	| UpM(ev,msg) -> up ev msg
	| DnM(ev,msg) -> dn ev msg
      ) emit
    and dn ev =
      let emit = snd (hdlr (s,(DnM(ev,top_msg)))) in
      Fqueue.iter (function
	| UpM(ev,msg) -> up ev msg
	| DnM(ev,msg) -> dn ev msg
      ) emit
    in

    let sched = Alarm.sched alarm in
    dn_r := Config_trans.f alarm ranking bot_nomsg vf up ;
    inject_init name sched up bot_nomsg ;
    dn
end

(**************************************************************)
(*
module Functional : S with
  type ('state,'b,'a) t = 
    Layer.state -> 
    View.full -> 
    'state * (('state * ('a,'b) Event.dirm) -> 
              ('state * ('b,'a) Event.dirm Fqueue.t))
= struct
  let name = Trace.file "Functional"

  type ('state,'b,'a) t = 
    Layer.state -> 
    View.full -> 
    'state * (('state * ('a,'b) Event.dirm) -> 
              ('state * ('b,'a) Event.dirm Fqueue.t))

  type ('state,'top,'bot) init = 
    ('state,'top,'bot) t -> 
    'top -> 'bot ->
    Sched.t ->
    Layer.state ->
    View.full ->
    (Event.up -> unit) -> 
    (Event.dn -> unit)

  let convert l state vs = Elink.get Elink.glue_functional_convert name l state vs
  let revert l = Elink.get Elink.glue_functional_revert name l
  let wrap_msg a b c = Elink.get Elink.glue_functional_wrap_msg name a b c
  let compose a b = Elink.get Elink.glue_functional_compose name a b
  let init a b c d e f g = Elink.get Elink.glue_functional_compose name a b c d e f g
end
*)
(**************************************************************)

type glue = 
  | Imperative 
  | Functional
  | Threaded

type ('s,'a,'b) t =
  | Imp of ('s,'a,'b) Imperative.t
  | Fun of ('s,'a,'b) Functional.t
  | Thr of ('s,'a,'b) Threader.t

type ('s,'top,'bot) init = 
    ('s,'top,'bot) t -> 
      'top -> 'bot ->
        Alarm.t ->
	 (Addr.id -> int) ->
	  Layer.state ->
	    View.full ->
	      (Event.up -> unit) -> 
		(Event.dn -> unit)
	      
let of_string s = 
  match String.uppercase s with
  | "IMPERATIVE" -> Imperative
  | "FUNCTIONAL" -> Functional
  | "THREADED" -> Threaded
  | _ -> failwith "glue_of_string:unknown glue"

let convert g l =
  match g with
  | Imperative -> Imp (Imperative.convert l)
  | Functional -> Fun (Functional.convert l)
  | Threaded   -> Thr (Threader  .convert l)

let compose l1 l2 = match l1,l2 with
| Imp(l1),Imp(l2) -> Imp(Imperative.compose l1 l2)
| Fun(l1),Fun(l2) -> Fun(Functional.compose l1 l2)
| Thr(l1),Thr(l2) -> Thr(Threader  .compose l1 l2)
| _,_ -> failwith "mismatched layers"

(* We take all the arguments first in order to prevent
 * unnecessary currying.
 *)
let init a b c d e f g h = match a with
| Imp(l) -> Imperative.init l b c d e f g h
| Fun(l) -> Functional.init l b c d e f g h
| Thr(l) -> Threader  .init l b c d e f g h

(**************************************************************)
(**************************************************************)
