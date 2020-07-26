(**************************************************************)
(* ETOUCH.ML *)
(* Author: Mark Hayden, 12/96 *)
(**************************************************************)
open Printf

let files = ref []
let noaccess = ref false

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
  
  if noaccess && Sys.os_type = "Unix" then (
    let cmd = sprintf "chmod 000 %s" file in
    let _ = Sys.command cmd in
    ()
  )

let main () =
  try
    Arg.parse [
      "-noaccess", Arg.Set noaccess, ""
    ] (fun file -> files := file :: !files) "" ;
    List.iter (fun f -> touch f !noaccess) !files
  with x -> raise x

let _ = 
  Printexc.catch main () ;
  exit 0
