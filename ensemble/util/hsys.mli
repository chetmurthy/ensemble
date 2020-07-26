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
(* HSYS.MLI *)
(* Author: Mark Hayden, 5/95 *)
(**************************************************************)

type debug = string
type buf = string
type ofs = int
type len = int
type port = int
type inet
type socket

type timeval = {
  mutable sec10 : int ;
  mutable usec : int
} 

(**************************************************************)
(* The following are essentially the same as the functions of
 * the same name in the Unix library.
 *)

val accept : socket -> socket * inet * port
val bind : socket -> inet -> port -> unit
val close : socket -> unit
val connect : socket -> inet -> port -> unit
val gethost : unit -> inet
val getlocalhost : unit -> inet
val gethostname : unit -> string
val getlogin : unit -> string
val getpeername : socket -> inet * port
val getsockname : socket -> inet * port
val gettimeofday : unit -> timeval
val inet_any : unit -> inet
val inet_of_string : string -> inet
val listen : socket -> int -> unit
val read : socket -> buf -> ofs -> len -> int
val recv : socket -> buf -> ofs -> len -> int
val recvfrom : socket -> buf -> int -> int -> int * inet * port
val send : socket -> buf -> ofs -> len -> int
val string_of_inet : inet -> string	(* i.e. gethostbyname *)
val string_of_inet_nums : inet -> string
val getenv : string -> string option
val getpid : unit -> int

(**************************************************************)

(* Bind to any port.  Returns port number used.
 *)
val bind_any : debug -> socket -> inet -> port

(**************************************************************)

(* This only returns the host name and none of the
 * domain names (everything up to the first '.'.
 *)
val string_of_inet_short : inet -> string

(**************************************************************)

(* Create a random deering address given an integer 'seed'.
 *)
val deering_addr : int -> inet

(**************************************************************)

(* Generate a string representation of an exception.
 *)
val error : exn -> string

(* Same as Printexc.catch.
 *)
val catch : ('a -> 'b) -> 'a -> 'b

(**************************************************************)

(* Same as Unix.gettimeofday, except that a timeval record
 * is passed in and the return value is written there.  See
 * ensemble/socket/socket.mli for an explanation.  
 *)
val gettimeofdaya : timeval -> unit

(**************************************************************)

(* Was Ensemble compiled with ip multicast and does this host
 * support it.
 *)
val has_ip_multicast : unit -> bool

(**************************************************************)

(* Integer value of a socket.  For debugging only.  On Unix,
 * this gives the file descriptor number.  On Windows, this
 * gives the handle number, which is somewhat different from
 * Unix file descriptors.  
 *)
val int_of_socket : socket -> int

(**************************************************************)

(* The maximum length of messages on the network. 
 *)
val max_msg_len : unit -> int

(**************************************************************)

(* A variation on fork().  [open_process command input]
 * creates a process of the given name and writes [input] to
 * its standard input.  Returns a tuple, where the first
 * entry specifies if the process exited successful.  The
 * second value is the standard output, and the third value
 * is the standard error.  
 *)
val open_process : string -> string array -> string -> (bool * string * string)

val background_process : string -> string array -> string -> (int * socket * socket)

(**************************************************************)

(* Handlers that are used for the pollinfo/polling
 * functions.  The first kind of handler specifies a
 * callback to make when there is data ready to read on the
 * socket.  The second kind of handler specifies that the
 * polling function is to recv() data from the socket into
 * its own buffer and pass the data up a central handler
 * (specified in the call to the pollinfo() function).  
 *)
type handler =
  | Handler0 of (unit -> unit)
  | Handler1

(**************************************************************)
(*
(* Read/write an integer to a string in network byte
 * order.
 *)
val pop_nint : buf -> ofs -> int
val push_nint : buf -> ofs -> int -> unit

(* INT_OF_SUBSTRING: read a 4-byte integer in host
 * byte order.
 *)
val int_of_substring : buf -> ofs -> int
*)
(**************************************************************)

(* This is an optimized version of the select function.  You
 * passing in select_info arguments for the read, write, and
 * exception conditions, as with normal select.  However,
 * this function specifies which sockets have data by
 * modifying the boolean values in the array that are
 * associated with the appropriate socket.  
 *)

(* Note: both arrays here should be of the same length.
 *)
type sock_info = ((socket array) * (bool array)) option
type select_info

val select_info : sock_info -> sock_info -> sock_info -> select_info

val select : select_info -> timeval -> int

(* This is the same as select, except that the timeout is
 * always 0.0.  
 *)
val poll : select_info -> int

(**************************************************************)

(* Optimized sending functions.  You first call sendto_info
 * with the socket to send on, and an array of destinations.
 * This returns a preprocessed data structure that can be
 * used later to actually do the sends with.  The sendto and
 * sendtov functions do not check for errors.
 *)
type sendto_info
val sendto_info : socket -> (inet * port) array -> sendto_info
val sendto : sendto_info -> buf -> ofs -> len -> unit

type send_info
val send_info : socket -> send_info
val sendp : send_info -> buf -> ofs -> len -> int

(**************************************************************)

type 'a refcnt = { mutable count : int ; obj : 'a } 
type 'a iovec = { rbuf : 'a ; ofs : ofs ; len : len }

