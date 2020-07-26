(**************************************************************)
(* SOCKET.ML *)
(* Authors: Robbert vanRenesse and Mark Hayden, 4/95 *)
(**************************************************************)
let name = "SSOCKET"
let failwith s = failwith (name^":"^s)
(**************************************************************)
open Printf
open Socksupp
(**************************************************************)
type buf = string
type ofs = int
type len = int

let max_msg_size = 8 * 1024

(**************************************************************)
(* Memory management functions. 
*)

(* Debugging
*)
let verbose = ref false

let set_verbose flag =
  printf "Socket verbose\n"; Pervasives.flush Pervasives.stdout;
  verbose := flag

let log f = 
  if !verbose then (
    let s = f () in
    print_string s; print_string "\n"; flush stdout;
  ) else ()

module Basic_iov = struct

  (* It is not clear whether this is really neccessary 
   * with the newer versions of OCAML.
   * 
   * PERF
   *)
  external (=||) : int -> int -> bool = "%eq"
  external (<>||) : int -> int -> bool = "%noteq"
  external (>=||) : int -> int -> bool = "%geint"
  external (<=||) : int -> int -> bool = "%leint"
  external (>||) : int -> int -> bool = "%gtint"
  external (<||) : int -> int -> bool = "%ltint"
  external (+||) : int -> int -> int = "%addint"
  external (-||) : int -> int -> int = "%subint"
  external ( *||) : int -> int -> int = "%mulint"

  (* The type of a C memory-buffer. It is opaque.
   *)
  type cbuf  
  type ofs = int
  type len = int
   
  type raw = {
    len : int ;
    cbuf : cbuf ;
  }

  type base = {
    mutable count : int; (* A reference count *)
    base_iov : raw   (* Free this cbuf when the refcount reaches zero *)
  }

  type t = { 
    base : base ;  
    iov : raw
  }
      
  external copy_raw_into_string : raw -> string -> ofs -> unit
    = "mm_copy_raw_into_string" "noalloc"

  external copy_raw_into_raw : raw -> raw -> unit
    = "mm_copy_raw_into_raw" "noalloc"
      
  external copy_string_into_raw : string -> ofs -> len -> raw -> unit
    = "mm_copy_string_into_raw" "noalloc"
      
  external free_cbuf : cbuf -> unit 
    = "mm_cbuf_free" "noalloc"

  external mm_cbuf_sub : raw -> ofs -> cbuf
    = "mm_cbuf_sub" 

  let mm_sub iov ofs len = 
    assert(iov.len >=|| ofs +|| len);
    let cbuf = mm_cbuf_sub iov ofs in
    {len=len; cbuf=cbuf}

  (* Flatten an array of iovectors. The destination iovec is
   * preallocated.
   *)
  external mm_flatten : raw array -> raw -> unit
    = "mm_flatten" "noalloc"

  (* Raw (C) allocation function. Can be user defined.
   *)
  external mm_alloc : int -> raw
    = "mm_alloc"

  (* Create an empty iovec. We do this on the C side, so
   * that it will be usable by C functions that may return
   * empty Iovec's.
   *)
  external mm_empty : unit -> raw
    = "mm_empty"

  (* These conversions are needed for CE, or in general, for
   * outside C interfaces. 
   *)
  let t_of_raw iovec = {
    base = {count=1; base_iov=iovec};
    iov = iovec 
  } 
  let raw_of_t t = t.iov



  let t_of_iovec base iovec = {base = base; iov = iovec} 

  (* Decrement the refount, and free the cbuf if the count
   * reaches zero. 
   *)
  let free t =
    if t.base.base_iov.len >|| 0 then (
      if t.base.count <=|| 0 then (
	printf "Error, refcount already zero. len=%d\n" t.base.base_iov.len;
	flush stdout;
	raise (Invalid_argument "bad refcounting");
      );
      (*printf "free: len=%d\n" t.iov.len; flush stdout;  *)
      t.base.count <- pred t.base.count;
      if t.base.count =|| 0 then (
	(*printf "freeing base iovec: len=%d(\n" t.base.base_iov.len; flush stdout;*)
	free_cbuf t.base.base_iov.cbuf;
	(*print ")";*)
      )
    )

  (* Instead of using the raw malloc function, we take
   * memory chunks of size CHUNK from the user. We then
  * try to allocated from them any message that can fit. 
   * 1. If the request length fits into what remains of the current 
   *    chunk, it is allocated there.
   * 2. If the message is larger than CHUNK, then we allocate 
   *    directly using mm_alloc.
   * 3. Otherwise, allocate a new chunk and allocated from it.
   * 
   * Note that we waste the very last portion of the iovec. 
   * however, we assume that allocation is performed in slabs
   * of no more than 8K (max_msg_size), and so waste is less
   * than 10%.
   *)

  type alloc_state = {
    chunk_size : int ;
    mutable chunk : t ; (* The current chunk  *)
    mutable pos : int ;
  }

  let size = 32 * max_msg_size   (* Current size is 256K *)

  let s = 
    let raw = mm_alloc size in
    {
      chunk_size = size;
      chunk = {
	base=  {count=1; base_iov = raw};
	iov = raw
      };
      pos = 0 ;
    }

  let free_old_chunk () = 
    log (fun () -> "free_old_chunk");
    s.chunk.base.count <- pred s.chunk.base.count ;
    if s.chunk.base.count =|| 0 then (
      log (fun () -> "freeing old chunk");
      free_cbuf s.chunk.base.base_iov.cbuf;
    )

  let alloc len = 
    if s.chunk_size -|| s.pos >=|| len then (
      log (fun () -> sprintf "simple_alloc %d\n" len);
      let iov = mm_sub s.chunk.base.base_iov s.pos len in
      s.chunk.base.count <- succ s.chunk.base.count;
      s.pos <- s.pos +|| len;
      t_of_iovec s.chunk.base iov
    ) else 
      (* requested size too large, allocating a fresh (C) region.
       *)
      if len >=|| s.chunk_size then (
	log (fun () -> sprintf "large_alloc %d\n" len);
	let large_iov = mm_alloc len in
	t_of_iovec {count=1;base_iov=large_iov} large_iov
      ) else (
	(* Here we waste the end of the cached iovec.
	 * 
	 * We do 
	 * 1) Keep a refcount of 1 for the iovec we give out,
	 * 2) Another 1 that we free only after we've used
	 *    up the whole chunk size.
	 * 3) Decrement the refcount of the old chunk.
	 *)
	free_old_chunk ();
	let new_chunk = mm_alloc s.chunk_size in
	let iov = mm_sub new_chunk 0 len in
	s.chunk <- {base={count=2;base_iov=new_chunk}; iov=new_chunk};
	s.pos <- len;
	t_of_iovec s.chunk.base iov
      )

  (* check that there is enough space in the cached iovec before
   * a receive operation. 
   * 
   * This has two effects:
   * 1) we waste the end of the current 2.
   * iovecg) we save an exception being thrown from inside the
   *    the receive, because there will always be enough space.
   * 
   * Return a cbuf from which to start allocating.
   *)
  let check_pre_alloc () = 
    if s.chunk_size -|| s.pos <|| max_msg_size then (
      (* Here we waste the end of the cached iovec.
       *)
      free_old_chunk ();

      let raw = mm_alloc s.chunk_size in
      s.chunk <- {
	base = {count=1; base_iov=raw};
	iov = raw;
      };
      s.pos <- 0;
      mm_cbuf_sub s.chunk.base.base_iov 0
    ) else
      mm_cbuf_sub s.chunk.base.base_iov s.pos

  (* We have allocated [len] space from the cached iovec.
   * Update our postion in it.
   *)
  let advance len = 
    s.chunk.base.count <- succ s.chunk.base.count;
    s.pos <- s.pos +|| len;
    assert (s.pos <=|| s.chunk_size)
	
  let empty = 
    let iov = mm_empty () in
    t_of_iovec {count=1; base_iov=iov} iov

  let len t = t.iov.len

  let t_of_string s ofs len = 
    let t = alloc len in
    copy_string_into_raw s ofs len t.iov;
    t

  let string_of_t t = 
    let s = String.create (len t) in
    copy_raw_into_string t.iov s 0;
    s

  let string_of_t_full s ofs t = 
    copy_raw_into_string t.iov s ofs
     

  (* Create an iovec that points to a sub-string in [iov].
   *)
  let sub t ofs len = 
    if ofs +|| len >|| t.iov.len then 
      raise (Invalid_argument 
	(Printf.sprintf "out-of-bounds, in Iovec.sub ofs=%d len=%d act_len=%d"
	  ofs len t.iov.len)
      );
    t.base.count <- succ t.base.count;
    { 
      base = t.base;
      iov= mm_sub t.iov ofs len 
    } 


  (* Increment the refount, do not really copy. 
   *)
  let copy t = 
    log (fun () -> "copy");
    t.base.count <- succ t.base.count ;
    t
      
  let really_copy t = 
    if t.iov.len >|| 0 then (
      let new_iov = alloc t.iov.len in
      copy_raw_into_raw t.iov new_iov.iov;
      new_iov
    ) else
      empty


  (* Compute the total length of an iovec array.
   *)
  let iovl_len iovl = Array.fold_left (fun pos iov -> 
    pos +|| len iov
  ) 0 iovl

  (* Flatten an iovec array into a single iovec.  Copying only
   * occurs if the array has more than 1 non-empty iovec.
   * 
   * If there was not enough memory for the flatten operation,
   * then an empty buffer is returned.
   *)
  let flatten iovl = 
    match iovl with 
	[||] -> raise (Invalid_argument "An empty iovecl to flatten")
      | [|i|] -> copy i
      | _ -> 
	  let total_len = iovl_len iovl in
	  let iovl = Array.map (fun x -> x.iov) iovl in
	  let dst = alloc total_len in
	  mm_flatten iovl dst.iov;
	  dst

  let flatten_w_copy iovl = 
    match iovl with 
	[||] -> raise (Invalid_argument "An empty iovecl to flatten")
      | [|i|] -> really_copy i
      | _ -> 
	  let total_len = iovl_len iovl in
	  let iovl = Array.map (fun x -> x.iov) iovl in
	  let dst = alloc total_len in
	  mm_flatten iovl dst.iov;
	  dst
      
  (* For debugging
   *)
  let num_refs t = t.base.count


  external mm_marshal : 'a -> raw -> Marshal.extern_flags list -> int
    = "mm_output_val"

  external mm_unmarshal : raw -> 'a
    = "mm_input_val"

  let mm_marshal obj t flags = mm_marshal obj t.iov flags

  let marshal obj flags = 
    let space_left = s.chunk_size -|| s.pos in
    let tail = sub s.chunk s.pos space_left in
    try 
      let len = mm_marshal obj tail flags in
      advance len;
      let res = sub tail 0 len in
      free tail;
      res
    with Failure _ -> 
      (* Not enough space.
       * We waste the end of the cached iovec, and 
       * allocate a new chunk.
       *)
      free_old_chunk ();
      let raw = mm_alloc s.chunk_size in
      s.chunk <- {
	base = {count=1; base_iov=raw};
	iov = raw
      };
      s.pos <- 0;
      try 
	let len = mm_marshal obj s.chunk flags in
	advance len;
	sub s.chunk 0 len
      with Failure _ -> 
	(* The messgae is larger than a chunk size, hence too long.
	 *)
	failwith (sprintf "message is too longer (> %d)" s.chunk_size)

  let unmarshal t =  mm_unmarshal t.iov 

