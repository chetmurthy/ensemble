(**************************************************************)
(* SOCKET.MLI *)
(* Authors: Robbert vanRenesse and Mark Hayden, 4/95  *)
(* Ohad Rodeh :                                       *)
(*         C-Memory mangement support          9/2001 *)
(*         Winsock2 support                   11/2001 *)
(*         Rewrite                            12/2003 *)
(**************************************************************)
val max_msg_size : int

type socket = Unix.file_descr
type buf = string
type ofs = int
type len = int

type timeval = {
  mutable sec10 : int ;
  mutable usec : int
} 

type win = 
    Win_3_11
  | Win_95_98
  | Win_NT_3_5
  | Win_NT_4
  | Win_2000

type os_t_v = 
    OS_Unix
  | OS_Win of win

(* Set the verbosity level
*)
val set_verbose : bool -> unit

exception Out_of_iovec_memory

module Iov : sig 
  (* The type of a C memory-buffer. It is opaque.
   *)
  type t 

  type pool

  (* initialize the memory-manager. 
   * [init verbose chunk_size max_mem_size send_pool_pcnt min_alloc_size incr_step]
   *)
  val init : bool -> int -> int -> float -> int -> int -> unit
    
  (* Release all the memory used, assuming none is allocated *)
  val shutdown : unit -> unit

  (* The pool of sent-messages *)
  val get_send_pool : unit -> pool
    
  (* The pool of recv-messages *)
  val get_recv_pool : unit -> pool

  (* allocation, and copy. 
   *)
  val string_of_t : t -> string 
  val string_of_t_full : string -> len -> t -> unit
  val t_of_string : pool -> string -> ofs -> len -> t
    
  val len : t -> int

  val empty : t 

  val alloc_async : pool -> len -> (t -> unit) -> unit

  val alloc : pool -> len -> t

  val satisfy_pending : unit -> unit

  val sub : t -> ofs -> len -> t
    
  (* Decrement the refount, and free the cbuf if the count
   * reaches zero. 
   *)
  val free : t -> unit 
    
  (* Increment the refount, do not really copy. 
   *)
  val copy : t -> t 

  (* Flatten an iovec array into a single iovec.  Copying only
   * occurs if the array has more than 1 non-empty iovec.
   *)
  val flatten : t array -> t

  (* For debugging. The number of references to the iovec.
   *)
  val num_refs : t -> int

  (* Marshal into a preallocated iovec. Raise's exception if
   * there is not enough space. Returns the marshaled iovec.
   *)
  val marshal : pool -> 'a -> Marshal.extern_flags list -> t

  (* Unmarshal directly from an iovec. Raises an exception if there
   * is a problem, and checks for out-of-bounds problems. 
   *)
  val unmarshal : t -> 'a

  (* statistics *)
  val get_stats : unit -> string

end
  
(**************************************************************)
(* Open a file descriptor for reading from stdin.  This is
 * for compatibility with Windows NT.  See
 * ensemble/socket/stdin.c for an explanation.  
 *)
val stdin : unit -> socket

(* For reading from stdin.
 *)
val read : socket -> buf -> ofs -> len -> len

(**************************************************************)

type sock_info = (socket array) * (bool array)
type select_info
val select_info : sock_info -> sock_info -> sock_info -> select_info

val select : select_info -> timeval -> int
val poll : select_info -> int

(**************************************************************)

(* Check if portions of two strings are equal.
 *)
val substring_eq : string -> ofs -> string -> ofs -> len -> bool

(**************************************************************)
(* Optimized transmission functions.  No exceptions are
 * raised.  Scatter-gather used if possible.  No interrupts
 * are serviced during call.  No bounds checks are made.
 *)

val recvfrom : socket -> buf -> ofs -> len -> len * Unix.sockaddr

(* A context structure.
*)
type sendto_info
val sendto_info : socket -> Unix.sockaddr array -> sendto_info

(* The returned length only refers to the last buffer sent. 
 * It is used only when using TCP sockets.
*)
val udp_send : sendto_info -> buf -> ofs -> len -> unit
val udp_mu_sendsv : sendto_info -> buf -> ofs -> len -> Iov.t array -> unit

