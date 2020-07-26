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
(* CONN.ML : communication connection ids *)
(* Author: Mark Hayden, 12/95 *)
(**************************************************************)
open Util
open Trans
(**************************************************************)
let name = Trace.file "CONN"
let failwith = Trace.make_failwith name
(**************************************************************)

type sndr_mbr = rank			(* for members *)
type dest_mbr = rank			(* for members *)
type dest_endpt = Endpt.id		(* for merging *)

(**************************************************************)

type id = {
  version       : Version.id ;
  group 	: Group.id ;
  stack 	: Stack_id.t ;
  proto 	: Proto.id option ;
  view_id 	: View.id option ;
  sndr_mbr 	: sndr_mbr ;
  dest_mbr 	: dest_mbr ;
  dest_endpt 	: dest_endpt option
}

(* This should uniquely specify a connection set.
 * The fields are ordered so that the hashing is
 * effective.
 *)
type key = {
  key_version  : Version.id ;
  key_endpt    : Endpt.id ;
  key_group    : Group.id ;
  key_stack    : Stack_id.t ;
  key_proto    : Proto.id ;
  key_view_id  : View.id
} 

type t = {
  key     	: key ;
  my_rank       : Trans.rank ;
  nmembers      : Trans.nmembers
}

type kind = Cast | Send | Other

type recv_info = id * kind * Trans.rank

(**************************************************************)

let string_of_kind = function
| Cast -> "Cast"
| Send -> "Send"
| Other -> "Other"

(**************************************************************)

let int_of_mbr = function
| Some mbr ->
    if mbr = -1 then failwith sanity ;
    mbr
| None -> (-1)

(**************************************************************)

let mbr_of_int = function
| -1 -> None
|  i -> Some i

(**************************************************************)

let squash_sender id = 
  let sender = mbr_of_int id.sndr_mbr in
  let id = { id with sndr_mbr = -2 (* hack! (should be -2) *) } in
  (sender,id)

(**************************************************************)

let no_sharing = [Marshal.No_sharing]

(* When digesting the marshalled object, we can skip
 * the marshalling header.
 *)
let hash_of_id id =
  let id = Marshal.to_string id no_sharing in
  let len = String.length id in
  Buf.digest_substring id Marshal.header_size (len - Marshal.header_size)

(**************************************************************)

let string_of_id = Trace.debug "" (fun id ->
  let (view_id,sndr_mbr,dest_mbr,dest_endpt) =
    id.view_id,id.sndr_mbr,id.dest_mbr,id.dest_endpt
  in
  let kind = match id.view_id,mbr_of_int id.sndr_mbr,mbr_of_int id.dest_mbr,id.dest_endpt with
    | Some _, Some _, Some _, None   -> "Pt2pt"
    | Some _, Some _, None  , None   -> "Cast"
    | Some _, None  , None  , Some _ -> "Merge"
    | None  , None  , None  , None   -> "Gossip"
    | _ -> "?" 
  in
  sprintf "{Conn:%s:%s:%s:%s:%s:from=%s:to=%s/%s:hash=%s}"
    kind
    (Group.string_of_id id.group)
    (Stack_id.string_of_id id.stack)
    (string_of_option Proto.string_of_id id.proto)
    (string_of_option View.string_of_id id.view_id)
    (string_of_option string_of_int (mbr_of_int id.sndr_mbr))
    (string_of_option string_of_int (mbr_of_int id.dest_mbr))
    (string_of_option Endpt.string_of_id id.dest_endpt)
    (Buf.to_hex (hash_of_id id))
)

(**************************************************************)
(*
let string_of_key key =
  sprintf "{Conn.t.id:ver=%s;endpt=%s;group=%s;view_id=%s;stack=%s;proto=%s}" 
    (Version.string_of_id key.key_version)
    (Endpt.string_of_id key.key_endpt)
    (Group.string_of_id key.key_group)
    (View.string_of_id key.key_view_id)
    (Stack_id.string_of_id key.key_stack)
    (string_of_option Proto.string_of_id key.key_proto)

let string_of_t t = string_of_key t.key
*)
(**************************************************************)
(* Create a record of connections for an id & view.
 *)

let create rank version group view_id stack_id proto_id view =
  let nmembers = Arrayf.length view in
  let endpt = Arrayf.get view rank in

  let key = {
    key_endpt = endpt ;
    key_stack = stack_id ;
    key_group = group ;
    key_version = version ;
    key_view_id = view_id ;
    key_proto = proto_id
  } in

  {
    key		= key ;
    my_rank     = rank ;
    nmembers    = nmembers
  }

(**************************************************************)

let id version group stack proto view_id sndr_mbr dest_mbr dest_endpt = {  
  version       = version ;
  group 	= group ;
  stack 	= stack ;
  proto 	= proto ;
  view_id 	= view_id ;
  sndr_mbr 	= int_of_mbr sndr_mbr ;
  dest_mbr 	= int_of_mbr dest_mbr ;
  dest_endpt	= dest_endpt
}

let idgen t a b c d e =
  let i = t.key in
  id i.key_version i.key_group i.key_stack a b c d e 

let merge_recv t =
  idgen t (Some t.key.key_proto) (Some t.key.key_view_id) None None (Some t.key.key_endpt)
let multi_recv t rank =
  idgen t (Some t.key.key_proto) (Some t.key.key_view_id) (Some rank) None None
let pt2pt_recv t rank =
  idgen t (Some t.key.key_proto) (Some t.key.key_view_id) (Some rank) (Some t.my_rank) None
let gossip t =
  idgen t None None None None None 
let multi_send t = 
  idgen t (Some t.key.key_proto) (Some t.key.key_view_id) (Some t.my_rank) None None
let pt2pt_send t rank =
  idgen t (Some t.key.key_proto) (Some t.key.key_view_id) (Some t.my_rank) (Some rank) None
let merge_send t view_id dest =
  idgen t (Some t.key.key_proto) view_id None None (Some dest)

let key t = t.key

let all_recv t scaled =
  if t.key.key_stack = Stack_id.Gossip then (
    Arrayf.singleton ((gossip t),Other,(-1))
  ) else (
    let merges = Arrayf.singleton ((merge_recv t),Other,(-1)) in

    let sends =
      if scaled then
	Arrayf.singleton ((pt2pt_recv t (-2)),Send,-2)
      else
	Arrayf.init t.nmembers (fun rank -> ((pt2pt_recv t rank),Send,rank)) 
    in
    
    let casts = 
      if scaled then
	Arrayf.singleton ((multi_recv t (-2)),Cast,-2)
      else 
	Arrayf.init t.nmembers (fun rank -> ((multi_recv t rank),Cast,rank)) 
    in

    let all_recv = Arrayf.concat [merges;sends;casts] in
    let all_recv = Arrayf.filter (fun (_,_,rank) -> rank <> t.my_rank) all_recv in
    all_recv
  )

(**************************************************************)
let ltime id = match id.view_id with None -> -1 | Some (ltime,_) -> ltime
(**************************************************************)
