(**************************************************************)
(*
 *  Ensemble, 1.10
 *  Copyright 2001 Cornell University, Hebrew University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
(**************************************************************)
(* SETUP.ML *)
(* Author: Mark Hayden, 12/96 *)
(**************************************************************)
open Printf
(**************************************************************)
let in_file = "ensemble.crypt"
let out_file = "ensemble.tar.gz"

let chars_of_string s =
  let l = ref [] in
  for i = 0 to pred (String.length s) do
    l := s.[i] :: !l
  done ;
  !l

let str_verb = ref false

let strip_prefix s c =
  let res =
    let rec loop i =
      if i >= String.length s then ""
      else if List.mem s.[i] c then loop (succ i)
      else String.sub s i ((String.length s) - i)
    in loop 0
  in
  res

let strtok s c =
  let c = chars_of_string c in
  let s = strip_prefix s c in
  let res =
    let rec loop i =
      if String.length s = 0 then 
      	raise Not_found
      else if i >= String.length s then
      	(s,"")
      else if List.mem s.[i] c then
	let tok = String.sub s 0 i in
	let s = String.sub s i ((String.length s) - i) in
	let s = strip_prefix s c in
	(tok,s)
      else loop (succ i)
    in loop 0
  in
  res

(**************************************************************)

let get_yn s =
  let rec loop () =
    printf "%s: " s ;
    let line = read_line () in
    if line = "" then loop () 
    else match line.[0] with
    | 'y' | 'Y' -> 
	true
    | 'n' | 'N' -> 
	false
    | _ -> 
	printf "  please answer yes or no\n" ;
	loop ()
  in loop ()

let handle f s =
  try Printexc.print f () with _ ->
    printf "setup:error:%s, exiting\n" s ;
    flush stdout ;
    exit 0

let reverse s =
  let len = String.length s in
  for i = 0 to len/2 do
    let j = len - i - 1 in
    let tmp = s.[i] in
    s.[i] <- s.[j] ;
    s.[j] <- tmp
  done

(**************************************************************)

let decrypt () =
  if Sys.file_exists out_file then (
    printf "setup:output file '%s' exists, not decrypting\n" out_file ;
    flush stdout
  ) else (
    let ch = handle
      (fun () -> open_in_bin in_file)
      (sprintf "opening setup file '%s'" in_file)
    in

    let len = in_channel_length ch in
    let buf = String.create len in

    let () = handle
      (fun () -> really_input ch buf 0 (String.length buf))
      (sprintf "reading setup file")
    in

    close_in ch ;

    reverse buf ;

    let ch = handle
      (fun () -> open_out_bin out_file)
      (sprintf "opening output file '%s'" out_file)
    in

    let () = handle
      (fun () -> output ch buf 0 (String.length buf))
      (sprintf "writing output file '%s'" out_file)
    in

    close_out ch ;
    Sys.remove in_file
  )

(**************************************************************)

let encrypt () =
  let ch = open_in_bin out_file in
  let len = in_channel_length ch in
  let buf = String.create len in
  really_input ch buf 0 (String.length buf) ;
  close_in ch ;
  reverse buf ;
  let ch = open_out_bin in_file in
  output ch buf 0 (String.length buf) ;
  close_out ch

(**************************************************************)

let run () =
   Arg.parse [] (function
     | "accepted" -> 
	 decrypt () ; 
	 exit 0
     | "encrypt" ->
      	 encrypt () ;
	 exit 0
     | _ ->
    	 printf "setup:bad argument, exiting\n" ;
	 exit 0 
  ) "setup:read Ensemble licensing agreement and setup Ensemble distribution" ;

  printf "\n" ;
  printf "Installing this software requires you to agree to the\n" ;
  printf "Ensemble license.  If you wish to print the license,\n" ;
  printf "it's in doc/license.txt.  You may also sign the license and\n" ;
  printf "fax it to +1 (607) 255-4428.  We will then sign it as\n" ;
  printf "well and send a copy back to you for your records.\n" ;
  printf "\n" ;

  if get_yn "Would you like to see this license now? " then (
    let rec loop s = 
      try
	let (s,l) = strtok s "\n" in
	s :: loop l
      with Not_found -> []
    in

    let license = loop license in

    let present l =
      List.iter (fun s -> printf "%s\n" s) l ;
      printf "<<hit return>>" ;
      read_line () ;
      ()
    in

    let rec loop l =
      match l with
      | [] -> ()
      | a::b::c::d::e::tl ->
	  present [a;b;c;d;e] ;
	  loop tl
      | _ -> 
	  present l
    in 

    loop license
  ) ;
  
  if not (get_yn "Do you agree with the terms of this license? ") then (
    printf "In that case so long and thanks for all the fish.\n" ;
    exit 0
  ) ;

  if not (get_yn "Have you previously submitted your information to us?") then (
    let oc = open_out "ensemble-mail"  in
    fprintf oc "[Email this to ensemble@cs.cornell.edu]\n" ;
    fprintf oc "Name: \n" ;
    fprintf oc "Organization: \n" ;
    fprintf oc "Phone: \n" ;
    fprintf oc "Fax: \n" ;
    fprintf oc "Address: \n" ;
    fprintf oc ": \n" ;
    fprintf oc ": \n" ;
    fprintf oc ": \n" ;
    close_out oc ;
    
    printf "I have created a file, ensemble-mail.\n" ;
    printf "Please fill in your information\n" ;
    printf "and email it to ensemble@cs.cornell.edu\n" ;
    printf "<hit return to continue>" ; 
    read_line () ; ()
  ) ;
  
  printf "Ok.  I'm decrypting the distribution.\n" ;
  flush stdout ;
  decrypt () ;
  printf "Done.  Now, continue with step (2) in ensemble/INSTALL\n" ;
  exit 0

let _ = run ()

(**************************************************************)