(*
  let _ = 
    printf "Running Socket iovec marshal/unmarshal sanity test\n"; flush stdout;
    let iov = alloc 100 in
    ignore (marshal (1,2,("A","B")) iov []);
    let obj = unmarshal iov in
    printf "xxx\n"; Pervasives.flush Pervasives.stdout;
    begin match obj with 
	x,y,(z,w) -> 
	  printf "x=%d, y=%d z=%s w=%s\n" x y z w
    end;
    printf "Passed)\n"; flush stdout;
    ()
*)

end

open Basic_iov

(**************************************************************)

let trace = 
  try 
    unit (Sys.getenv "SOCKET_TRACE") ;
    true 
  with Not_found -> 
    false

(**************************************************************)

type timeval = {
  mutable sec10 : int ;
  mutable usec : int
} 

external gettimeofday : timeval -> unit 
  = "skt_gettimeofday" "noalloc"

(**************************************************************)

type socket = Unix.file_descr

(**************************************************************)

external start_input : unit -> Unix.file_descr 
  = "skt_start_input"

(* See documentation in stdin.c.
 *)
let stdin =
  let stdin = ref None in
  if is_unix then (
    fun () -> Unix.stdin 
  ) else (
    fun () ->
      (*failwith "stdin not supported --- just for debugging";*)
      match !stdin with
	| None ->
	    let s = start_input () in
	    stdin := Some s ;
	    s
	| Some s -> s
  )

