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
(* Modifed : Ohad Rodeh , 2/99 *)
(**************************************************************)
let name = Trace.file "SHARED"
let failwith = Trace.make_failwith name
let log = Trace.log name
(**************************************************************)
open Buf
(**************************************************************)

module Cipher = struct

type src = Buf.t
type dst = Buf.t

type context =
  | Encrypt of Buf.t
  | Decrypt of Buf.t

type t = {
  name : string ;
  init : Security.key -> bool -> context ;
  encrypt : context -> Buf.t -> ofs -> len -> Buf.t ;
  encrypt_inplace : context -> Buf.t -> ofs -> len -> unit 
} 

let namea t = t.name
let init t = t.init
let encrypt t = t.encrypt
let encrypt_inplace t = t.encrypt_inplace

let single_use t key enc src =
  let ctx = init t key enc in
(*
  let dst = Buf.create (Buf.length src) in
  encrypt t ctx src len0 dst len0 (Buf.length src) ;
  dst
*)
  encrypt t ctx src len0 (Buf.length src)
    
let table = ref []

let install name init encrypt encrypt_inplace = 
  let t = {
    name = name ;
    init = init ;
    encrypt = encrypt ; 
    encrypt_inplace = encrypt_inplace
  } in
  table := (name,t) :: !table

let lookup name =
  let rec loop = function
    | [] -> raise (Failure ("Could not find encryption algorithm " ^ name))
    | (name_enc,t)::tl ->
	if name=name_enc then t else loop tl
  in loop !table  
end

(**************************************************************)


module Sign  = struct

type src = Buf.t
type dst = Buf.t

type context = Buf.t
type digest  = Buf.t

type t = {
  name : string ; 
  init : Buf.t -> context ;
  init_hack : context -> Buf.t -> unit ;
  update : context -> Buf.t -> ofs -> len -> unit ;
  final : context -> digest ;
  final_hack : context -> Buf.t -> ofs -> unit
}
	   
let namea t = t.name
let init t = t.init
let init_hack t = t.init_hack 
let update t = t.update 
let final t = t.final
let final_hack  t = t.final_hack

let table = ref []

let install name init init_hack update final final_hack = 
  let t = {
    name = name ;
    init = init ;
    init_hack = init_hack ; 
    update = update ;  
    final = final ; 
    final_hack = final_hack
  } in
  table := (name,t) :: !table

let lookup name =
  let rec loop = function
    | [] -> raise (Failure ("Could not find signature algorithm <" ^ name ^ ">"))
    | (sign_name,t)::tl ->
	if name = sign_name then t else loop tl
  in loop !table  


let sign alg key buf ofs len =
  let key = Security.buf_of_key key in
  let ctx = init alg key in 
  update alg ctx buf ofs len ;
  let sign = final alg ctx in
  sign

let sign_hack alg key buf ofs len dst ofs = 
  let key = Security.buf_of_key key in
  let ctx = init alg key in
  update alg ctx buf ofs len ;
  final_hack alg ctx dst ofs
end


(**************************************************************)

module Prng = struct

  type context = string
      
  type t = {
    name : string ;
    init : Buf.t -> context ;
    rand : context -> Buf.t
  }
      
  let namea t = t.name
  let init t = t.init
  let rand t = t.rand
    
  let table = ref []
    
  let install name init rand = 
    let t = {
      name = name ;
      init = init ;
      rand = rand
    } in
    table := (name,t) :: !table
      
  let lookup name =
    let rec loop = function
      | [] -> raise (Failure "no appropriate Pseudo Random Generator available")
      | (prng_name,t)::tl ->
	  if name = prng_name then t else loop tl
    in loop !table  
	 
(* This function creates strings of size 16, this should be
 * fixed.  It initializes the random number generator, if
 * this has not been done so far.  It then uses a sequence
 * of pseudo-random numbers to create random strings.  Each
 * call to PRNG creates an integer, that is converted into 3
 * random bytes.  
 *)
  let ctx = ref None 
  let key_len = 16
    
  let create () =
    let t = lookup "ISAAC" in
    let init = init t
    and rand = rand t in
    
  (* Initialize the PRNG if this is the first time.
   *)
    begin match !ctx with 
      | None -> 
	  let frac_of_time () = 
	    let t = Time.to_float (Time.gettimeofday ()) in
	    let t = t *. 1000000.0 in
	    let sec = float (Pervasives.truncate t) in
	    Pervasives.truncate (1000000.0 *. (t -. sec))
	  in
	  ctx := Some (init (Buf.pad_string (string_of_int (frac_of_time ())))) ;
      | Some _ -> ()
    end;
    
    let ctx = Util.some_of name !ctx in
    
    let create_random_string len = 
      let rec loop s togo = 
	if Buf.length s >=|| len then s
	else 
	  let r = rand ctx in
	  loop (Buf.append s r) (togo -|| Buf.length r) 
      in
      let s = loop (Buf.empty()) len in
      Buf.sub name s len0 len 
    in
    
    let key = create_random_string (ceil key_len) in
    Security.Common key
      
end    
  
(**************************************************************)
  
  
