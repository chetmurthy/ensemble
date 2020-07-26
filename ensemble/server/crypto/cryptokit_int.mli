(**************************************************************)
(*
 *  Ensemble, 2_00
 *  Copyright 2004 Cornell University, Hebrew University
 *           IBM Israel Science and Technology
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
(**************************************************************)
(* CRYPTOKIT_INT.MLI *)
(* Author: Ohad Rodeh, 4/2004 *)
(**************************************************************)
(* Pseudo-random number generator *)
open Cryptokit
open Printf
  
(**************************************************************)
module  Prng : sig
  val init : string -> unit
  val rand : int -> string
end
  
(**************************************************************)

module Cipher : sig
  val encrypt : 
    string  (*key*) -> 
    bool   (*encrypt/decrypt*) -> 
    string  (*buffer*) -> 
    string  (*result*)
end

(**************************************************************)

module DH : sig
  type key
  type pub_key
  type param

  (* Diffie-Hellman *)
  val init : unit -> unit
  val generate_parameters : int -> param
  val param_of_string : string -> param 
  val string_of_param : param -> string
  val generate_key : param -> key
  val get_p : param -> string
  val get_g : param -> string
  val get_pub : key -> pub_key
  val key_of_string : string -> key
  val string_of_key : key -> string
  val string_of_pub_key : pub_key -> string
  val pub_key_of_string : string -> pub_key
  val compute_key : key -> pub_key -> string

end
  
(**************************************************************)
