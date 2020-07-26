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
(* APPL_INTF.ML: application interface *)
(* Author: Mark Hayden, 8/95 *)
(* See documentation for a description of this interface *)
(**************************************************************)
open Trans
open Util
open View
(**************************************************************)
let name = Trace.file "APPL_INTF"
let failwith s = Trace.make_failwith2 name s
let log = Trace.log name
(**************************************************************)

(* Some type aliases.
 *)
type dests = rank array

(**************************************************************)

type control =
  | Leave
  | Prompt
  | Suspect of rank list

  | XferDone
  | Rekey of bool 
  | Protocol of Proto.id
  | Migrate of Addr.set
  | Timeout of Time.t

  | Dump
  | Block of bool
  | No_op


type ('cast_msg,'send_msg) action =
  | Cast of 'cast_msg
  | Send of dests * 'send_msg
  | Send1 of rank * 'send_msg
  | Control of control

(**************************************************************)

let string_of_control = Trace.debug "" (function
  | Suspect sus -> sprintf "Suspect(%s)" (string_of_int_list sus)
  | Protocol p -> sprintf "Protocol(_)"
  | Block b -> sprintf "Block(%b)" b
  | Migrate _ -> sprintf "Migrate(_)"
  | Timeout _ -> sprintf "Timeout(_)"
  | Leave -> "Leave"
  | Prompt -> "Prompt"
  | Dump -> "Dump"
  | Rekey _ -> "Rekey(_)"
  | XferDone -> "XferDone"
  | No_op -> "No_op"
)

let string_of_action = function
  | Cast _ -> sprintf "Cast(_)"
  | Send(dest,_) -> sprintf "Send(%s,_)" (string_of_int_array dest)
  | Send1(dest,_) -> sprintf "Send1(%d,_)" dest
  | Control c ->
      sprintf "Control(%s)" (string_of_control c)

(**************************************************************)

let action_map fc fs = function
  | Cast m -> Cast(fc m)
  | Send(d,m) -> Send(d,(fs m))
  | Send1(d,m) -> Send1(d,(fs m))
  | Control o -> Control o

let action_array_map fc fs = Array.map (action_map fc fs)

(**************************************************************)

module Old = struct

(* APPL_INTF.T: The record interface for applications.  An
 * application must define all the following callbacks and
 * put them in a record.
 *)

type (
  'cast_msg,
  'send_msg,
  'merg_msg,
  'view_msg
) full = {

  recv_cast 		: origin -> 'cast_msg ->
    ('cast_msg,'send_msg) action array ;

  recv_send 		: origin -> 'send_msg ->
    ('cast_msg,'send_msg) action array ;

  heartbeat_rate	: Time.t ;

  heartbeat 		: Time.t ->
    ('cast_msg,'send_msg) action array ;

  block 		: unit ->
    ('cast_msg,'send_msg) action array ;

  block_recv_cast 	: origin -> 'cast_msg -> unit ;
  block_recv_send 	: origin -> 'send_msg -> unit ;
  block_view            : View.full -> (rank * 'merg_msg) list ;
  block_install_view    : View.full -> 'merg_msg list -> 'view_msg ;
  unblock_view 		: View.full -> 'view_msg ->
    ('cast_msg,'send_msg) action array ;

  exit 			: unit -> unit
}

type iov = (Iovec.t, Iovec.t, Iovec.t, Iovec.t) full

type iovl = (Iovecl.t, Iovecl.t, Iovecl.t, Iovecl.t) full

type ('a,'b,'c,'d) power = ('a * Iovecl.t, 'b * Iovecl.t,'c,'d) full

type t = iovl

let iovl = ident

end

(**************************************************************)

module New = struct

let null _ = [||]

type cast_or_send = C | S

type blocked = U | B

type 'msg naction = ('msg,'msg) action

type 'msg handlers = {
  flow_block : rank option * bool -> unit ;
  block : unit -> 'msg naction array ;
  heartbeat : Time.t -> 'msg naction array ;
  receive : origin -> blocked -> cast_or_send -> 'msg -> 'msg naction array ;
  disable : unit -> unit
} 

type 'msg full = {
  heartbeat_rate : Time.t ;
  install : View.full -> ('msg naction array) * ('msg handlers) ;
  exit : unit -> unit
} 

type t = Iovecl.t full

type 'msg power = ('msg * Iovecl.t) full

(**************************************************************)

let string_of_cs = function C -> "C" | S ->"S"
let string_of_blocked = function B -> "B" | U -> "U"

(**************************************************************)

let failed1 _ = failwith sanity
let failed4 _ _ _ _ = failwith sanity
let failed_handlers = {
  flow_block = failed1 ;
  heartbeat = failed1 ;
  receive = failed4 ;
  block = failed1 ;
  disable = failed1
} 

let full i =
  let ma,um = Iovecl.make_marsh (info name "new:full") in
  let ta = action_array_map ma ma in

  let install vf =
    let actions,handlers = i.install vf in
    let actions = ta actions in
    let receive o b cs =
      let receive = handlers.receive o b cs in
      fun m -> ta (receive (um m))
    in
    
    let block () =
      ta (handlers.block ())
    in

    let heartbeat t =
      ta (handlers.heartbeat t)
    in

    let handlers = { 
      flow_block = handlers.flow_block;
      heartbeat = heartbeat ;
      receive = receive ;
      block = block ;
      disable = handlers.disable
    } in
    
    actions,handlers
  in 
  
  { heartbeat_rate = i.heartbeat_rate ;
    install = install ;
    exit = i.exit }
end

(* These are put here for dynamic linking reasons.
 *)
type ('a,'b) appl_compat_header =
  | TCast of 'a
  | TSend of 'b
  | TMerge
  | TView

type appl_lwe_header =
  | LCast of origin
  | LSend of origin * rank array

type appl_multi_header = int

module Protosi = struct
  open New
  type id = int
  type 'a dncall_gen = ('a,'a) action

  (* For Receive, remember that the protocol server
   * doesn't know we are blocked until it gets the
   * Block(true) from us.   So we don't put the blocked
   * stuff in there.
   *)

  type 'a upcall_gen = 
    | UInstall of View.full
    | UReceive of origin * cast_or_send * 'a
    | UHeartbeat of Time.t
    | UBlock
    | UExit

  type endpt = string

  type 'a message_gen =
    | Create of id * View.state * Time.t * (Addr.id list)
    | Upcall of id * 'a upcall_gen
    | Dncall of id * ltime * 'a dncall_gen
    | SendEndpt of id * ltime * endpt * 'a
    | SuspectEndpts of id * ltime * endpt list

  type message = Iovecl.t message_gen
  type dncall = Iovecl.t dncall_gen
  type upcall = Iovecl.t upcall_gen
end

(**************************************************************)
