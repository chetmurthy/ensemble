(**************************************************************)
(* ECP.ML *)
(* Author: Mark Hayden, 12/96 *)
(**************************************************************)
open Printf
open Mkutil

let dest = ref None
let nocmi = ref false
let nocmo = ref false
let mlext = ref false
let ro = ref false

let files = ref []

let copy srcfile =
  let dest =
    match !dest with
    | None -> failwith "no output specified"
    | Some dest -> dest
  in
  if !mlext then (
    let srcdir  = Filename.dirname srcfile in
    let srcbase = Filename.basename srcfile in
    let srcchop = srcbase in
    let oc_ext = match !nocmi, !nocmo with
    | false,false -> oc_ext
    | true, false -> oc_extnocmi
    | true, true  -> oc_extnocmicmo
    | _,_ -> failwith sanity
    in      
    
    Array.iter (fun ext ->
      let ext = plat_ext ext in
      let src = Filename.concat srcdir (srcchop ^ ext) in
      let dst = (dest ^ ext) in
      if Sys.file_exists src then (
	if !verbose then (
	  eprintf "ecp: %s -> %s\n" src dst ;
	  flush stderr
	) ;
	if Sys.file_exists dst then
	  Sys.remove dst ;
	copy src dst
      )
    ) oc_ext
  ) else (
    if not (Sys.file_exists srcfile) then
      failwith "source file doest not exist" ;
    if Sys.file_exists dest then
      Sys.remove dest ;
    copy srcfile dest ;
    if platform = Unix && !ro then (
      let cmd = sprintf "chmod 444 %s" dest in
      let _ = Sys.command cmd in
      ()
    )
  )

let main () =
  try
    Arg.parse [
      "-o",	       Arg.String(fun dir -> dest := Some dir),"";
      "-mlext",	       Arg.Set mlext, "" ;
      "-nocmi",        Arg.Set nocmi, "" ;
      "-nocmo",        Arg.Set nocmo, "" ;
      "-verbose",      Arg.Set verbose ,"";
      "-plat",         Arg.String(fun s -> plat := "-"^s),"";
      "-ro",           Arg.Set ro, ""
    ] (fun file -> files := file :: !files) "" ;

    List.iter copy !files
  with x -> raise x

let _ = 
  Printexc.catch main () ;
  exit 0
