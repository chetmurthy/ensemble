(**************************************************************)
(* SHARED *)
(* Author: Mark Hayden, 6/95 *)
(* Modifed : Ohad Rodeh , 2/99 *)
(**************************************************************)
open Buf
open Util
open Security
(**************************************************************)
let name = Trace.file "SHARED"
let failwith s = Trace.make_failwith name s
let log = Trace.log name    
let log1 = Trace.log (name^"1")
(**************************************************************)
  
  
module Prng = struct
  let initialized = ref false
    
  (* Get a context to the PRNG. The PRNG is initialized if it 
   * this is the first call. 
   *)
  let check_init () = 
    match !initialized with 
      | false -> 
	  let time = Time.to_float (Time.gettimeofday ()) in
	  log (fun () -> sprintf "time=%f" time);
	  Cryptokit_int.Prng.init (string_of_float time);
	  initialized := true;
    
      | true -> ()
	  
  (* Create a fresh security key/mac/cipher/buf. 
  *)
  let create_key () = 
    check_init ();
    let buf = Cryptokit_int.Prng.rand (Buf.int_of_len (Security.key_len)) in
    Security.key_of_buf (Buf.of_string buf)
      
  let create_mac () = 
    check_init ();
    let buf = Cryptokit_int.Prng.rand (Buf.int_of_len (Security.mac_len)) in
    Security.mac_of_buf (Buf.of_string buf)
      
  let create_cipher () = 
    check_init ();
    let buf = Cryptokit_int.Prng.rand (Buf.int_of_len (Security.cipher_len)) in
    Security.cipher_of_buf (Buf.of_string buf)

  let create_buf len = 
    check_init ();
    Buf.of_string (Cryptokit_int.Prng.rand (Buf.int_of_len len))
end    
  
(**************************************************************)
  
module Cipher = struct
  type src = Buf.t
  type dst = Buf.t
	
  let encrypt cipher flag buf = 
    let key = Security.buf_of_cipher cipher in
    let key = Buf.string_of key in
    Buf.of_string (Cryptokit_int.Cipher.encrypt key flag (Buf.string_of buf))
      
  (* Encrypt and decrypt a Security.key
   *)
  let encrypt_key cipher = function
    | NoKey -> failwith "Cannot encrypt an empty key"
    | Common key -> 
	Common ({
	  mac = mac_of_buf (encrypt cipher true (buf_of_mac key.mac) ) ;
	  cipher = cipher_of_buf (encrypt cipher true (buf_of_cipher key.cipher) )
	}) 
  
  let decrypt_key cipher = function
    | NoKey -> failwith "Cannot decrypt an empty key"
    | Common enc_key -> 
	Security.Common ({
	  mac = mac_of_buf (encrypt cipher false (buf_of_mac enc_key.mac)) ;
	  cipher = cipher_of_buf (encrypt cipher false (buf_of_cipher enc_key.cipher)) 
	})
  

  (* Run an encryption algorithm through a sanity check.
   *)
  let sanity_check alg snt_loops perf_loops = 
    eprintf "Sanity\n";
    let key = Security.key_of_buf (Buf.of_string "01234567012345670123456701234567") in
    let buf = Buf.of_string "11111111222222223333333344444444" in
    let buf1 = encrypt (get_cipher key) true buf in
    let buf2 = encrypt (get_cipher key) false buf1 in
    printf "buf=%s\n"  (hex_of_string (Buf.string_of buf)); 
    printf "buf2=%s\n" (hex_of_string (Buf.string_of buf2));
    if buf2 <> buf then failwith "Check_failed";
    eprintf "OK.\n";

    (* Check sanity of the encryption algorithm. Create a 
     * random string of size [mlen], encrypt and decrypt it. 
     *)
    let mlen = len_of_int 40 in
    for i=0 to snt_loops do 
      let key = Security.key_of_buf (Buf.of_string "01234567012345670123456701234567") in
      let buf = Prng.create_buf mlen in
      let buf1 = encrypt (get_cipher key) true  buf in
      let buf2 = encrypt (get_cipher key) false buf1 in
      if buf <> buf2 then failwith "bad encryption"
    done;
    eprintf "OK.\n";
end
  
(**************************************************************)
  
