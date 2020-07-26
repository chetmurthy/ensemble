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
(* ROUTE.ML *)
(* Author: Mark Hayden, 12/95 *)
(**************************************************************)
open Trans
open Buf
open Util
(**************************************************************)
let name = Trace.file "ROUTE"
let failwith = Trace.make_failwith name
(**************************************************************)

let drop = Trace.log "ROUTED"
let info = Trace.log "ROUTEI"

(**************************************************************)

type message =
  | Signed of (bool -> Obj.t option -> int -> Iovecl.t -> unit)
  | Unsigned of (Obj.t option -> int -> Iovecl.t -> unit)
  | Bypass of (int -> Iovecl.t -> unit)
  | Raw of (Iovecl.t -> unit)
  | Scale of (rank -> Obj.t option -> int -> Iovecl.t -> unit)

(**************************************************************)

type id =
  | SignedId
  | UnsignedId
  | BypassId
  | RawId
  | ScaleId

(**************************************************************)

type key = Conn.id * Conn.key * int
type merge = Iovec.rbuf -> ofs -> len -> unit
type data = Conn.id * Buf.t * Security.key * message *
     ((Conn.id * Buf.t * Security.key * message) Arrayf.t ->
      (Iovec.rbuf -> Buf.ofs -> Buf.len -> unit) Arrayf.t)

type handlers = (key,data,merge) Handler.t

type xmits =
  ((Buf.t -> ofs -> len -> unit) * 
   (Iovecl.t -> unit) *
   (Iovecl.t -> Buf.t -> unit))

(* Type of routers.
 *)
