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
(* SECURITY *)
(* Authors: Mark Hayden, 6/95 *)
(**************************************************************)
open Trans
open Buf
(**************************************************************)

(* Type of keys in Ensemble.
 *)
type key = 
  | NoKey
  | Common of Buf.t

(* Create a new random key.  This is not cryptographically
 * secure.  
 *)
(*
val create : unit -> key
*)

(* Get the string contents of a key.
 *)
val str_of_key : key -> string
val buf_of_key : key -> Buf.t

(* Get a textual representation of the key for printing out
 * to the user.  
 *)
val string_of_key_short : key -> string
val string_of_key : key -> string
