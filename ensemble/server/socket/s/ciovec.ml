(**************************************************************)
(* NATIOV.ML : Memory management functions. *)
(* Author: Ohad Rodeh 10/2002 *)
(* Rewrite:           12/2003 *)
(**************************************************************)
open Printf
open Socksupp
(**************************************************************)
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
(**************************************************************)

let log f = ()
(*let s = f () in
  print_string "CIOVEC:"; print_string s; print_string "\n"; flush stdout *)


(* The type of a C memory-buffer. It is opaque.
 *)
type cbuf  
type buf = string
type ofs = int
type len = int

type base = {
  cbuf : cbuf;         (* Free this cbuf when the refcount reaches zero *)
  total_len : int;     (* The total length of the C-buffer *)
  id : int;            (* The identity of this chunk *)
  mutable count : int; (* A reference count *)
  pool : pool          (* Which pool does this chunk belong to *)
}
    
(* An iovector is an extent out of a C-buffer *)
and t = { 
  base : base ;  
  ofs : int ;
  len : int
}

and pool = {
  name  : string;                     (* SEND/RECV *)
  size : int ;                      (* The total size of the pool *)
  free_chunks : base Queue.t;       (* The set of free chunks *)
  mutable chunk_array : base array; (* The whole set of chunks *)
  mutable chunk : base option;      (* The current chunk  *)
  mutable pos : int ;
  mutable allocated : int;          (* The total allocated space *)
  mutable pending : (len * (t -> unit)) Queue.t (* A list of pending allocation requests *)
}
    
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
  mutable initialized : bool;
  mutable verbose : bool;
  mutable chunk_size : int ;             
  mutable min_alloc_size : int;
  mutable incr_step : int;               (* By how many chunks to increase a pool 
                                            when it dries up *)
  mutable maximum : int ;                (* The maximum allowed size of memory *)
  mutable send_pool : pool option;       (* A pool for sent-messages *)
  mutable recv_pool : pool option;       (* A pool for receiving messages *)
  mutable extra_pool : pool              (* A pool for all extra memory. *)
}

(**************************************************************)
external copy_cbuf_ext_to_string : cbuf -> ofs -> string -> ofs -> len -> unit
  = "mm_copy_cbuf_ext_to_string" "noalloc"
    
external copy_string_to_cbuf_ext : string -> ofs -> cbuf -> ofs -> len -> unit
  = "mm_copy_string_to_cbuf_ext" "noalloc"
    
external copy_cbuf_ext_to_cbuf_ext : cbuf -> ofs -> cbuf -> ofs -> len -> unit
  = "mm_copy_cbuf_ext_to_cbuf_ext" "noalloc"
    
external free_cbuf : cbuf -> unit 
  = "mm_cbuf_free" "noalloc"
    
(* Flatten an array of iovectors. The destination iovec is
 * preallocated.
 *)
external mm_flatten : t array -> t -> unit
  = "mm_flatten" "noalloc"
    
(* Raw (C) allocation function. Can be user defined.
 *)
external mm_alloc : int -> cbuf
  = "mm_cbuf_alloc"
    
(* Create an empty iovec. We do this on the C side, so
 * that it will be usable by C functions that may return
 * empty Iovec's.
 *)
external mm_empty : unit -> cbuf
  = "mm_empty"
    
external mm_marshal : 'a -> cbuf -> ofs -> len -> Marshal.extern_flags list -> int
  = "mm_output_val"
    
external mm_unmarshal : cbuf -> ofs -> len -> 'a
  = "mm_input_val"
    
(**************************************************************)
let string_of_list     f l = sprintf "[%s]" (String.concat "|" (List.map f l))
let string_of_array    f a = string_of_list f (Array.to_list a)
  
(* Initialization section *)    

let create_empty_pool name = {
  name = name;
  size = 0;
  free_chunks = Queue.create ();
  chunk_array = [||];
  chunk = None;
  pos = 0;
  allocated = 0;
  pending = Queue.create ()
}
  
let s = {
  initialized = false;
  verbose = true;
  chunk_size = 0;
  min_alloc_size = 0;
  incr_step = 0;
  maximum = 0;
  send_pool = None;
  recv_pool = None;
  extra_pool = create_empty_pool "Invalid"
}
  