(**************************************************************)

external heap : unit -> Obj.t array 
  = "skt_heap"
external addr_of_obj : Obj.t -> string 
  = "skt_addr_of_obj"
external minor_words : unit -> int 
  = "skt_minor_words" "noalloc"
external frames : unit -> int array array 
  = "skt_frame_descriptors"

(**************************************************************)
external skt_recvfrom : socket -> buf -> ofs -> len -> len * Unix.sockaddr
  = "skt_recvfrom" 

let recvfrom s b o l = 
  if is_unix then Unix.recvfrom s b o l []
  else skt_recvfrom s b o l 


(* READ: Depending on the system, call either read or recv.
 * This is only used for stdin (where on Nt it is a socket).
 *)
external skt_recvfrom2 : socket -> buf -> ofs -> len -> len 
  = "skt_recvfrom2" 

let read =
  if is_unix then 
    fun s b o l -> Unix.read s b o l
  else
    fun s b o l -> skt_recvfrom2 s b o l

(**************************************************************)

type sock_info = (socket array) * (bool array)
type socket_info = (socket array) * (bool array)
type select_info = socket_info * socket_info * socket_info * int

external select : select_info -> timeval -> int 
  = "skt_select" "noalloc"
external poll : select_info -> int 
  = "skt_poll" "noalloc"

