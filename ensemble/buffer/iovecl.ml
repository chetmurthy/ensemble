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
(* IOVECL.ML: operations on arrays of Iovec's. *)
(* Author: Mark Hayden, 5/96 *)
(**************************************************************)
open Trans
open Buf
open Util
(**************************************************************)
let name = Trace.file "IOVECL"
let failwith s = Trace.make_failwith2 name s
(**************************************************************)

type t = Iovec.t Arrayf.t

(**************************************************************)

let free debug il =
  let debug = Refcnt.info2 name "free" debug in
  for i = pred (Arrayf.length il) downto 0 do Iovec.free  debug (Arrayf.get il i) done

let ref debug il =
  let debug = Refcnt.info2 name "ref" debug in
  for i = pred (Arrayf.length il) downto 0 do Iovec.ref   debug (Arrayf.get il i) done

let check debug il =
  let debug = Refcnt.info2 name "check" debug in
  for i = pred (Arrayf.length il) downto 0 do Iovec.check debug (Arrayf.get il i) done

(* These are taken from the Iovec module.
 *)
let copy = Iovec.iovecl_copy
let take = Iovec.iovecl_take

(**************************************************************)

let empty = Arrayf.empty

let of_iovec debug iov = Arrayf.singleton iov

let of_iovec_array = ident

let append debug iovl1 iovl2 = Arrayf.append iovl1 iovl2

let prependi debug iov iovl = Arrayf.prependi iov iovl
let appendi debug iovl iov = Arrayf.append iovl (Arrayf.singleton iov)

let concat debug iovll = Arrayf.concat iovll
let concata debug iovll = Arrayf.flatten iovll

(**************************************************************)
(* Although the ref used below this causes allocation with
 * bytecode, I have verified that the native code compiler
 * eliminates the reference allocation.  
 *)

let len debug il = 
  let l = Pervasives.ref len0 in
  for i = 0 to pred (Arrayf.length il) do
    l := !l +|| Iovec.len debug (Arrayf.get il i)
  done ;
  !l

(**************************************************************)

let is_empty il =
  Arrayf.is_empty il || len name il = len0

(**************************************************************)

let rec read_net_int_help debug il i ofs =
  if i >= Arrayf.length il then 
    failwith "read_net_int_help: length < ofs+4" ;
  let iov = Arrayf.get il i in
  let len = Iovec.len debug iov in
  if len >=|| ofs +|| len4 then 
    Iovec.read_net_int name iov ofs
  else
    read_net_int_help debug il (succ i) (ofs -|| len)

let read_net_int debug il ofs =
  read_net_int_help debug il 0 ofs

let rec read_net_len_help debug il i ofs =
  if i >= Arrayf.length il then 
    failwith "read_net_int_help: length < ofs+4" ;
  let iov = Arrayf.get il i in
  let len = Iovec.len debug iov in
  if len >=|| ofs +|| len4 then 
    Iovec.read_net_len name iov ofs
  else
    read_net_len_help debug il (succ i) (ofs -|| len)

let read_net_len debug il ofs =
  read_net_len_help debug il 0 ofs

(**************************************************************)

(* MH: I think this is buggy.
 *)
(*
let eq debug il0 il1 =
  if len debug il0 <> len debug il1 then
    false
  else (
    let n0 = Arrayf.length il0 in
    let n1 = Arrayf.length il1 in
    let rec loop (i0:int) (o0:len) (i1:int) (o1:len) =
      if i0 >= n0 || i1 >= n1 then
 	true
      else (
	let iov0 = Arrayf.get il0 i0 in
	let iov1 = Arrayf.get il1 i1 in
	let l0 = Iovec.len debug iov0 in
	let l1 = Iovec.len debug iov1 in
	let check len =
	  Iovec.read debug iov0 (fun buf0 ofs0 _ ->
	    Iovec.read debug iov1 (fun buf1 ofs1 _ ->
	      if
		Buf.subeq buf0 (ofs0 +|| o0) buf1 (ofs1 +|| o1) len
	      then true else ( eprintf "i0=%d,o0=%d,i1=%d,o1=%d\n" 
				i0 (int_of_len (ofs0 +|| o0)) i1 (int_of_len (ofs1 +|| o1)) ; false )
	    )
	  )
	in
	if l0 -|| o0 < l1 -|| o1 then (
	  if check (l0 -|| o0) then
	    loop (succ i0) len0 i1 (o1 +|| l0 -|| o0)
	  else
	    false
	) else (
	  if check (l1 -|| o1) then
	    loop i0 (o0 +|| l1 -|| o1) (succ i1) len0
	  else
	    false
	)
     )
    in loop 0 len0 0 len0
  )	  
*)
(**************************************************************)

let flatten_buf debug il buf ofs max_len = 
  let debug = Refcnt.info2 name "flatten_buf" debug in
  let len = len debug il in
  if len >|| max_len then (
    eprintf "flatten_buf:iovecl too large:%s\n" debug ;
    failwith "flatten_buf:iovecl too large"
  ) ;
(*
  Iovec.log (fun () -> sprintf "flatten_buf:%s:%d -> %d bytes" debug (Arrayf.length il) (int_of_len len)) ;
*)
  let ofs = Pervasives.ref ofs in
  for i = 0 to pred (Arrayf.length il) do
    let iov = Iovec.really_break (Arrayf.get il i) in
    
    (* Both of these versions are equivalent, only
     * that (1) eliminates an allocation.
     *)
(* 1. *)
    let len = iov.Iovec.len in
    Buf.blit debug (Refcnt.read debug iov.Iovec.rbuf) iov.Iovec.ofs buf !ofs len ;
    ofs := !ofs +|| len
(* 2. *)
(*    
    Iovec.read debug (Arrayf.get il i) (fun sbuf sofs slen ->
      Buf.blit debug sbuf sofs buf !ofs slen ;
      ofs := !ofs +|| slen
    )
*)
  done ;
  len

let flatten_buf_exact debug il buf ofs len =
  let ret = flatten_buf debug il buf ofs len in
  assert (ret = len)

(**************************************************************)

let count_nonempty debug il =
  let nonempty = Pervasives.ref 0 in
  for i = 0 to pred (Arrayf.length il) do
    if Iovec.len debug (Arrayf.get il i) <>|| len0 then
      incr nonempty
  done ;
  !nonempty

(**************************************************************)

let clean_help iov = Iovec.len name iov <>|| len0

let clean debug il =
  let n = Arrayf.length il in
  let nonempty = count_nonempty debug il in
  if nonempty = Arrayf.length il then il else (
    Arrayf.filter clean_help il
  )

(**************************************************************)

let is_singleton debug il =
  Arrayf.length il = 1

let get_singleton debug il =
  assert (Arrayf.length il = 1) ;
  Arrayf.get il 0

let alloc debug rbuf ofs len =
  of_iovec debug (Iovec.alloc debug rbuf ofs len)

let alloc_noref debug rbuf ofs len =
  of_iovec debug (Iovec.alloc_noref debug rbuf ofs len)

let md5_update debug ctx il =
  let debug = Refcnt.info2 name "check" debug in
  for i = 0 to pred (Arrayf.length il) do
    Iovec.md5_update debug ctx (Arrayf.get il i) 
  done

(**************************************************************)

let flatten debug il = 
  let debug = Refcnt.info2 name "flatten" debug in
  let nonempty = count_nonempty debug il in
  let ret =
    match nonempty with
    | 0 ->
	Iovec.empty debug
    | 1 ->
	let ni = Arrayf.length il in
	let nonempty = Pervasives.ref (-1) in
	for i = 0 to pred ni do
	  let iov = Arrayf.get il i in
	  if Iovec.len name iov >|| len0 then
	    nonempty := i
	done ;
	assert (!nonempty >= 0) ;
	Iovec.copy debug (Arrayf.get il !nonempty)
    | _ ->
	let len = len debug il in
	Iovec.log (fun () -> sprintf "flatten:%s:allocating %d bytes" debug (int_of_len len)) ;
	Iovec.createf debug len (flatten_buf_exact debug il)
  in
  free debug il ;
  ret

(**************************************************************)

let eq debug il0 il1 =
  let il0 = copy debug il0 in
  let il1 = copy debug il1 in
  let i0 = flatten debug il0 in
  let i1 = flatten debug il1 in
  let ret = Iovec.eq debug i0 i1 in
  Iovec.free debug i0 ;
  Iovec.free debug i1 ;
  ret

(*
let eq debug il0 il1 =
  let e1 = eq debug il0 il1 in
  let e2 = eq1 debug il0 il1 in
  if e1 <> e2 then failwith "eq:sanity" ;
  e2
*)
(**************************************************************)

let make_marsh debug =
  let debug = Refcnt.info2 name "make_marsh" debug in
  let (marsh,unmarsh) = Buf.make_marsh debug true in
  let debug1 = Refcnt.info2 name "make_marsh(ma)" debug in
  let debug2 = Refcnt.info2 name "make_marsh(um)" debug in
  let marsh obj =
    let str = marsh obj in
    alloc_noref debug1 (Iovec.heap debug str) len0 (Buf.length str)
  and unmarsh iovl =
    let iovl = take debug2 iovl in
    let iov = flatten debug2 iovl in
    let obj = Iovec.read debug2 iov unmarsh in
    Iovec.free name iov ;
    obj
  in (marsh,unmarsh)

(**************************************************************)

type loc = int * ofs
let loc0 = (0,len0)

let rec sub_help debug iovl ((i,ofs) as loc) pos doing_hi =
  assert (pos >=|| ofs) ;
  assert (i < Arrayf.length iovl) ;
  let leni = Iovec.len debug (Arrayf.get iovl i) in
  let endi = ofs +|| leni in
  if pos < endi || (doing_hi && pos = endi) then 
    (loc,(pos -|| ofs))
  else 
    sub_help debug iovl ((succ i),(ofs+||leni)) pos doing_hi

let sub_scan debug loc iovl ofs len' =
  let debug = Refcnt.info2 name "sub" debug in
  if len' =|| len0 then (
    empty,loc
  ) else (
    let total_len = len debug iovl in
    if ofs <|| len0 || len' <|| len0 || len' +|| ofs >|| total_len then (
      eprintf "IOVECL:sub:ofs=%d len=%d total_len=%d debug=%s\n" 
	(int_of_len ofs) (int_of_len len') (int_of_len total_len) debug ;
      failwith "sub:ofs,len out of bounds" ;
    ) ;

    let ((lo_iov,_) as loc),lo_ofs = sub_help debug iovl loc ofs false in
    let ((hi_iov,_) as loc),hi_ofs = sub_help debug iovl loc (ofs +|| len') true in
(*
    eprintf "IOVECL:sub:ofs=%d len=%d lo_iov=%d lo_ofs=%d hi_iov=%d hi_ofs=%d pos=%d\n" 
      (int_of_len ofs) (int_of_len len') lo_iov (int_of_len lo_ofs) hi_iov (int_of_len hi_ofs) 
      (int_of_len pos) ;
*)
    let ret = 
      if lo_iov = hi_iov then (
	let iov = Iovec.sub debug (Arrayf.get iovl lo_iov) lo_ofs (hi_ofs -|| lo_ofs) in
	of_iovec debug iov
      ) else (
	assert (lo_iov < hi_iov) ;
	let last = hi_iov - lo_iov in
	let iovl = 
	  Arrayf.init (hi_iov - lo_iov + 1) (fun i ->
	    let iov = Arrayf.get iovl (lo_iov + i) in
	    if i = 0 then (
	      let leni = Iovec.len debug iov in
	      Iovec.sub debug iov lo_ofs (leni -|| lo_ofs)
	    ) else if i = last then (
	      Iovec.sub debug iov len0 hi_ofs
	    ) else (
	      Iovec.copy debug iov
	    )
	  )
	in
	of_iovec_array iovl
      )
    in ret,loc
  )

let sub debug iovl ofs len = fst (sub_scan debug loc0 iovl ofs len)

(* Simple version of above.
 *)
(*
let _ = Trace.comment "slow Iovecl.sub"
let sub name iovl ofs len =
  if len = len0 then (
    empty
  ) else (
    let iovl = copy name iovl in
    let iov = flatten name iovl in
    let iov' = Iovec.sub name iov ofs len in
    Iovec.free name iov ;
    of_iovec name iov'
  )
*)

(* Checking version of above.
 *)
(*
let _ = Trace.comment "checking Iovecl.sub"
let sub name iovl ofs len =
  let ret = sub name iovl ofs len in
  begin
    let iovl = copy name iovl in
    let iov' = flatten name iovl in
    let iov = Iovec.sub name iov' ofs len in
    Iovec.free name iov' ;
    let iov = of_iovec name iov in
    if not (eq name ret iov) then (
      eprintf "ofs=%d,len=%d\n" (int_of_len ofs) (int_of_len len) ;
      failwith "sub(checking)" ;
    ) ;
    free name iov
  end ;
  ret
*)

let sub_take debug iov ofs len =
  let ret = sub debug iov ofs len in
  free debug iov ;
  ret

(**************************************************************)

(* Fragment an iovecl.
 *)
let fragment debug frag_len iov =
  let debug = Refcnt.info2 name "fragment" debug in
  let iov = copy debug iov in
  let fleni = int_of_len frag_len in
  let len = len name iov in
  let leni = int_of_len len in
  let n = (leni + pred fleni) / fleni in
  let a = Array.create n empty in
  let loc_r = Pervasives.ref loc0 in
  for i = 0 to pred n do
    let ofs = frag_len *|| i in
    let len =
      if i = pred n then
	len -|| ofs
      else
	frag_len
    in
    let iov,loc = sub_scan debug !loc_r iov ofs len in
    loc_r := loc ;
    a.(i) <- iov
  done ;
  free debug iov ;
  Arrayf.of_array a

(* Checking version of above. *)
(*
let fragment debug frag_len iov =
  let iov = copy debug iov in
  let frags = fragment debug frag_len iov in
  free debug iov ;
  begin
    let merge = Arrayf.map (copy debug) frags in
    let merge = concat debug (Arrayf.to_list merge) in
    let merge = flatten debug merge in
    let iov = copy debug iov in
    let iov = flatten debug iov in
    if not (Iovec.eq debug merge iov) then
      failwith "badly fragged" ;
  end ;
  frags
*)

(**************************************************************)

let print name iovl =
  let info = Arrayf.map (fun iov ->
    Iovec.read name iov (fun buf ofs len -> sprintf "(%d:%d,%d)" 
      (int_of_len (Buf.length buf)) (int_of_len ofs) (int_of_len len))
  ) iovl in
  eprintf "IOVECL:print:%s:%s\n" name (Arrayf.to_string ident info)
(*
  let s = flatten name iovl in
  let s = to_string name s in
  let len = String.length s in
  let s = hex_of_string s in
  log (fun () -> sprintf "%s:%d:%s\n" name len s)
*)

(**************************************************************)

let sendv = Iovec.sendv
let sendtov = Iovec.sendtov
let sendtosv = Iovec.sendtosv
let sendtovs = Iovec.sendtovs
let eth_sendtovs = Iovec.eth_sendtovs

(**************************************************************)