(* Recv a packet in Ensemble format.  
 * [udp_mu_recv_packet sock prealloc_buf] returns [mllen, iovec]
 * 
 * It attempts to recive a packet where the header will be copied into
 * the preallocated buffer. The bulk data will be allocated inside an
 * iovec. The length of the ml-header is returned.
 *)
val udp_mu_recv_packet : Iov.pool -> socket -> string -> len * Iov.t

(* These functions are used in Hsyssupp in receiving 
 * TCP packets. 
 *)
val tcp_send : socket -> buf -> ofs -> len -> len
val tcp_sendv : socket -> Iov.t array -> len
val tcp_sendsv : socket -> buf -> ofs -> len -> Iov.t array -> len
val tcp_sends2v : socket -> buf -> buf -> ofs -> len -> Iov.t array -> len
val tcp_recv : socket -> string -> ofs -> len -> len
val tcp_recv_iov : socket -> Iov.t -> ofs -> len -> len
val tcp_recv_packet : socket -> string -> ofs -> len -> Iov.t -> len

(**************************************************************)

(*** Multicast support. *)

(* Return whether this host supports IP multicast. 
 *)
val has_ip_multicast : unit -> bool 

(* Is this a class D address ?
*)
val in_multicast : Unix.inet_addr -> bool

(* Setup the TTL value
 *)
val setsockopt_ttl : socket -> int -> unit 

(* Setup the loopback switch
 *)
val setsockopt_loop : socket -> bool -> unit 

(* Join an IP multicast group. 
 *)
type mcast_send_recv = 
  | Recv_only
  | Send_only
  | Both

val setsockopt_join : socket -> Unix.inet_addr -> mcast_send_recv -> unit 

(* Leave an IP multicast group. 
 *)
val setsockopt_leave : socket -> Unix.inet_addr -> unit 

(**************************************************************)

(* Set size of sending buffers.
 *)
val setsockopt_sendbuf : socket -> int -> unit

(* Set size of receiving buffers.
 *)
val setsockopt_recvbuf : socket -> int -> unit

(* Set socket to be blocking/nonblocking.
 *)
val setsockopt_nonblock : socket -> bool -> unit

(* Set socket ICMP error reporting.  See sockopt.c.
 *)
val setsockopt_bsdcompat : socket -> bool -> unit

(* Set the socket to reusable (or not).
*)
val setsockopt_reuse : socket -> bool -> unit

(**************************************************************)
(* MD5 support.
 *)
type md5_ctx
val md5_init : unit -> md5_ctx
val md5_init_full : string -> md5_ctx
val md5_update : md5_ctx -> buf -> ofs -> len -> unit
val md5_update_iov : md5_ctx -> Iov.t -> unit
val md5_final : md5_ctx -> Digest.t

(**************************************************************)

(* HACK!  It's useful to be able to print these out as ints.
 *)
val int_of_socket : socket -> int

(* On WIN32 we need to use WINSOCK2's calls, instead of
 * regular ones. Since Caml uses WINSOCK1 for maximum portability, we 
 * need to override this for WIN32.
 *)
val socket : Unix.socket_domain -> Unix.socket_type -> int -> Unix.file_descr
val socket_mcast : Unix.socket_domain -> Unix.socket_type -> int -> Unix.file_descr
val connect : Unix.file_descr -> Unix.sockaddr -> unit
val bind : Unix.file_descr -> Unix.sockaddr -> unit

(* Will work only on sockets on win32.
*)
val close : Unix.file_descr -> unit

val listen : Unix.file_descr -> int -> unit
val accept : Unix.file_descr -> Unix.file_descr * Unix.sockaddr
(**************************************************************)

(* Same as Unix.gettimeofday.  Except that
 * the caller passes in a timeval object that
 * the time is returned in.
 *)
val gettimeofday : timeval -> unit

(**************************************************************)
(* Return the version of the OS.
 *)
val os_type_and_version : unit -> os_t_v
val is_unix : bool
(**************************************************************)


      

  