(**************************************************************)

external substring_eq : string -> ofs -> string -> ofs -> len -> bool 
  = "skt_substring_eq" "noalloc"

(**************************************************************)

(* HACK!  It's useful to be able to print these out as ints.
 *)
external int_of_file_descr : Unix.file_descr -> int
  = "skt_int_of_file_descr"

let int_of_socket s =
  int_of_file_descr s

(**************************************************************)
external skt_socket_mcast : 
  Unix.socket_domain -> Unix.socket_type -> int -> Unix.file_descr
    = "skt_socket_mcast"

external skt_socket : 
  Unix.socket_domain -> Unix.socket_type -> int -> Unix.file_descr
  = "skt_socket"

external skt_connect : Unix.file_descr -> Unix.sockaddr -> unit
  = "skt_connect"

external skt_bind : Unix.file_descr -> Unix.sockaddr -> unit
  = "skt_bind"

external skt_close : Unix.file_descr -> unit
  = "skt_close"

external skt_listen : Unix.file_descr -> int -> unit
  = "skt_listen"

external skt_accept : Unix.file_descr -> Unix.file_descr * Unix.sockaddr 
  = "skt_accept"

let socket dom typ proto = 
  let s = 
    if is_unix then Unix.socket dom typ proto 
    else skt_socket dom typ proto 
  in
  log (fun () -> sprintf "sock=%d\n" (int_of_socket s));
  s

let socket_mcast = 
  if is_unix then Unix.socket
  else skt_socket_mcast

let connect = 
  if is_unix then Unix.connect
  else skt_connect

let bind = 
  if is_unix then Unix.bind
  else skt_bind

