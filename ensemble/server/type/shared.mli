(**************************************************************)
(* SHARED *)
(* Author: Mark Hayden, 6/95 *)
(**************************************************************)

module Cipher : sig 
  type src = Buf.t
  type dst = Buf.t

  (* Encrypt/decrypt 
   *)
  val encrypt : Security.cipher (*key*) -> bool (*encrypt/decrypt*)-> src -> dst

  (* Encrypt and decrypt a Security.key
   *)
  val encrypt_key : Security.cipher -> Security.key -> Security.key
  val decrypt_key : Security.cipher -> Security.key -> Security.key

  (* [check_sanity name snt_loops perf_loops] Check that an algorithm 
   * actually works. Also measure its performance. 
   *)
  val sanity_check : string -> int -> int -> unit
end 

(**************************************************************)

module Prng : sig

  (* Create a fresh security key/mac/cipher. 
   *)
  val create_key : unit -> Security.key 
  val create_mac : unit -> Security.mac
  val create_cipher : unit -> Security.cipher
  val create_buf : Buf.len -> Buf.t

end    
  
(**************************************************************)
module DH : sig
  (* The type of a long integer (arbitrary length). It is implemented
   * efficiently * by the OpenSSL library.
   *)
  type pub_key
    
  (* A key contains four bignums: p,g,x,y. Where p is the modulo, g is
   * a generator for the group of integers modulo p, x is the private key, 
   * and y is the public key. y = p^x mod p.
   *)
  type key

  type param 

  (* print the parameters of a key.
   *)
  val show_params : param -> key -> unit
      
  (* get a key of a specific length from the standard file list.
   *)
  val fromFile : int -> param 

  val init : unit -> unit 
      
  (* generate p and g.
   *)
  val generate_parameters : int -> param
      
  val string_of_param : param -> string 

  val param_of_string : string -> param

  (* create new x and y, where the p and g already exist.
   *)
  val generate_key : param -> key
      
  val get_p : param -> string
      
  val get_g : param -> string
      
  val get_pub : key -> pub_key
      
  (* Convert a string into a DH key.
   *)
  val key_of_string : string -> key
      
      
  (* Convert a DH key into a key.
   *)
  val string_of_key : key -> string
      
  val string_of_pub_key : pub_key -> string
      
  val pub_key_of_string : string -> pub_key
      
  (* [compute_key Key(x) g^z] returns g^(zx) mod p 
   *)
  val compute_key : key -> pub_key -> string

  (* [generate_parameters_into_file t len] Generate new key parameters of size [len]
   * and write them into a file
   *)
  val generate_parameters_into_file : int -> unit

  (* [check_sanity name snt_loops perf_loops] Check that an algorithm 
   * actually works. Also measure its performance. 
   *)
  val sanity_check :  string -> int -> int -> unit

end
  
(**************************************************************)
  
  
