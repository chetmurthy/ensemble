(**************************************************************)
(* CRYPTOKIT_INT *)
(* Author: Ohad Rodeh, 3/2004 *)
(**************************************************************)
(* Pseudo-random number generator *)
open Cryptokit
open Printf
  
(**************************************************************)
module Prng = struct

  let prng = ref None
    
  let init seed = 
    if String.length seed < 4 then 
      failwith "seed too short";
    prng := Some (Random.pseudo_rng (seed ^ seed ^ seed ^ seed))
      
  let rand len = 
    match !prng with 
      | None -> failwith "has not been initialized"
      | Some prng -> Random.string prng len 
      
end
  
(**************************************************************)

module Cipher = struct 
  type ofs = int
  type len = int
  type src = string
  type dst = string

  let key_len = 8

  let encrypt key flag buf = 
    let key = 
      if String.length key < key_len then 
	invalid_arg (sprintf "init:key length < %d" key_len)
      else if String.length key = 8 then 
	key 
      else 
	String.sub key 0 8
    in
    let transform = 
      if flag then 
	Cipher.des ~mode:Cipher.CBC key Cipher.Encrypt
      else
	Cipher.des ~mode:Cipher.CBC key Cipher.Decrypt
    in
    transform_string transform buf

end

(**************************************************************)

module DH = struct
  
  type state = {
    mutable prng : Random.rng option;
  }

  type key = {
    secret : DH.private_secret;
    pub : string ;
    param : DH.parameters
  }

  type pub_key = string

  type param = DH.parameters

  let s = {prng=None}

  (* Diffie-Hellman *)
  let init () = 
    let hex s = transform_string (Hexa.decode()) s in
    let prng =
      Random.pseudo_rng (hex "5b5e50dc5b6eaf5346eba8244e5666ac4dcd5409") in    
    s.prng <- Some prng
      
  let generate_parameters len = 
    let prng = match s.prng with
      | None -> (
	  init ();
	  match s.prng with 
	    | None -> failwith "sanity"
	    | Some prng -> prng
	)
      | Some prng -> prng
    in
    DH.new_parameters ~rng:prng len
	  
  let param_of_string buf = 
    (Marshal.from_string buf 0 : DH.parameters )

  let string_of_param param = 
    Marshal.to_string param []

  let generate_key param = 
    let secret = DH.private_secret param in
    let pub = DH.message param secret in 
    {
      secret = secret ;
      pub = pub ;
      param = param
    }
      
  let get_p param = param.DH.p

  let get_g param = param.DH.g

  let get_pub key = key.pub

  let key_of_string buf = 
    (Marshal.from_string buf 0 : key )

  let string_of_key key = 
    Marshal.to_string key []

  let string_of_pub_key pub_key = pub_key

  let pub_key_of_string pub_key = pub_key

  let compute_key key pub_key = 
    DH.shared_secret key.param key.secret pub_key 

end
  
(**************************************************************)