val sendv : send_info -> string refcnt iovec array -> int
val sendtov : sendto_info -> string refcnt iovec array -> unit
val sendtosv : sendto_info -> string -> string refcnt iovec array -> unit
val sendtovs : sendto_info -> string refcnt iovec array -> string -> unit

(**************************************************************)

(* Called to set a function for logging information about
 * this module.
 *)
val set_error_log : ((unit -> string) -> unit) -> unit

(**************************************************************)

(* Options passed to setsockopt.
 *)
type socket_option =
  | Nonblock of bool
  | Reuse
  | Join of inet
  | Leave of inet
  | Multicast of bool
  | Sendbuf of int
  | Recvbuf of int
  | Bsdcompat of bool

(* Set one of the above options on a socket.
 *)
val setsockopt : socket -> socket_option -> unit

(**************************************************************)

(* Create a datagram (UDP) or a stream (TCP) socket.
 *)
val socket_dgram : unit -> socket
val socket_stream : unit -> socket

(**************************************************************)

(* Allocate or free a string outside of the ML heap.
 *)
val static_string : len -> string
val static_string_free : string -> unit

(* Check if portions of two strings are equal.
 *)
val substring_eq : string -> ofs -> string -> ofs -> len -> bool

(**************************************************************)

(* MD5 support.
 *)
type md5_ctx
val md5_init : unit -> md5_ctx
val md5_update : md5_ctx -> buf -> ofs -> len -> unit
val md5_final : md5_ctx -> Digest.t

(**************************************************************)
(* Create a socket connected to the standard input.
 * See ensemble/socket/stdin.c for an explanation of
 * why this is necessary.
 *)
val stdin : unit -> socket

(**************************************************************)

type recv_info
val recv_info : socket -> recv_info

(* Receive on a datagram socket.  Some errors cause a 0 to
 * be returned instead of generating an exception.  Also,
 * the size & offset values should be 4-byte aligned and the
 * return value is guaranteed to be aligned as well
 * (non-aligned packets will be dropped!).  
 *)
val udp_recv :  recv_info -> buf -> ofs -> len -> int

(**************************************************************)

type eth

type eth_sendto_info

val eth_supported : unit -> bool

val eth_init : string -> eth * socket

(* Similar to udp_recv above, but hacked for ethernet headers.
 *)
val eth_recv :  recv_info -> buf -> ofs -> len -> int

val eth_sendto_info :
    socket -> string(*interface*) -> int(*flags*) -> eth(*src*) -> eth array(*dests*) -> eth_sendto_info

val eth_sendtovs : eth_sendto_info -> string refcnt iovec array -> string -> unit

val eth_to_bin_string : eth -> string
val eth_of_bin_string : string -> eth

(**************************************************************)

val heap : unit -> Obj.t array
val addr_of_obj : Obj.t -> string
val minor_words : unit -> int
val frames : unit -> int array array

(**************************************************************)
(* Use these at your own risk.
 *)
val socket_of_file_descr : Unix.file_descr -> socket
val file_descr_of_socket : socket -> Unix.file_descr

(* Ohad.
 *)
val inet_of_unix_inet_addr : Unix.inet_addr -> inet
val unix_inet_addr_of_inet : inet -> Unix.inet_addr 


(* These simply returns the text readable value the
 * inet (XXX.YYY.ZZZ.TTT). Used for safe marshaling routines.
*)
val simple_string_of_inet  : inet -> string 
val simple_inet_of_string  : string -> inet 

(**************************************************************)
val install_error : (exn -> string) -> unit
(**************************************************************)
