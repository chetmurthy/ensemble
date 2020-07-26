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
(* ADDR.MLI *)
(* Author: Mark Hayden, 12/95 *)
(**************************************************************)
open Trans

(* Address ids.
 *)
type id =
  | Atm
  | Deering
  | Netsim
  | Tcp
  | Udp
  | Sp2
  | Krb5
  | Pgp
  | Fortezza
  | Mpi
  | Eth

(* Addresses.
 *)
type t =
  | AtmA of inet
  | DeeringA of inet * port
  | NetsimA
  | TcpA of inet * port
  | UdpA of inet * port
  | Sp2A of inet * port
  | Krb5A of string
  | PgpA of string
  | FortezzaA of string
  | MpiA of rank
  | EthA of eth * pid

(* Processes actually use collections of addresses.
 *)
type set

(* Display functions.
 *)
val string_of_id : id -> string
val string_of_id_short : id -> string	(* just first char *)
val string_of_addr : t -> string
val string_of_set : set -> string

(* Conversion functions.
 *)
val set_of_arrayf : t Arrayf.t -> set
val arrayf_of_set : set -> t Arrayf.t
val id_of_addr : t -> id
val id_of_string : string -> id
val ids_of_set : set -> id Arrayf.t
val project : set -> id -> t

(* Info about ids.
 *)
val has_mcast : id -> bool
val has_pt2pt : id -> bool
val has_auth : id -> bool

(* Sets of addresses are on the same process if any of the 
 * addresses are the same.  (Is this correct?)
 *)
val same_process : set -> set -> bool

(* Remove duplicated destinations.  [compress my_addr
 * addresses] returns tuple with whether any elements of the
 * view were on the same process and a list of addresses with
 * distinct processes.  
 *)
val compress : set -> set Arrayf.t -> bool * set Arrayf.t

(* Default ranking of modes.  Higher is better.
 *)
val default_ranking : id -> int

(* Choose "best" mode to use.
 *)
val prefer : (id -> int) -> id Arrayf.t -> id

(* Explain problem with these modes.
 *)
val error : id Arrayf.t -> unit

val modes_of_view : set Arrayf.t -> id Arrayf.t
