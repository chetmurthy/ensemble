(**************************************************************)
(* DHA.ML *)
(* Interface to the Diffie-Hellman algorithm. ML side *)
(* Author: Ohad Rodeh, 4/2000 *)
(**************************************************************)
open Ensemble
open Shared
open DH
(**************************************************************)
let name = Trace.file "DHA"
let failwith s = failwith (name^":"^s)
let log = Trace.log name 
(**************************************************************)
external dhml_Init : unit -> unit 
  = "dhml_DH_Init"

external dhml_DH_generate_parameters : int -> key
  = "dhml_DH_generate_parameters" 


external dhml_DH_copy_params : key -> key
    = "dhml_DH_copy_params" 

external dhml_DH_generate_key : key -> unit
    = "dhml_DH_generate_key" 

external dhml_d2i_DHparams : string -> int -> key
    = "dhml_d2i_DHparams" 

external dhml_i2d_DHparams : key -> string
    = "dhml_i2d_DHparams"

external dhml_DH_size : key -> int 
    = "dhml_DH_size" 

external dhml_DH_get_p : key -> bignum
    = "dhml_DH_get_p" 

external dhml_DH_get_g : key -> bignum 
    = "dhml_DH_get_g" 

external dhml_DH_get_prv_key : key -> bignum
    = "dhml_DH_get_prv_key" 

external dhml_DH_get_pub_key : key -> bignum 
    = "dhml_DH_get_pub_key" 

external dhml_DH_compute_key : key -> bignum -> string -> unit 
    = "dhml_DH_compute_key" 

external dhml_BN_size : bignum -> int
    = "dhml_BN_size" 

external dhml_BN_bn2bin : bignum -> string -> unit
    = "dhml_BN_bn2bin" 

external dhml_BN_bin2bn : string -> bignum 
    = "dhml_BN_bin2bn" 


let string_of_bignum bignum = 
  log (fun () -> "string_of_bignum");
  let len = dhml_BN_size bignum in
  let s = String.create len in
  dhml_BN_bn2bin bignum s;
  s

let bignum_of_string = dhml_BN_bin2bn

let compute_key key bignum= 
  let blen = dhml_DH_size key in
  let s = String.create blen in
  dhml_DH_compute_key key bignum s;
  s

let key_of_string = dhml_d2i_DHparams 

let key_of_string s = dhml_d2i_DHparams s (String.length s)
let string_of_key = dhml_i2d_DHparams


(* Install in the Shared module.
 *
 * This supports separate compilation and linking for the crypto
 * libraries.
*)
let _ = 
  Shared.DH.install 
    "OpenSSL/DH" 
    dhml_Init 
    dhml_DH_generate_parameters 
    dhml_DH_copy_params 
    dhml_DH_generate_key 
    dhml_DH_get_p 
    dhml_DH_get_g 
    dhml_DH_get_pub_key 
    dhml_DH_get_prv_key 
    key_of_string 
    string_of_key    
    string_of_bignum 
    bignum_of_string 
    compute_key        
