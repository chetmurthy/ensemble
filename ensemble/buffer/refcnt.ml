(**************************************************************)
(* REFCNT.ML *)
(* Author: Mark Hayden, 3/95 *)
(**************************************************************)
open Util
open Trans
open Buf
(**************************************************************)
let name = Trace.file "REFCNT"
(**************************************************************)
(* Fast version.  Only one copy of ref counting objects are
 * kept.  Everything is in-place.  Roots are the same as the
 * actual objects.  Nothing is done with the debug
 * information.  Everything should be inlined.  
 *)


type 'a t = 'a Hsys.refcnt
type 'a root = 'a t
(*
let info a b = a^":"^b
let info2 a b c = a^":"^b^":"^c
*)
let info _ a = a
let info2 _ _ a = a
let make _ obj = { Hsys.count = 1 ; Hsys.obj = obj }
let create debug o = let x = make debug o in (x,x)
let check _ _ = ()
let ref  _ h = h.Hsys.count <- succ h.Hsys.count
let free _ h = h.Hsys.count <- pred h.Hsys.count
let copy _ h = h.Hsys.count <- succ h.Hsys.count ; h
let take _ h = h
let read _ h = h.Hsys.obj
let void = make
let count _ h = h.Hsys.count
let to_string h = sprintf "Refcnt(Fast;count=%d)" h.Hsys.count

let sendv = Buf.sendv
let sendtov = Buf.sendtov
let sendtosv = Buf.sendtosv
let sendtovs = Buf.sendtovs

type iovec = Buf.t t Buf.iovec
let iovec_alloc_noref debug rbuf ofs len =
  { rbuf = rbuf ; ofs = ofs ; len = len }
let iovec_alloc debug rbuf ofs len =
  let rbuf = copy debug rbuf in
  iovec_alloc_noref debug rbuf ofs len
let iovec_free  debug i = free  debug i.rbuf
let iovec_ref   debug i = ref   debug i.rbuf
let iovec_check debug i = check debug i.rbuf
let iovec_copy  debug i = iovec_ref debug i ; i
let iovec_take  debug i = i
let iovecl_copy debug il = 
  for i = pred (Arrayf.length il) downto 0 do
    iovec_ref debug (Arrayf.get il i)
  done ;
  il
let iovecl_take debug il = il


(**************************************************************)
(**************************************************************)
(**************************************************************)
(**************************************************************)
(**************************************************************)
(* Debugging version *)
(*

let failwith = Trace.make_failwith name

let counter = Util.counter ()

(* The root has its counter and an id.
 *)
type lroot = {
  mutable rcount : int ;
  id : int
}

(* Exported roots have a type parameter.
 * Local ones do not.
 *)
type 'a root = lroot

(**************************************************************)

(* Operations on roots.
 *)  
let rinc r = r.rcount <- succ r.rcount
let rdec r = r.rcount <- pred r.rcount

let count debug r =
  r.rcount

(**************************************************************)

(* This is where reference counting information
 * is stored.
 *)
type handle = {
  mutable count : int ;
  mutable debug : (string * string) list ;
  root : lroot
} 

(* Exported refcounts are just pointers to
 * handles and the object.
 *)
type 'a t = {
  handle : handle ;
  obj : 'a
} 

(**************************************************************)
(* Create a weak object.
 *)
let cur = ref (Weak.create 0)
let idx = ref 0

let weak o =
  let o = Obj.repr o in
  if !idx >= Weak.length !cur then (
    idx := 0 ;
    cur := Weak.create 1022 ;
  ) ;
  let my_idx = !idx in
  let my_cur = !cur in
  incr idx ;
  Weak.set my_cur my_idx (Some o) ;
  fun () -> Weak.check my_cur my_idx

(* Major returns true if a major GC has occured.
 *)
let major =
  let weak = Weak.create 1 in
  fun () ->
    if Weak.check weak 0 then
      false
    else (
      Weak.set weak 0 (Some(ref 0)) ;
      true
    )

(**************************************************************)

let alive = ref []

(* Scan the list of alive members, removing ones that have
 * been collected.
 *)
let scan () =
  eprintf "REFCNT:scan:begin:(#=%d)\n" (List.length !alive) ;
  alive := List.filter (fun f -> f ()) !alive ;
  eprintf "REFCNT:scan:end:(#=%d)\n" (List.length !alive)

(**************************************************************)

let info a b = b^":"^a
let info2 a b c = info (a^"."^b) c

(*
let dump where debug h =
  eprintf "REFCNT:rc=%d:%s:%s:%s\n" 
    h.count where debug (string_of_list (string_of_pair ident ident) (List.rev h.debug))
*)
let dump where debug h =
  eprintf "REFCNT:rc=%d:%s:%s\n" 
    h.count where debug ;
  List.iter (fun (a,b) ->
    eprintf "  %s %s\n" a b
  ) (List.rev h.debug)