(* will work only on sockets on WIN32.
*)
let close = 
  if is_unix then Unix.close
  else skt_close

let listen = 
  if is_unix then Unix.listen
  else skt_listen

let accept = 
  if is_unix then Unix.accept
  else skt_accept

(**************************************************************)
    
    
(* Optimized socket operations.
 * - unsafe
 * - no exceptions
 * - "noalloc" is enabled
 * - socket, flags, and address are preprocessed
 * - no interrupts accepted
 * - no retransmission attempts on interrupts
 *)


(* Pre-processed information on a socket.
*)
type sendto_info

(* A context structure.
*)
type ctx 

type digest = string (* A 16-byte string *)

external create_ctx : unit -> ctx 
  = "skt_Val_create_ctx"

external sendto_info : 
  Unix.file_descr -> Unix.sockaddr array -> sendto_info
    = "skt_Val_create_sendto_info"

external sendto : sendto_info -> buf -> ofs -> len -> unit
  = "skt_sendto" "noalloc"

(* These two functions are used to send UDP packets. 
 * They add a header describing the size of the ML/Iovec size 
 * of the data. 
 * The format is: [ml_len] [usr_len]
 * 
 * Corresponding code exists in udp_recv_packet. 
*)
external sendtov : sendto_info -> Basic_iov.t array -> unit 
  = "skt_sendtov" "noalloc"

external sendtosv : sendto_info -> buf -> ofs -> len -> Basic_iov.t array -> unit
  = "skt_sendtosv" "noalloc"

external skt_udp_recv_packet : 
  socket -> 
  Basic_iov.cbuf -> (* pre-allocated user-space memory *)
  string * Basic_iov.raw 
    = "skt_udp_recv_packet"

let udp_recv_packet sock = 
  (* check that there is enough memory, and return a cbuf for 
   * udp_recv.
   *)
  let cbuf = Basic_iov.check_pre_alloc () in
  let buf,iov = skt_udp_recv_packet sock cbuf in

  (* Update our position in the cached memory chunk.
   * On WIN32, since we don't have MSG_PEEK, we read everything into
   * user buffers. Hence, we need to copy the ML header into a string, 
   * and advance past 8byte pre-header + ML header + user-buffer.
   *)
  if iov.len >|| 0 then (
    if is_unix then 
      Basic_iov.advance iov.len
    else
      Basic_iov.advance (String.length buf + iov.len + 8);
    buf, Basic_iov.t_of_iovec s.chunk.base iov
  ) else
    buf, empty
  
    
(**************************************************************)
(* Receive messages into preallocated buffers. Exceptions are
 * thrown. 
 *)

external recv : socket -> buf -> ofs -> len -> len 
  = "skt_recv" "noalloc"
external recv_iov : socket -> Basic_iov.raw -> ofs -> len -> len 
  = "skt_recv_iov" "noalloc"
external tcp_recv_packet : socket -> string -> ofs -> len -> Basic_iov.raw -> len
  = "skt_tcp_recv_packet"

let recv_iov sock t ofs len = recv_iov sock t.Basic_iov.iov ofs len

let tcp_recv_packet sock buf ofs len t = 
  tcp_recv_packet sock buf  ofs len t.Basic_iov.iov

(**************************************************************)
(* Operations for sending messages point-to-point. 
 * 1) Exceptions are thrown
 * 2) nothing is allocated
 * 3) The length sent is returned
 * 4) The sendto parameter must contain a single destination. 
 *)
    
external send_p : socket -> buf -> ofs -> len -> len
  = "skt_send_p" "noalloc"

external sendv_p : socket -> Basic_iov.t array -> len
  = "skt_sendv_p" "noalloc"

external sendsv_p : socket -> buf -> ofs -> len -> Basic_iov.t array -> len
  = "skt_sendsv_p" "noalloc"

external sends2v_p : socket-> buf -> buf -> ofs -> len -> Basic_iov.t array -> len
  = "skt_sends2v_p_bytecode" "skt_sends2v_p_native" "noalloc"

(**************************************************************)