let create_pool name size chunk_size =
  let num_chunks = size / chunk_size in
  if num_chunks = 0 then 
    failwith (sprintf "initialization: zero chunks in pool <%s>" name);
  if num_chunks < 4 then (
    printf "CIOVEC: warning: you'll have bad memory utilization with less than 4 chunks\n";
    flush stdout;
  );
  let pool = {
    name = name;
    size = size;
    free_chunks = Queue.create ();
    chunk_array = [||];
    chunk = None;
    pos = 0;
    allocated = 0;
    pending = Queue.create ();
  } in
  let chunk_array = Array.init num_chunks (fun i -> 
    let cbuf = mm_alloc chunk_size in  {
      cbuf = cbuf;
      total_len = chunk_size;
      id = i;
      count=0; 
      pool = pool;
    }
  ) in
  Array.iter (fun chunk -> Queue.add chunk pool.free_chunks) chunk_array;
  pool.chunk_array <- chunk_array;
  let init_chunk = Queue.pop pool.free_chunks in
  init_chunk.count <- 1;
  pool.chunk <- Some init_chunk;
  pool

let clear_pool pool = 
  Queue.clear pool.free_chunks;
  Array.iter (fun chunk -> free_cbuf chunk.cbuf) pool.chunk_array;
  pool.chunk_array <- [||];
  pool.chunk <- None;
  pool.pos <- 0;
  pool.allocated <- 0;
  Queue.clear pool.pending;
  ()

let grow_pool pool = 
  if Array.length pool.chunk_array * s.chunk_size > 100 * 1024 * 1024 then
    failwith "Pool size will grow beyond 100Mbytes. This is too much, exiting";

  (* create new chunks *)
  let base_len = 1 + Array.length pool.chunk_array in
  let new_chunks = Array.init s.incr_step (fun i -> 
    let cbuf = mm_alloc s.chunk_size in  {
      cbuf = cbuf;
      total_len = s.chunk_size;
      id = i + base_len;
      count=0; 
      pool = pool;
    }
  ) in
  (* add them to free list *)
  Array.iter (fun chunk -> Queue.add chunk pool.free_chunks) new_chunks;
  (* resize the array *)
  pool.chunk_array <- Array.append pool.chunk_array new_chunks;
  ()


let get_pool_stats pool = 
  sprintf "refs=%s pos=%d alloced=%d"
    (string_of_array (fun chunk -> sprintf "%d" chunk.count) pool.chunk_array)
    pool.pos
    pool.allocated

(* initialize the memory-manager. 
 * [init chunk_size max_mem_size min_alloc_size]
 *)
let init verbose chunk_size max_mem_size send_pool_pcnt min_alloc_size incr_step = 
  if s.initialized then 
    failwith "sanity: initializing the memory-manager twice";
  s.verbose <- verbose;
  s.initialized <- true;
  s.chunk_size <- chunk_size;
  s.maximum <- max_mem_size;
  s.min_alloc_size <- min_alloc_size;
  s.incr_step <- incr_step;
  if s.verbose then (
    printf "ciovec, chunk_size=%d  max_mem_size=%d\n" chunk_size max_mem_size;
    flush stdout;
  );

  let send_pool_size = (float_of_int max_mem_size) *. send_pool_pcnt in
  let send_pool_size = int_of_float send_pool_size in
  let recv_pool_size = max_mem_size - send_pool_size in
  if send_pool_size >|| 0 then
    s.send_pool <- Some (create_pool "Send" send_pool_size chunk_size);
  if recv_pool_size >|| 0 then
    s.recv_pool <- Some (create_pool "Recv" recv_pool_size chunk_size)
  
(* Release all the memory used *)
let shutdown () = 
  (* No memory is allocated, everything can be released *)
  s.initialized <- false;
  s.verbose <- false;
  s.chunk_size <- 0;
  s.min_alloc_size <- 0;
  s.maximum <- 0;

  (* If there is memory allocated --- fail *)
  begin match s.send_pool with
    | None -> ()
    | Some pool -> 
	if pool.allocated > 0 then
	  failwith "cannot free the resources used the memory-manager";
      clear_pool pool
  end;
  begin match s.recv_pool with
    | None -> ()
    | Some pool -> 
	if pool.allocated > 0 then
	  failwith "cannot free the resources used the memory-manager";
      clear_pool pool
  end;
  ()

(**************************************************************)
let get_send_pool () = match s.send_pool with 
  | None -> failwith "the send pool has not been initialized yet"
  | Some pool -> pool