let lcheck where debug i =
  if major () then
    scan () ;
  let h = i.handle in
  if h.count < 0 then (
    dump where debug h
  ) else if h.root.rcount < 0 then ( 
    failwith "debug:sanity:negative root" ;
  )

(* Mark a refcount object.
 *)
let mark where debug i = 
  let h = i.handle in
  lcheck where debug i ;
  h.debug <- (where,debug)::h.debug

let finalize handle weak =
  let check () =
    let alive = weak () in
    if not alive && handle.count > 0 then
      dump "check" "dead" handle ;
    alive
  in check

(* Make a new object.
 *)
let make where debug obj root =
  let handle = { count = 1 ; debug = [] ; root = root } in
  let ret = { handle = handle ; obj = obj } in

  (* Create a weak object and install it in the
   * list of alive handles.
   *)
  let weak = weak ret in
  
  (* Finalize is in a separate function so
   * that ret is not in its scope at all.
   *)
  alive := (finalize handle weak) :: !alive ;
  
  mark where debug ret ;
  ret

let create debug obj =
  let root = { rcount = 1 ; id = counter() } in
  let first = make "create" debug obj root in
  (root,first)

let void debug obj =
  let root = { rcount = 1 ; id = counter() } in
  make "void" debug obj root
  
let inc debug i = 
  mark "incr" debug i ;
  let h = i.handle in
  rinc h.root ;
  h.count <- succ h.count

let copy debug i = 
  lcheck "copy" debug i ;
  let h = i.handle in
  rinc h.root ;
  make "copy" debug i.obj h.root

let free debug i = 
  mark "decr" debug i ;

  (* Only decrement root if this handle is still valid.
   *)
  let h = i.handle in
  if h.count > 0 then
    rdec h.root ;
  h.count <- pred h.count ;
  lcheck debug "decr:post" i

let read debug i =
  mark "read" debug i ;
  lcheck "read" debug i ;
  i.obj

let check debug i = 
  lcheck "check" debug i

(* Does not affect root refcount.
 *)
let take debug i =
  let h = i.handle in
  let ret = make "take" debug i.obj h.root in
  h.count <- pred h.count ;
  mark "take(src)" debug i ;
  lcheck "take(post)" debug i ;
  ret

let to_string r = sprintf "Refcnt(id=%d)" r.id

(**************************************************************)
(**************************************************************)

let mapper iov =
  let rbuf = { Hsys.count = 0 ; Hsys.obj = read name iov.Buf.rbuf } in
  { Buf.rbuf = rbuf ; Buf.ofs = iov.Buf.ofs ; Buf.len = iov.Buf.len }

let map_iovl iovl = Arrayf.map mapper iovl

let sendv info iovl =
  let iovl = map_iovl iovl in
  Buf.sendv info iovl

let sendtov info iovl =
  let iovl = map_iovl iovl in
  Buf.sendtov info iovl

let sendtosv info s iovl =
  let iovl = map_iovl iovl in
  Buf.sendtosv info s iovl

let sendtovs info iovl s =
  let iovl = map_iovl iovl in
  Buf.sendtovs info iovl s

let eth_sendtovs info iovl s =
  let iovl = map_iovl iovl in
  Buf.eth_sendtovs info iovl s

(**************************************************************)

type iovec = Buf.t t Buf.iovec

let name = "IOVEC"			(* HACK *)

(* Wrap an rbuf as an Iovec.  Assume it is properly
 * aligned.
 *)
let iovec_alloc_noref debug rbuf ofs len =
  (* The ofs and len should be within the buffer.
   *)
  assert (ofs >=|| len0) ;
  assert (ofs +|| len <=|| Buf.length (read debug rbuf)) ;

  { rbuf = rbuf ; ofs = ofs ; len = len }

let iovec_alloc debug rbuf ofs len =
  let debug = info2 name "alloc" debug in
  let rbuf = copy debug rbuf in
  iovec_alloc_noref debug rbuf ofs len

let iovec_free  debug i = free  (info2 name "free"  debug) i.rbuf
let iovec_ref   debug i = inc   (info2 name "ref"   debug) i.rbuf
let iovec_check debug i = check (info2 name "check" debug) i.rbuf

let iovec_copy debug i  =
  let debug = info2 name "copy" debug in
  iovec_alloc debug i.rbuf i.ofs i.len

let iovec_take debug i = 
  let debug1 = info2 name "take(dst)" debug in
  let debug2 = info2 name "take(src)" debug in
  let ret = iovec_alloc debug1 i.rbuf i.ofs i.len in
  free debug2 i.rbuf ;
  ret

let name = "IOVECL"			(* HACK *)

let iovecl_copy debug il =
  let debug = info2 name "copy"  debug  in
  Arrayf.map (fun i -> iovec_copy debug i) il

let iovecl_take debug il =
  let debug = info2 name "take" debug in
  Arrayf.map (fun i -> iovec_take debug i) il

*)
(**************************************************************)
