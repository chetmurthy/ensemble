(**************************************************************)
(* BUF.MLI *)
(* Author: Mark Hayden, 8/98 *)
(**************************************************************)
open Trans
open Util
(**************************************************************)

type len = int
type ofs = len

(* Number of bytes in a word (4).  Curently, everything
 * works as 32-bit.  At some later point, will move things
 * to be 64-bit.
 *)
let word_len = 4
let mask1 = pred word_len
let mask2 = lnot mask1

(* Round up/down to next multiple of 4.
 *)
let is_len i = i land mask1 = 0
let floor i = i land mask2
let ceil i = (i + mask1) land mask2

external int_of_len : len -> int = "%identity"
external (=||) : len -> len -> bool = "%eq"
external (<>||) : len -> len -> bool = "%noteq"
external (>=||) : len -> len -> bool = "%geint"
external (<=||) : len -> len -> bool = "%leint"
external (>||) : len -> len -> bool = "%gtint"
external (<||) : len -> len -> bool = "%ltint"
external (+||) : len -> len -> len = "%addint"
external (-||) : len -> len -> len = "%subint"
external ( *||) : len -> int -> len = "%mulint"

let len_of_int len =
  assert (is_len len) ;
  len

let len_mul4 len = 4 * len

let len0 = 0
let len4 = 4
let len8 = 8
let len12 = 12
let len16 = 16

(* We use a defined value instead of calculating
 * it each time.  This lets the optimizer sink its
 * teeth into the value.
 *)
let md5len = 16
let _ = assert (md5len = String.length (Digest.string ""))
let md5len_plus_4 = md5len +|| len4
let md5len_plus_8 = md5len +|| len8
let md5len_plus_12 = md5len +|| len12

(**************************************************************)