type 'msg t = {
  debug		: debug ;
  secure	: bool ;
  scaled	: bool ;
  proc_hdlr     : ((bool -> 'msg) -> message) ;
  pack_of_conn  : (Conn.id -> Buf.t) ;
  merge         : ((Conn.id * Buf.t(*digest*) * Security.key * message) Arrayf.t -> 
                   (Iovec.rbuf -> ofs -> len -> unit) Arrayf.t) ;
  blast         : (xmits -> Security.key -> Buf.t(*digest*) -> Conn.id -> 'msg)
} 

(**************************************************************)

let id_of_message = function 
  | Signed _ -> SignedId 
  | Unsigned _ -> UnsignedId
  | Bypass _ -> BypassId
  | Raw _ -> RawId
  | Scale _ -> ScaleId

(**************************************************************)

let create debug secure scaled proc_hdlr pack_of_conn merge blast = {
  debug = debug ;
  secure = secure ;
  scaled = scaled ;
  proc_hdlr = proc_hdlr ;
  pack_of_conn = pack_of_conn ;
  merge = merge ;
  blast = blast
}

let debug r = r.debug
let secure r = r.secure
let scaled r = r.scaled

let hash_help p =
  Hashtbl.hash_param 100 1000 p

let install r handlers ck all_recv key handler =
  Arrayf.iter (fun (conn,kind,rank) ->
    let pack = r.pack_of_conn conn in
    let pack0 = Buf.int16_of_substring pack (Buf.length pack -|| len4) in

    (* We put in an extra integer to make the hashing less
     * likely to result in collisions.  Note that this
     * integer has to go last in order to be effective
     * (see ocaml/byterun/hash.c).  Yuck.  
     *)
    let hash_help = hash_help (conn,ck) in
    let hdlr = r.proc_hdlr (handler kind rank) in
    Handler.add handlers pack0 (conn,ck,hash_help) (conn,pack,key,hdlr,r.merge)
  ) all_recv
(*; eprintf "ltimes=%s\n" (string_of_int_list (Sort.list (>=) ((List.map (fun ((c,_,_),_) -> Conn.ltime c) (Handler.to_list handlers)))))*)

let remove r handlers ck all_recv =
  Arrayf.iter (fun (conn,_,_) ->
    let pack = r.pack_of_conn conn in
    let pack0 = Buf.int16_of_substring pack (Buf.length pack -|| len4) in
    let hash_help = hash_help (conn,ck) in
    Handler.remove handlers pack0 (conn,ck,hash_help)
  ) all_recv

let blast r xmits key conn =
  info (fun () -> sprintf "conn=%s" (Conn.string_of_id conn)) ;
  let pack = r.pack_of_conn conn in
  r.blast xmits key pack conn

(**************************************************************)
(* Security stuff.
 *)

let secure_ref = ref false
let insecure_warned = ref false

let set_secure () =
  eprintf "ROUTE:security enabled\n" ;
  secure_ref := true

let security_check router =
  (* Check for security problems.
   *)
  if !secure_ref && not router.secure then (
    eprintf "ROUTE:enabling transport with insecure router (%s)\n" router.debug ;
    eprintf "  -secure flag is set, exiting\n" ;
    exit 1
  )
(* ;
  if router.secure & (not !secure) & (not !insecure_warned) then (
    insecure_warned := true ;
    eprintf "ROUTE:warning:enabling secure transport but -secure flag not set\n" ;
    eprintf "  (an insecure transport may be enabled)\n"
  )
*)

(**************************************************************)
(* This function takes an array of pairs and returns an
 * array of pairs, where the fst's are unique, and snd'd are
 * grouped as the snd's of the return value.  [group
 * [|(1,2);(3,4);(1,5)|]] evaluates to
 * [|(1,[|2;5|]);(3,[|4|])|], where (1,2) and (1,5) are
 * merged into a single entry in the return value.  
 *)

let group_cmp i j = fst i >= fst j

let group a =
  let len = Arrayf.length a in
  match len with
    (* Handle simple cases quickly.
     *)
  | 0 -> Arrayf.empty
  | 1 -> 
      let a = Arrayf.get a 0 in
      Arrayf.singleton ((fst a),(Arrayf.singleton (snd a)))

  | _ -> 
      (* General case.
       *)

      (* Sort by the fst of the pairs in the array.
       *)
      let a = Arrayf.sort group_cmp a in

      (* Initialize result state.
       *)
      let key = ref (fst (Arrayf.get a 0)) in
      let b = Arraye.create len (!key,Arrayf.empty) in
      let lasta = ref 0 in
      let lastb = ref 0 in

      (* Collect items with equivalent fsts into
       * lists.
       *)
      for i = 1 to len do
	if i = len || fst (Arrayf.get a i) <> !key then (
	  let sub = Arrayf.sub a !lasta (i - !lasta) in
	  let sub = Arrayf.map snd sub in
	  Arraye.set b !lastb (!key,sub) ;
	  incr lastb ;
	  lasta := i ;
	  if i < len then (
	    key := fst (Arrayf.get a i)
	  )
	) ;
      done ;

      (* Clean up the result state.
       *)
      let b = Arraye.sub b 0 !lastb in
      let b = Arrayf.of_arraye b in
      b

(**************************************************************)

(* Test code for 'group'
*)
let _ = Trace.test_declare "group" (fun () ->
  let group_simple a =
    let len = Arrayf.length a in
    if len = 0 then Arrayf.empty else (
      (* Sort by the fst of the pairs in the array.
       *)
      let a = Arrayf.sort group_cmp a in

      (* Initialize result state.
       *)
      let k0,d0 = Arrayf.get a 0 in
      let k = Arraye.create len k0 in
      let d = Arraye.create len [] in
      let j = ref 0 in
      Arraye.set d 0 [d0] ;

      (* Collect items with equivalent fsts into
       * lists.
       *)
      for i = 1 to pred len do
	if fst (Arrayf.get a i) <> Arraye.get k !j then (
	  incr j ;
	  assert (!j < len) ;
	  Arraye.set k !j (fst (Arrayf.get a i))
	) ;
	Arraye.set d !j (snd (Arrayf.get a i) :: (Arraye.get d !j))
      done ;

      (* Clean up the result state.
       *)
      incr j ;
      let d = Arraye.sub d 0 !j in
      let k = Arraye.sub k 0 !j in
      let d = Arraye.map Arrayf.of_list d in
      let d = Arrayf.of_arraye d in
      let k = Arrayf.of_arraye k in
      Arrayf.combine k d
    )
  in
  
  let expand a =
    let a = Arrayf.map (fun (i,b) ->
      Arrayf.map (fun j -> (i,j)) b
    ) a in
    Arrayf.flatten a
  in

  for c = 1 to 100000 do
    if (c mod 1000) = 0 then
      eprintf "test:%d\n" c ;
    let a = Arrayf.init (Random.int 50) (fun _ ->
      (Random.int 5, Random.int 15))
    in
    let b = group_simple a in
    let c = group a in

    let a = Arrayf.sort (>=) a in
    let b = Arrayf.map (fun (i,a) -> (i,(Arrayf.sort (>=) a))) b in
    let c = Arrayf.map (fun (i,a) -> (i,(Arrayf.sort (>=) a))) c in
    let d = Arrayf.sort (>=) (expand c) in

    if b <> c || a <> d then (
      eprintf "inp=%s\n" ((Arrayf.to_string (string_of_pair string_of_int string_of_int)) a) ;
      eprintf "old=%s\n" ((Arrayf.to_string (string_of_pair string_of_int Arrayf.int_to_string)) b) ;
      eprintf "new=%s\n" ((Arrayf.to_string (string_of_pair string_of_int Arrayf.int_to_string)) c) ;
      assert (b = c) ;
    ) ;
    
  done
)

(**************************************************************)

let no_handler () = "no upcalls for message"
let empty1 _ _ = drop no_handler
let empty2 _ _ = drop no_handler
let empty3 _ _ _ = drop no_handler

let merge1 a = ident (fun a1 -> Arrayf.iter (fun f -> f a1) a)

let merge2 a =
  match (Arrayf.to_array a) with
  | [||] -> empty2
  | [|f1|] -> f1
  | [|f1;f2|] ->
      fun a1 a2 ->
	f1 a1 a2 ; f2 a1 a2
  | _ ->
      let n = pred (Arrayf.length a) in
      fun a1 a2 ->
	for i = 0 to n do
	  (Arrayf.get a i) a1 a2
	done

let merge3 a = 
  match (Arrayf.to_array a) with
  | [||] -> empty3
  | [|f1|] -> f1
  | [|f1;f2|] ->
      fun a1 a2 a3 ->
	f1 a1 a2 a3 ; f2 a1 a2 a3
  | _ ->
      let n = pred (Arrayf.length a) in
      fun a1 a2 a3 ->
	for i = 0 to n do
	  (Arrayf.get a i) a1 a2 a3
	done

let merge4 a = ident (fun a1 a2 a3 a4 -> Arrayf.iter (fun f -> f a1 a2 a3 a4) a)

(**************************************************************)

let empty3rc r o l = drop no_handler ; Refcnt.free name r
let merge3rc a = 
  match Arrayf.to_array a with
  | [||] -> empty3rc
  | [|f1|] -> f1
  | [|f1;f2|] ->
      fun r o l -> 
	f1 (Refcnt.copy name r) o l ; f2 r o l
  | _ ->
      let n = pred (Arrayf.length a) in
      fun r o l ->
	for i = 1 to n do
	  (Arrayf.get a i) (Refcnt.copy name r) o l
	done ;
	(Arrayf.get a 0) r o l

(**************************************************************)
(* Handle the reference counting.  The idea here is that in
 * the code we allocate an iovec array with one reference.
 * Here we want to increment that reference count if there
 * is more than 1 destination and decrement it if there are
 * none.  Note that we do the operations that increment the
 * reference counts first so that the count does not get
 * zeroed on us.
 *)

let empty1iov argv = drop no_handler ; Iovecl.free name argv
let merge1iov a = 
  match Arrayf.to_array a with
  | [||] -> empty1iov
  | [|f1|] -> f1
  | [|f1;f2|] ->
      fun argv -> 
	f1 (Iovecl.copy name argv) ; f2 argv
  | _ ->
      let pred_len = pred (Arrayf.length a) in
      fun argv ->
	for i = 1 to pred_len do
	  (Arrayf.get a i) (Iovecl.copy name argv)
	done ;
	(Arrayf.get a 0) argv

let empty2iov arg1 argv = drop no_handler ; Iovecl.free name argv
let merge2iov a = 
  match Arrayf.to_array a with
  | [||] -> empty2iov
  | [|f1|] -> f1
  | [|f1;f2|] ->
      fun arg1 argv -> 
	f1 arg1 (Iovecl.copy name argv) ; f2 arg1 argv
  | _ ->
      let pred_len = pred (Arrayf.length a) in
      fun arg1 argv ->
	for i = 1 to pred_len do
	  (Arrayf.get a i) arg1 (Iovecl.copy name argv)
	done ;
	(Arrayf.get a 0) arg1 argv

let empty2iovr argv arg2 = drop no_handler ; Iovecl.free name argv
let merge2iovr a = 
  match Arrayf.to_array a with
  | [||] -> empty2iovr
  | [|f1|] -> f1
  | [|f1;f2|] ->
      fun argv arg2 -> 
	f1 (Iovecl.copy name argv) arg2 ; f2 argv arg2
  | _ ->
      let pred_len = pred (Arrayf.length a) in
      fun argv arg2 ->
	for i = 1 to pred_len do
	  (Arrayf.get a i) (Iovecl.copy name argv) arg2
	done ;
	(Arrayf.get a 0) argv arg2

let empty3iov arg1 arg2 argv = drop no_handler ; Iovecl.free name argv
let merge3iov a = 
  match Arrayf.to_array a with
  | [||] -> empty3iov
  | [|f1|] -> f1
  | [|f1;f2|] ->
      fun arg1 arg2 argv ->
	f1 arg1 arg2 (Iovecl.copy name argv) ; f2 arg1 arg2 argv
  | _ ->
      let pred_len = pred (Arrayf.length a) in
      fun arg1 arg2 argv ->
	for i = 1 to pred_len do
	  (Arrayf.get a i) arg1 arg2 (Iovecl.copy name argv)
	done ;
	(Arrayf.get a 0) arg1 arg2 argv

let empty4iov arg1 arg2 arg3 argv = drop no_handler ; Iovecl.free name argv
let merge4iov a = 
  match Arrayf.to_array a with
  | [||] -> empty4iov
  | [|f1|] -> f1
  | [|f1;f2|] -> fun arg1 arg2 arg3 argv ->
      f1 arg1 arg2 arg3 (Iovecl.copy name argv) ; f2 arg1 arg2 arg3 argv
  | _ ->
      let pred_len = pred (Arrayf.length a) in
      fun arg1 arg2 arg3 argv ->
	for i = 1 to pred_len do
	  (Arrayf.get a i) arg1 arg2 arg3 (Iovecl.copy name argv)
	done ;
	(Arrayf.get a 0) arg1 arg2 arg3 argv

let pack_of_conn = Conn.hash_of_id

(**************************************************************)

(*type merge = (Conn.id * Security.key * Conn.kind * rank * message) array -> (Iovec.t -> unit)*)

let merge info =
  let info = Arrayf.map (fun (c,p,k,h,m) -> ((id_of_message h),(m,(c,p,k,h)))) info in
  let info = group info in
  let info = 
    Arrayf.map (fun (_,i) -> 
      assert (Arrayf.length i > 0) ; 
      (fst (Arrayf.get i 0)) (Arrayf.map snd i)
    ) info 
  in
  let info = Arrayf.flatten info in
  merge3rc info

let delay f =
  let delayed a b c =
    (f ()) a b c
  in
  delayed


let handlers () =
  let table = Handler.create merge delay in
(*
  Trace.install_root (fun () -> [
    sprintf "ROUTE:#enabled=%d" (Handler.size table) ;
    sprintf "ROUTE:table:%s" (Handler.info table)
  ]) ;
*)
  table

let deliver handlers rbuf ofs len = 
  let pos = ofs +|| len -|| len4 in
(*
  eprintf "ROUTE:deliver:hash word=%04X\n" (Buf.int16_of_substring (Refcnt.read name rbuf) pos) ;
*)
  let handler = Handler.find handlers (Buf.int16_of_substring (Refcnt.read name rbuf) pos) in
  handler rbuf ofs len

let deliver_iov handlers iov =
  let iov = Iovec.really_break iov in
  deliver handlers iov.Iovec.rbuf iov.Iovec.ofs iov.Iovec.len

let deliver_iovl handlers mbuf iovl =
  let iov = Mbuf.flatten name mbuf iovl in
  deliver_iov handlers iov

(**************************************************************)