let get_recv_pool () = match s.recv_pool with 
  | None -> failwith "the receive pool has not been initialized yet"
  | Some pool -> pool

(**************************************************************)
let get_stats () = 
  sprintf "send_pool={%s}  recv_pool={%s}" 
    (get_pool_stats (get_send_pool ()))
    (get_pool_stats (get_recv_pool ()))

(**************************************************************)

let len t = t.len
  
let num_refs t = t.base.count
  
let chunk_sub chunk ofs len = 
  assert (chunk.total_len >=|| ofs +|| len);
  chunk.count <- succ chunk.count;
  {base=chunk; ofs=ofs; len=len}
  
let empty_cbuf = mm_empty ()
  
let empty = 
  let empty_chunk = {
    cbuf=mm_empty (); 
    total_len = 0;
    count=1; 
    id=(-1);
    pool = s.extra_pool
  } in
  {base=empty_chunk; ofs=0; len=0}
  
let alloc_new_chunk pool = 
  log (fun () -> "alloc_new_chunk");
  let chunk = Queue.pop pool.free_chunks in
  assert(chunk.count =|| 0);
  chunk.count <- 1;
  pool.pos <- 0;
  pool.chunk <- Some chunk;
  ()
  
let free_chunk_and_refresh chunk= 
  log (fun () -> sprintf "free_chunk_and_refresh chunk.count=%d allocated=%d id=%d" 
    chunk.count chunk.pool.allocated chunk.id);
  let pool = chunk.pool in
  assert (pool.allocated >=|| 0);
  assert (chunk.count =|| 0);
  if chunk.id <>|| (-1) then (
    pool.allocated <- pool.allocated -|| s.chunk_size;
    Queue.add chunk pool.free_chunks;
    match pool.chunk with 
      | None -> alloc_new_chunk pool
      | Some _ -> ()
  ) else (
    (* This isn't a chunk for reuse, it is an extra chunk for an ML application *)
    free_cbuf chunk.cbuf;
  )
    
(* Decrement the ref-count of the old chunk. Allocate a new chunk if possible.
 *)
let free_old_chunk_alloc_new pool = 
  let chunk = some_of pool.chunk in
  (* Account for the wasted area *)
  let len = s.chunk_size -|| pool.pos in
  pool.allocated <- pool.allocated +|| len;
  
  (* reduce ref-count so we can reclaim the space *)
  chunk.count <- pred chunk.count ;
  assert (chunk.count >=|| 0);
  pool.chunk <- None;
  
  log (fun () -> sprintf "free_old_chunk, num_refs=%d" chunk.count);
  if chunk.count =|| 0 then (
    log (fun () -> "actually free old-chunk");
    free_chunk_and_refresh chunk;
    true
  ) else if not (Queue.is_empty pool.free_chunks) then (
    alloc_new_chunk pool;
    true
  ) else (
    false
  )
    
(* Decrement the refount, and free the cbuf if the count
 * reaches zero. 
 *)
let free t =
  if t.base.total_len >|| 0 then (
    log (fun () -> sprintf "free len=%d pool=%s" t.len t.base.pool.name);
    if t.base.count <=|| 0 then
      raise (Invalid_argument (sprintf 
        "bad refcounting chunk_id=%d iov.base.total_len=%d" t.base.id t.base.total_len)
      );
    (*log (fun () -> sprintf "free: len=%d" t.iov.len);*)
    t.base.count <- pred t.base.count;
    if t.base.count =|| 0 then (
      log (fun () -> sprintf "freeing a buffer (len=%d)" t.base.total_len);
      ignore (free_chunk_and_refresh t.base)
    );
  )
    
    
(* make sure that the current chunk has at least a minimal amount of memory left
 *)
let normalize_chunk pool = 
  if s.chunk_size -|| pool.pos <|| s.min_alloc_size then (
    log (fun () -> "exec normalize_chunk");
    ignore (free_old_chunk_alloc_new pool)
  )
    
(* Allocate the rest of the chunk. Don't allocate another one because we may
 * be out of memory. 
 *)
let alloc_from_current_chunk pool chunk len = 
  log (fun () -> sprintf "simple_alloc len=%d pool=%s" len pool.name);
  pool.allocated <- pool.allocated +|| len;
  let iov = chunk_sub chunk pool.pos len in
  pool.pos <- pool.pos +|| len;
  normalize_chunk pool;
  iov
    
let alloc pool len = 
  if len >|| 0 then (
    match pool.chunk with 
        None -> raise Out_of_iovec_memory
      | Some chunk -> 
          if s.chunk_size -|| pool.pos >=|| len then (
            (* Normal case, there is enough space in the current chunk. Allocate
             * there. 
             *)
            log (fun () -> sprintf "alloc from chunk %d" len);
            alloc_from_current_chunk pool chunk len
          )
          else if pool.allocated +|| len >|| pool.size then (
            (* There isn't enough space  *)
            log (fun () -> sprintf "not enough space, allocated=%d len=%d max=%d\n" 
              pool.allocated len pool.size);
            raise Out_of_iovec_memory
          ) 
          else if len >=|| s.chunk_size then (
            (* requested size too large  *)
            failwith (sprintf "message is longer than chunk size (req=%d, chunk=%d)" 
              len s.chunk_size)
          )
          else (
            (* Here we waste the end of the cached iovec. *)
            log (fun () -> sprintf "waste end of iovec %d" (s.chunk_size - pool.pos));
            if free_old_chunk_alloc_new pool then 
              alloc_from_current_chunk pool (some_of pool.chunk) len
            else
              raise Out_of_iovec_memory
          )
  ) else (
    empty
  )
    
(* Add request to pending list
 *)
let alloc_async pool len cont_fun = 
  if len >|| 0 then (
    log (fun () -> sprintf "adding request for (%d bytes) to pending list" len);
    Queue.add (len, cont_fun) pool.pending
  ) else (
    cont_fun empty      
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
let check_pre_alloc pool = 
  match pool.chunk with 
    | None -> false
    | Some chunk -> 
        if s.chunk_size -|| pool.pos >=|| max_msg_size then (
          (* Normal case, there is enough space in the current chunk. Allocate
           * there. 
           *)
          log (fun () -> sprintf "prealloc from current chunk %d" max_msg_size);
          true
        )
        else if pool.allocated +|| max_msg_size >|| s.maximum then (
          (* There isn't enough space  *)
          log (fun () -> sprintf "prealloc: not enough space, allocated=%d len=%d max=%d"
            pool.allocated max_msg_size s.maximum);
          false
        )
        else (
          (* Here we waste the end of the cached iovec. *)
          log (fun () -> sprintf "prealloc: waste end of iovec %d" 
	    (s.chunk_size-||pool.pos));
          if free_old_chunk_alloc_new pool then 
            true
          else
            false
        )
          
(* We have allocated [len] space from the cached iovec.
 * Update our postion in it.
 *)
let advance_and_sub_alloc pool total_len ofs len= 
  (* This isn't very good. We assume advance works hand-in-hand with pre_alloc. 
   *)
  let chunk = some_of pool.chunk in
  let iov = chunk_sub chunk (pool.pos +|| ofs) len in
  pool.pos <- pool.pos +|| total_len;
  assert (pool.pos <=|| s.chunk_size);
  pool.allocated <- pool.allocated +|| total_len;
  iov
    

let rec satisfy_pending_pool pool = 
  if Queue.is_empty pool.pending then () 
  else (
    let (len,conf_fun) = Queue.peek pool.pending in
    if pool.allocated +|| len >|| s.maximum then  (
      (* There is not enough space, we need to wait until space free's up  *)
      log (fun () -> sprintf "satisfy_pending: not enough space (allocated=%dK) (req=%d)"
        (pool.allocated/1024) len);
    ) else (
      (* PERF: We're catching the exception here so as to have a tail-loop struct *)
      let iov = 
        try alloc pool len 
        with Out_of_iovec_memory -> 
          log (fun () -> sprintf "No iovec space to satisfy requests refs=%s"
	    (string_of_array (fun chunk -> sprintf "%d" chunk.count) pool.chunk_array));
          empty
      in
      (* We can satisfy the request right now   *)
      log (fun () -> sprintf "satisfy_request");
      if iov.len >|| 0 then (
        ignore (Queue.pop pool.pending);
        conf_fun iov;
        
        (* Continue with the rest of the requests  *)
        log (fun () -> sprintf "satisfy_pending[2]");
        satisfy_pending_pool pool
      )
    )
  )
    
let satisfy_pending_pool_opt = function
  | None -> ()
  | Some pool -> satisfy_pending_pool pool
	
let satisfy_pending () = 
  satisfy_pending_pool_opt s.recv_pool;
  satisfy_pending_pool_opt s.send_pool
    
let t_of_string pool s ofs len = 
  let t = alloc pool len in
  copy_string_to_cbuf_ext s ofs t.base.cbuf t.ofs len;
  t
    
let string_of_t t = 
  assert (num_refs t >|| 0);
  (*    log (fun () -> sprintf "string_of_t: num_refs=%d len=%d" (num_refs t) (len t));*)
  let s = String.create (len t) in
  copy_cbuf_ext_to_string t.base.cbuf t.ofs s 0 t.len;
  s
    
let string_of_t_full s ofs t = 
  assert (num_refs t >|| 0);
  copy_cbuf_ext_to_string t.base.cbuf t.ofs s ofs t.len 
    
    
(* Create an iovec that points to a sub-string in [iov].
 *)
let sub t ofs len = 
  assert (num_refs t >|| 0);
  assert (ofs +|| len <=|| t.len);
  t.base.count <- succ t.base.count;
  { 
    base = t.base;
    ofs = t.ofs +|| ofs;
    len = len;
  } 
  
(* Increment the refount, do not really copy. 
 *)
let copy t = 
  assert (num_refs t >|| 0); 
  t.base.count <- succ t.base.count ;
  t
    
(* Compute the total length of an iovec array.
 *)
let iovl_len iovl = Array.fold_left (fun pos iov -> 
  assert (num_refs iov >|| 0);
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
	let pool = iovl.(0).base.pool in
	let total_len = iovl_len iovl in
	let dst = alloc pool total_len in
	mm_flatten iovl dst;
	dst
	  
(**************************************************************)
(* Optimized marshal/unmarshal
*)

(* Marshal an ML object into the tail of the current chunk. Can throw a Failure
 * exception if there isn't sufficient space. 
 *)
let marshal_to_current_chunk pool obj flags = 
  match pool.chunk with 
    | Some chunk -> 
        let len = mm_marshal obj chunk.cbuf pool.pos (s.chunk_size -|| pool.pos) flags in
        let iov = chunk_sub chunk pool.pos len in
        pool.pos <- pool.pos +|| len;
        assert (pool.pos <=|| s.chunk_size);
        pool.allocated <- pool.allocated +|| len;
        log (fun () -> sprintf 
          "marshal_to_current_chunk mllen=%d allocated=%d" len pool.allocated);
        normalize_chunk pool;
        iov
    | None -> failwith "sanity: marshal_into_current_chunk called with a null chunk"
        
(* There is no more space in the iovec system. Allocate a fresh iovec for this
 * purpose.
 *)
let marshal_to_fresh_iov pool obj flags = 
  let mlstr = Marshal.to_string obj flags in
  let mllen = String.length mlstr in  
  log (fun () -> sprintf "marshal_to_fresh_iov mllen=%d" mllen);
  let cbuf = mm_alloc mllen in
  copy_string_to_cbuf_ext mlstr 0 cbuf 0 mllen;
  let iregular_chunk = {
    cbuf = cbuf;
    total_len = mllen;
    id = (-1);     (* -1 denotes that this isn't a regular chunk *)
    count=1; 
    pool=s.extra_pool;
  } in
  {base= iregular_chunk; ofs=0; len=mllen}
  
(* Marshal ML object into an iovec *)
let marshal pool obj flags =
  match pool.chunk with 
    | Some chunk -> 
        begin
          try 
            (* 1. Try to marshal into the end of the current iovec. *)
            marshal_to_current_chunk pool obj flags
          with Failure _ -> 
            (* 2. There isn't enough space in current chunk. 
             * free current chunk, and allocated a new one.  
             *)
            if free_old_chunk_alloc_new pool then (
              try 
                marshal_to_current_chunk pool obj flags
              with Failure _ -> 
                (* 3. unsuccessful: the message is too large. *)
                marshal_to_fresh_iov pool obj flags
            ) else (
              (* 4. No iovec memory left. *)
              marshal_to_fresh_iov pool obj flags
            )
        end
    | None -> 
        (* 5. No iovec memory left. *)
        marshal_to_fresh_iov pool obj flags
        
	
let unmarshal t =  
  assert (num_refs t >|| 0);
  mm_unmarshal t.base.cbuf t.ofs t.len
    
(**************************************************************)