module DH = struct

  (* The type of a long integer (arbitrary length). It is implemented
   * efficiently * by the OpenSSL library.
   *)
  type pub_key = Cryptokit_int.DH.pub_key
    
  (* A key contains four bignums: p,g,x,y. Where p is the modulo, g is
   * a generator for the group of integers modulo p, x is the private key, 
   * and y is the public key. y = p^x mod p.
   *)
  type key = Cryptokit_int.DH.key

  type param = Cryptokit_int.DH.param

  let init = Cryptokit_int.DH.init 
      
  let generate_parameters = Cryptokit_int.DH.generate_parameters
      
  let param_of_string =  Cryptokit_int.DH.param_of_string
      
  let string_of_param = Cryptokit_int.DH.string_of_param

  let generate_key = Cryptokit_int.DH.generate_key
      
  let get_p = Cryptokit_int.DH.get_p 
      
  let get_g = Cryptokit_int.DH.get_g 
      
  let get_pub = Cryptokit_int.DH.get_pub
      
  let key_of_string = Cryptokit_int.DH.key_of_string
      
  let string_of_key = Cryptokit_int.DH.string_of_key
      
  let string_of_pub_key = Cryptokit_int.DH.string_of_pub_key
      
  let pub_key_of_string = Cryptokit_int.DH.pub_key_of_string
      
  let compute_key = Cryptokit_int.DH.compute_key

  let show_params param key = 
    let p = get_p param
    and g = get_g param in
    eprintf "p=%s\n" (hex_of_string p);
    eprintf "g=%s\n" (hex_of_string g);
    let pub = get_pub key in
    let pub = string_of_pub_key pub in
    eprintf "pub=%s\n" (hex_of_string pub)
      
      
  let fromFile keysize = 
    log (fun () -> sprintf "fromFile, keysize=%d" keysize);
    let ensroot = 
      try Unix.getenv "ENS_ABSROOT" 
      with Not_found -> 
	eprintf "Must have the ENS_ABSROOT enviroment variable defined, so 
I can find the Diffie-Hellman keys.\n";
	failwith "ENSROOT undefined"
    in
    let fName = 
      if Hsys.is_unix then 
	sprintf "%s/server/crypto/real/param%d" ensroot keysize 
      else
	sprintf "%s\\server\\crypto\\real\\param%d" ensroot keysize 
    in
    let fd = open_in fName in
    let len = in_channel_length fd in
    if len = 0 then 
      failwith "file is empty";
    log (fun () -> sprintf "parameter string length=%d" len);
    let s = String.create len in
    begin try
      really_input fd s 0 len
    with _ -> 
      failwith (sprintf "Error while extracting parameters from file %s" fName) 
    end;
    param_of_string (hex_to_string s)


  let generate_parameters_into_file len = 
    let param = generate_parameters len in
    let p = get_p param
    and g = get_g param in
    eprintf "p=%s\n" (hex_of_string p);
    eprintf "g=%s\n" (hex_of_string g);
    log1 (fun () -> sprintf "toFile, keysize=%d" len);
    let ensroot = Unix.getenv "ENS_ABSROOT" in
    let fName = 
      if Hsys.is_unix then 
	sprintf "%s/server/crypto/real/param%d" ensroot len 
      else
	sprintf "%s\\server\\crypto\\real\\param%d" ensroot len
    in
    log1 (fun () -> sprintf "ensroot=%s" ensroot);
    log1 (fun () -> sprintf "fName=%s" fName);
    let buf = string_of_param param in
    log1 (fun () -> sprintf "length(string_of_param)=%d" (String.length buf));
    let fd = open_out fName in
    output_string fd (hex_of_string (string_of_param param));
    close_out fd;
    ()
    
  (* Run Diffie-Hellman implementation through a sanity check.
   *)
  let sanity_check alg num key_len = 
    init ();

    let create_key len = 
      let param = fromFile len in
      log (fun () -> "generate_key");
      let key = generate_key param in
      show_params param key;
      flush stdout;
      key
    in
    let key = create_key key_len in
    

    eprintf "Coping keys\n"; 
    let control = Gc.get () in
(*    control.Gc.verbose <- 1;
    Gc.set control;*)
    for i=0 to num do 
      let key_s = string_of_key key in
      let key' = key_of_string key_s in
      ()
    done;
    
    eprintf "Checking PUB_KEYs\n";
    for i=0 to num do 
      let pub = get_pub key in
      ()
    done;
    
    eprintf "Checking string<->PUB_KEY \n";
    let pub = get_pub key in
    for i=0 to num do 
      let s = string_of_pub_key pub in
      let key = pub_key_of_string s in
      ()
    done;
(*    control.Gc.verbose <- 0;*)

    eprintf "Checking compute_key\n";
    let key_a = key 
    and key_b = create_key key_len in

    for i=0 to 50 do 
      eprintf ".";
      let pub_a = get_pub key_a
      and pub_b = get_pub key_b in
      let shared  = compute_key key_a pub_b
      and shared' = compute_key key_b pub_a in
      if shared <> shared' then 
	failwith "bad compute_key";
      let shared = pub_key_of_string shared in
      let shared = string_of_pub_key shared in
      if shared <> shared' then 
	failwith "bad string_of_pub_key & compute_key";
      ()
    done;

    let pub_a = get_pub key_a
    and pub_b = get_pub key_b in
    let shared  = compute_key key_a pub_b
    and shared' = compute_key key_b pub_a in
    eprintf "\nshared=%s\n" (hex_of_string shared);


    eprintf "Performance.\n";
    let time0 = Time.gettimeofday () in
    for i=1 to 50 do
      eprintf ".";
      let pub_a = get_pub key_a
      and pub_b = get_pub key_b in
      let shared  = compute_key key_a pub_b
      and shared' = compute_key key_b pub_a in
      ()
    done;
    let time1 = Time.gettimeofday () in
    let diff = Time.to_float (Time.sub time1 time0) in
    printf "\ntime for %d diffie-hellman exponentiations (key_len=%d)= %f(sec)\n" 
      100 key_len (diff/.(2.0 *. 50.0)) ;

    ()

end
(**************************************************************)
  
  
  
