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
(* MKUTIL.ML *)
(**************************************************************)
open Printf
(**************************************************************)

let verbose = ref false
let plat = ref ""
let optflag = ref false
let sanity = "sanity"

(**************************************************************)

let hacker () =
  try Some(Sys.getenv "ECAMLCHACK")
  with Not_found -> None

(**************************************************************)

type platform =
  | Unix
  | Nt

let platform = match Sys.os_type with
  | "Unix" -> Unix
  | "Win32" -> Nt
  | _ -> failwith "ECAMLC:bad Sys.config"

(**************************************************************)

let obj_ext = match platform with Unix -> ".o" | Nt -> ".obj"
let lib_ext = match platform with Unix -> ".a" | Nt -> ".lib"
let asm_ext = match platform with Unix -> ".s" | Nt -> ".asm"

let oc_ext         = [|".cmi";".cmo";".cma";".cmx";".cmxa";".so";obj_ext;lib_ext;asm_ext|]
let oc_extnocmi    = [|       ".cmo";".cma";".cmx";".cmxa";".so";obj_ext;lib_ext;asm_ext|]
let oc_extnocmicmo = [|              ".cma";       ".cmxa";".so"        ;lib_ext        |]
let oc_extc () = if not !optflag then [|".cmi";".cmo";".cma"|] else oc_ext

let plat_ext ext = ext
(* Not needed anymore
let plat_ext ext =
  match ext with 
  | ".cmx" | ".o" | ".obj" | ".s" | ".cmxa" | ".a" | ".lib" -> 
      !plat^ext 
  | ".cmo" | ".cma" when platform = Nt ->
      !plat^ext
  | _ -> 
      ext 
*)

(**************************************************************)

let global_replace s a b =
  let la = String.length a in
  let lb = String.length b in
  let rec loop s i =
(*    printf "i=%5d, s=%s\n" i s ; flush stdout ;*)
    let ls = String.length s in
    if i + la >= ls then s 
    else if String.sub s i la = a then (
      let l = String.sub s 0 i in
      let r = String.sub s (i+la) (ls-i-la) in
      loop (l ^ b ^ r) (i+lb)
    ) else loop s (i+1)
  in loop s 0

(**************************************************************)
let suffixes = [".ml";".mli";".cmi";".cmo";".cma";".o";".obj";".a";".lib";".s";".cmx";".cmxa"]

let suffix f =
  let rec loop = function
    | [] -> None
    | hd::tl ->
	if Filename.check_suffix f hd then (Some hd)
	else loop tl
  in loop suffixes

(**************************************************************)

let strchr c s =
  let n = String.length s in
  let rec loop i =
    if i >= n then 
      raise Not_found
    else if s.[i] = c then
      i
    else loop (succ i)
  in loop 0

(**************************************************************)

let strstr c s =
  let n = String.length s in
  let rec loop i =
    if i >= n then 
      raise Not_found
    else if List.mem s.[i] c then
      i
    else loop (succ i)
  in loop 0

let chars_of_string s =
  let l = ref [] in
  for i = 0 to pred (String.length s) do
    l := s.[i] :: !l
  done ;
  !l

(**************************************************************)

let string_split c s =
  let c = chars_of_string c in
  let rec loop s =
    try
      let i = strstr c s in
      let hd = String.sub s 0 i in
      let tl = String.sub s (i+1) (String.length s - i - 1) in
      hd::(loop tl)
    with Not_found -> [s]
  in loop s

(**************************************************************)

let read_lines c =
  let lines = ref [] in
  try
    while true do
      let line = input_line c in
      lines := line :: !lines
    done ; []
  with End_of_file ->
    List.rev !lines

(**************************************************************)

let hex_of_string s =
  let n = String.length s in
  let h = String.create (2 * n) in
  for i = 0 to pred n do
    let c = s.[i] in
    let c = Char.code c in
    let c = sprintf "%02X" c in
    String.blit c 0 h (2 * i) 2
  done ;
  h

(**************************************************************)

let ident a = a

let string_of_list f l   = sprintf "[%s]" (String.concat "|" (List.map f l))

let string_of_pair fa fb = fun (a,b) -> sprintf "(%s,%s)" (fa a) (fb b)

let string_of_option sov = function
  | None -> "None"
  | Some v -> sprintf "Some(%s)" (sov v)

(**************************************************************)

let find_path dirs file =
  let rec loop = function
    | [] -> raise Not_found
    | dir::tl ->
	let path = Filename.concat dir file in
	if Sys.file_exists path then	(*BUG*)
	  path
	else loop tl
  in loop dirs

(**************************************************************)

let copy old_file new_file =
  let ic = open_in_bin old_file in
  let len = in_channel_length ic in
  let buf = String.create len in
  really_input ic buf 0 len ;
  close_in ic ;
  let oc = open_out_bin new_file in
  output oc buf 0 len ;
  close_out oc

(**************************************************************)

let touch file noaccess =
  let contents = 
    if noaccess then (
      if Sys.file_exists file then
	Sys.remove file ;
      ""
    ) else if Sys.file_exists file then (
      let ic = open_in_bin file in
      let len = in_channel_length ic in
      let buf = String.create len in
      really_input ic buf 0 len ;
      close_in ic ;
      Sys.remove file ;
      buf
    ) else ""
  in
    
  let oc = open_out_bin file in
  output oc contents 0 (String.length contents) ;
  close_out oc ;
  
  if noaccess && platform = Unix then (
    let cmd = sprintf "chmod 000 %s" file in
    let _ = Sys.command cmd in
    ()
  )

(**************************************************************)

let string_of_ch ch =
  let len = in_channel_length ch in
  let buf = String.create len in
  really_input ch buf 0 len ;
  buf

(**************************************************************)
(*
let srcdir = "/usr/u/hayden/ensemble"
let dstdir = "/amd/a/gulag/ensemble"
let dstlen = String.length dstdir
let srclen = String.length dstdir

let hayden file =
  try
    Sys.getenv "ECAMLCHACK" ; 
    eprintf "file=%s\n" file ; flush stderr ;
    let dir = Filename.dirname file in
    if String.length dir < String.length srcdir then
      raise Not_found ;
    if String.sub dir 0 srclen <> srcdir then
      raise Not_found ;
    let dst = dstdir ^ (String.sub file srclen (String.length file - srclen)) in
    eprintf "%s -> %s\n" file dst ;
    dst
  with Not_found -> file
*)
(**************************************************************)