external has_ip_multicast : unit -> bool 
  = "skt_has_ip_multicast" 
external in_multicast : Unix.inet_addr -> bool 
  = "skt_in_multicast" 
external setsockopt_ttl : socket -> int -> unit 
  = "skt_setsockopt_ttl" 
external setsockopt_loop : socket -> bool -> unit 
  = "skt_setsockopt_loop" 
external setsockopt_join : socket -> Unix.inet_addr -> unit 
  = "skt_setsockopt_join" 
external setsockopt_leave : socket -> Unix.inet_addr -> unit 
  = "skt_setsockopt_leave" 
external setsockopt_sendbuf : socket -> int -> unit
  = "skt_setsockopt_sendbuf"
external setsockopt_recvbuf : socket -> int -> unit
  = "skt_setsockopt_recvbuf"
external setsockopt_nonblock : socket -> bool -> unit
  = "skt_setsockopt_nonblock"
external setsockopt_bsdcompat : socket -> bool -> unit
  = "skt_setsockopt_bsdcompat"
external setsockopt_reuse : socket -> bool -> unit
  = "skt_setsockopt_reuse"
let setsockopt_reuse sock onoff = 
  if is_unix then Unix.setsockopt sock Unix.SO_REUSEADDR onoff
  else setsockopt_reuse sock onoff
(**************************************************************)
(* MD5 hash functions. We need to have it work on Iovecs as
 * well as regular strings. 
*)
type md5_ctx = string

external md5_ctx_length : unit -> int
  = "skt_md5_context_length" "noalloc"
external md5_init : md5_ctx -> unit
  = "skt_md5_init" "noalloc"
external md5_init_full : md5_ctx -> string -> unit
  = "skt_md5_init_full" "noalloc"
external md5_update : md5_ctx -> buf -> ofs -> len -> unit
  = "skt_md5_update" "noalloc"
external md5_update_iov : md5_ctx -> Basic_iov.raw -> unit
  = "skt_md5_update_iov" "noalloc"
external md5_final : md5_ctx -> Digest.t -> unit
  = "skt_md5_final" "noalloc"

let md5_init () =
  let ret = String.create (md5_ctx_length ()) in
  md5_init ret ;
  ret

let md5_init_full init_key =
  if String.length init_key <> 16 then 
    raise (Invalid_argument "md5_init_full: initial key value is not of length 16");
  let ret = String.create (md5_ctx_length ()) in
  md5_init_full ret init_key;
  ret


let md5_final ctx =
  let dig = String.create 16 in
  md5_final ctx dig ;
  dig

let md5_update_iov ctx iov_t = 
  md5_update_iov ctx iov_t.Basic_iov.iov

(**************************************************************)

let sihelp (socks,ret) =
  let max = ref 0 in
  Array.iter (fun sock ->
    let sock = int_of_socket sock in
    if sock > !max then max := sock
  ) socks ;
  ((socks,ret),!max)

let select_info a b c =
  let (a,am) = sihelp a in
  let (b,bm) = sihelp b in
  let (c,cm) = sihelp c in
  let max = succ (max am (max bm cm)) in
  (a,b,c,max)

(**************************************************************)
type win = 
    Win_3_11
  | Win_95_98
  | Win_NT_3_5
  | Win_NT_4
  | Win_2000

type os_t_v = 
    OS_Unix
  | OS_Win of win

external win_version : unit -> string = "win_version"

let os_type_and_version () = 
  let v = ref None in
  match !v with 
      Some x -> x
    | None -> 
	let ver = 
	  if is_unix then OS_Unix
	  else (
	    let version = 
	      match win_version () with
		  "NT3.5" -> Win_NT_3_5
		| "NT4.0" -> Win_NT_4
		| "2000" -> Win_2000
		| "95/98" -> Win_95_98
		| "3.11" -> Win_3_11
		| _ -> failwith "Sanity: win_version returned bad value"
	    in
	    OS_Win version
	  ) in
	v := Some ver;
	ver

(**************************************************************)
let is_unix = is_unix

(**************************************************************)

