(**************************************************************)
(* MARSH.MLI *)
(* Author: Mark Hayden, 12/96 *)
(**************************************************************)
open Trans
open Buf
(**************************************************************)

(* Type of marshalled objects: used at sender.
 *)
type marsh

(* Initialize a marshaller.
 *)
val marsh_init : Mbuf.t -> marsh

(* Convert a marshaller into a iovecl.
 *)
val marsh_done : marsh -> Iovecl.t

(* Functions for adding data to a string.
 *)
val write_int    : marsh -> int -> unit
val write_bool   : marsh -> bool -> unit
val write_string : marsh -> string -> unit
val write_buf    : marsh -> Buf.t -> unit
val write_list   : marsh -> ('a -> unit) -> 'a list -> unit
val write_array  : marsh -> ('a -> unit) -> 'a array -> unit
val write_option : marsh -> ('a -> unit) -> 'a option -> unit
val write_iovl   : marsh -> Iovecl.t -> unit
val write_iovl_len : marsh -> Iovecl.t -> unit

(**************************************************************)

(* Type of unmarshalling objects: used at receiver.
 *)
type unmarsh

(* This exception is raised if there is a problem
 * unmarshalling the message.  
 *)
exception Error of string

(* Convert a iovecl into an unmarsh object.
 *)
val unmarsh_init : Mbuf.t -> Iovecl.t -> unmarsh

(* Signal that we are done marshalling.
 *)
val unmarsh_done : unmarsh -> unit
val unmarsh_done_all : unmarsh -> unit	(* & we should have read it all *)

(* Functions for reading from marshalled objects.
 *)
val read_int    : unmarsh -> int
val read_bool   : unmarsh -> bool
val read_string : unmarsh -> string
val read_buf    : unmarsh -> Buf.t
val read_list   : unmarsh -> (unit -> 'a) -> 'a list
val read_option : unmarsh -> (unit -> 'a) -> 'a option
val read_iovl   : unmarsh -> len -> Iovecl.t
val read_iovl_len : unmarsh -> Iovecl.t

(**************************************************************)
