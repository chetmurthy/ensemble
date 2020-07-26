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
(* SHARED *)
(* Author: Mark Hayden, 6/95 *)
(**************************************************************)
open Buf
(**************************************************************)

module Cipher : sig 
  type src = Buf.t
  type dst = Buf.t

  type context =
    | Encrypt of Buf.t
    | Decrypt of Buf.t

  (* The type of a shared key manager.
   *)
  type t

  (* Lookup an encryption mechanism.
   *)
  val lookup : string (* NAME *) -> t

  (* What is the name of this mechanism
   *)
  val namea : t -> string 

  (* Create a new context from the key.
   *)
  val init : t -> Security.key -> bool -> context

  (* Encrypt/decrypt 
   *)
  val encrypt : t -> context -> Buf.t -> Buf.ofs -> Buf.len -> Buf.t 

  (* Encrypt/decrypt inplace 
   *)
  val encrypt_inplace : t -> context -> Buf.t -> Buf.ofs -> Buf.len -> unit
(*
  val final : t -> context -> unit
*)

  val single_use : t -> Security.key -> bool -> Buf.t -> Buf.t

  (* Install a new encryption mechanism.
   *)
  val install : 
    string ->  (* NAME *)
    (Security.key -> bool -> context) ->	(* init *)
    (context -> Buf.t -> ofs -> len -> Buf.t) -> (* encrypt *)
    (context -> Buf.t -> ofs -> len -> unit) -> (* encrypt_inplace *)
    unit
end 

(**************************************************************)

module Sign : sig
  (* The type of a shared signature manager.
   *)
  type t

  type context = Buf.t
  type digest  = Buf.t

  (* Find the signature algorithm. 
   *)
  val lookup : string (* NAME *) -> t

  (* The name of the specified algorithm
   *)
  val namea : t -> string 

  (* Create a context from a key, the hack version takes a preallocated string.
   *)
  val init : t -> Buf.t -> context
  val init_hack : t -> context -> Buf.t -> unit

  (* Update the context with a substring
   *)
  val update : t -> context -> Buf.t -> ofs -> len -> unit

  (* Create a digest from a context, the hack version takes a preallocated 
   * context. 
   *)
  val final : t -> context -> digest
  val final_hack : t -> context -> Buf.t -> ofs -> unit

  (* Install a new signture mechanism.
   *)
  val install : 
    string -> 
    (Buf.t -> context) ->  (* init *)
    (context -> Buf.t -> unit) -> (* init_hack *)
    (context -> Buf.t -> ofs -> len -> unit) -> (* update *)
    (context -> digest) ->  (* final *)
    (context -> Buf.t -> ofs -> unit) -> (* final_hack *)
      unit

  (* Sign a portion of a buffer with a key. The hack version takes
   * a preallocated string.
   *)
  val sign : t -> Security.key -> Buf.t -> Buf.ofs -> Buf.len -> Buf.t
  val sign_hack : t -> Security.key -> Buf.t -> Buf.ofs -> Buf.len -> Buf.t -> 
    Buf.ofs -> unit
end	    
	    
(**************************************************************)

module Prng : sig
  type t
    
  type context
    
  val namea : t -> string 
  val init : t -> Buf.t -> context
  val rand : t -> context -> Buf.t
  val lookup : string (* NAME *)-> t
      
  val install : 
    string -> (* NAME *)
    (Buf.t -> context) -> (* init *)
    (context -> Buf.t) -> (* rand *)
      unit
	    
  (* Create a new pseudo-random key
   *)
  val create : unit -> Security.key 
      
end    
  
(**************************************************************)