type t = string
type 'a iovec = 'a Hsys.iovec = { rbuf : 'a ; ofs : ofs ; len : len }

let create = String.create
let copy = String.copy
let subeq = Hsys.substring_eq
let to_string = String.copy
let empty () = ""
let udp_recv = Hsys.udp_recv
let digest_sub = Digest.substring
let digest_substring = Digest.substring
let sendto = Hsys.sendto
let recv_hack = Hsys.recv
let sendv = Arrayf.sendv
let sendtov = Arrayf.sendtov
let sendtosv = Arrayf.sendtosv
let sendtovs = Arrayf.sendtovs
let concat bl = String.concat "" bl
let append b0 b1 = b0 ^ b1
let to_hex = Util.hex_of_string
let md5_update = Hsys.md5_update
let md5_final = Hsys.md5_final

(* This should work for 32 bit platforms, but not for
 * 64 bit.
 *)
(*
let length buf = 
  assert (pred (Obj.size (Obj.repr buf)) = String.length buf) ;
  pred (Obj.size (Obj.repr buf))
*)
let length = String.length

let static len = 
  assert (is_len len) ;
  Hsys.static_string len

let check debug buf ofs len =
  if ofs < 0 || len < 0 || ofs + len > length buf then (
    eprintf "BUF:check:%s: ofs=%d len=%d act_len=%d\n" debug ofs len (length buf) ;
    failwith ("Buf.check:"^debug)
  )

(* Unsafe blit can be used because we make the appropriate
 * checks first.
 *)
let blit debug sbuf sofs dbuf dofs len =
  check debug sbuf sofs len ;
  check debug dbuf dofs len ;
  String.unsafe_blit sbuf sofs dbuf dofs len

let blit_str = blit

let of_string debug s =
  if not (is_len (String.length s)) then (
    eprintf "BUF:of_string:%s:bad length\n" debug ;
    failwith "of_string:bad_length"
  ) ;
  String.copy s

let sub debug buf ofs len = 
  check debug buf ofs len ;
  String.sub buf ofs len

let pad_string s =
  let len = String.length s in
  let plen = ceil len in
  let buf = create plen in
  String.blit s 0 buf 0 len ;
  String.fill buf len (plen - len) (Char.chr 0) ;
  buf

(**************************************************************)

let write_net_int s ofs i =
  (* Xavier says it is unnecessary to "land 255" the values
   * prior to setting the string values.
   *)
  s.[ofs    ] <- Char.unsafe_chr (i asr 24) ;
  s.[ofs + 1] <- Char.unsafe_chr (i asr 16) ;
  s.[ofs + 2] <- Char.unsafe_chr (i asr  8) ;
  s.[ofs + 3] <- Char.unsafe_chr (i       )

let read_net_int s ofs =
  (Char.code s.[ofs    ] lsl 24) +
  (Char.code s.[ofs + 1] lsl 16) +
  (Char.code s.[ofs + 2] lsl  8) +
  (Char.code s.[ofs + 3]       ) 

let read_net_len s ofs =
  let ret = read_net_int s ofs in
  assert (is_len ret) ;
  ret

let write_net_len = write_net_int

let int_of_substring = read_net_int
let int16_of_substring s ofs =
  (Char.code s.[ofs    ] lsl  8) +
  (Char.code s.[ofs + 1]       )

let subeq8 buf ofs buf8 =
     buf.[ofs    ] = buf8.[0] 
  && buf.[ofs + 1] = buf8.[1]
  && buf.[ofs + 2] = buf8.[2]
  && buf.[ofs + 3] = buf8.[3]
  && buf.[ofs + 4] = buf8.[4]
  && buf.[ofs + 5] = buf8.[5]
  && buf.[ofs + 6] = buf8.[6]
  && buf.[ofs + 7] = buf8.[7]

let subeq16 buf ofs buf16 =
     subeq8 buf ofs buf16
  && buf.[ofs +  8] = buf16.[8] 
  && buf.[ofs +  9] = buf16.[9]
  && buf.[ofs + 10] = buf16.[10]
  && buf.[ofs + 11] = buf16.[11]
  && buf.[ofs + 12] = buf16.[12]
  && buf.[ofs + 13] = buf16.[13]
  && buf.[ofs + 14] = buf16.[14]
  && buf.[ofs + 15] = buf16.[15]

(**************************************************************)
(*
external pop_nint : string -> int -> int = "%string_unsafe_read32n"
external push_nint : string -> int -> int -> unit = "%string_unsafe_write32n"
external int_of_substring : string -> ofs -> int = "%string_unsafe_read32"
*)
(*
external pp : string -> int -> int = "%string_unsafe_read32n"
external pu : string -> int -> int -> unit = "%string_unsafe_write32n"
let pp = pp
let pu = pu
*)
(**************************************************************)

let make_marsh_buf name catch_unmarsh =
  let marsh obj buf ofs len =
    let olen = 
      try
	ignore (Marshal.to_buffer buf ofs len obj []) ;
	Marshal.total_size buf ofs
      with Failure _ -> (-1)
    in
    if olen < 0 then olen else (
  (*
      printf "BUF:marshal:%d bytes\n" (rep_len) ;
  *)
      let ret = ceil olen in
     if ret >|| len then (
	(-len4)
      ) else (
	(* Just to be sanitary, we fill the extra space with 0's.
	 * This should be unnecessary.
	 *)
	if ret >|| olen then
	  String.fill buf (ofs+olen) (ret-olen) (Char.chr 0) ;
	ret
      )
    )

  and unmarsh buf ofs len =
    let olen = Marshal.total_size buf ofs in
    if olen > len then (
      if catch_unmarsh then (
      	eprintf "BUF:unmarsh:%s:short object: olen=%d > len=%d\n" name olen len ;
	exit 1
      ) else (
	failwith "unmarsh:short object"
      )
    ) ;
	
    let obj =
      try Marshal.from_string buf ofs with Failure s as e when catch_unmarsh ->
      	eprintf "BUF:unmarsh:%s:%s\n" name (Hsys.error e) ;
	eprintf "  len=%d, avail_len=%d\n" (int_of_len len) (length buf - ofs) ;

	(* Print out magic number information.
	 *)
	let tmp = Marshal.to_string () [] in
    	let intext_magic_number = read_net_int tmp 0 in
	let magic = read_net_int buf ofs in
	eprintf "  magic number: expected=%08x got=%08x\n" intext_magic_number magic ;

	exit 1
    in
    
    (* Check that unmarshaller did not read too much.
     *)
    if ceil olen <> len then (
      eprintf "BUF:olen=%d, ofs=%d, len=%d\n" olen (int_of_len ofs) (int_of_len len) ;
      failwith "BUF:unmarsh:bad message len"
    ) ;

    obj
  in
(*
  let marsh obj buf ofs len =
    let ret = Hsys.marshal (Obj.repr obj) buf ofs len in
    printf "BUF:marsh:%d bytes\n" ret ;
    ret
  in
*)

  (* BUG: performance *)
(*
  let unmarsh buf ofs len =
    let check = String.copy buf in
    let obj = unmarsh buf ofs len in
    if buf <> check then
      failwith "marshaller modified buffer" ;
    obj
  in
*)

(*
  let unmarsh buf ofs len =
    unmarsh (String.sub buf ofs len) 0 len
  in
*)
  (* BUG: performance *)
(*
  let marsh o buf ofs len =
    let len = marsh o buf ofs len in
    if len >=| 0 then (
      let s = String.sub buf ofs len in
      let no = unmarsh s 0 len in
      if o <> no then 
	failwith "bad marshalled object"
    ) ;
    len
  in
*)
  (marsh,unmarsh)

let make_marsh name catch_unmarsh =
  let marshal,unmarshal = make_marsh_buf name catch_unmarsh in
  
  let marshal obj =
    let rec loop len =
      let buf = String.create (int_of_len len) in
      let ret = marshal obj buf len0 len in
      if ret < 0 then (
      	loop (len_mul4 len)
      ) else (
      	String.sub buf 0 ret
      )
    in loop (len_of_int (63*4))
  in

  (marshal,unmarshal)

(* Turn on the debugging...*)
(*
let _ = eprintf "BUF:debuggging marshaller enabled\n"
let make_marsh name catch_unmarsh =
  let id = Digest.string name in
  let problem s = failwith (sprintf "problem:marsh:%s:%s" name s) in
  let marshal,unmarshal = make_marsh name catch_unmarsh in

  let marsh o = 
    let str = marshal o in
    let len = String.length str in
    let d   = Digest.string str in
    let l   = String.create 4 in
    Trans.push_nint l 0 len ;
    String.concat "" [l;id;d;str]
  in
  let unmarsh buf ofs len =
    if ofs < 0 || ofs + len > String.length buf then
      problem "unmarsh:short[a]" ;
    let str = String.sub buf ofs len in

    if String.length str < 20 then
      problem (sprintf "unmarsh:short(len=%d)[b]" (String.length str)) ;
    let id' = String.sub str 4 16 in
    if id <> id' then (
      eprintf "BUF:unmarsh:id = %s\n" (hex_of_string id) ;
      eprintf "BUF:unmarsh:id'= %s\n" (hex_of_string id') ;
      problem "unmarsh:id mismatch"
    ) ;

    let len = Trans.pop_nint str 0 in 
    if len + 36 > String.length str then
      problem "unmarsh:short" ;

    let  d' = String.sub str 20 16 in
    let d = Digest.substring str 36 len in
    if d <> d' then problem "unmarsh:signature mismatch" ;

    unmarshal (String.sub str 36 len) 0 len
  in 
  (marsh,unmarsh)
*)

(**************************************************************)
let break = ident
(**************************************************************)
