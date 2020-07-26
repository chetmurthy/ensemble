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
(* EMV.ML *)
(* Author: Mark Hayden, 12/96 *)
(**************************************************************)
open Printf
open Mkutil

let dest = ref None
let nocmi = ref false
let mlext = ref false

let files = ref []

let install srcfile =
  let srcdir  = Filename.dirname srcfile in
  let srcbase = Filename.basename srcfile in
  let srcchop = srcbase in
  let oc_ext =
    if !nocmi then oc_extnocmi else oc_ext 
  in

  match !dest with
  | None -> failwith "no destination directory"
  | Some dest ->
      Array.iter (fun ext ->
      	let ext = plat_ext ext in
        let src = Filename.concat srcdir (srcchop ^ ext) in
      	let dst = (dest ^ ext) in
	if Sys.file_exists src then (
	  if !verbose then (
	    eprintf "hinstall: mv %s %s\n" src dst ;
	    flush stderr
	  ) ;
	  if Sys.file_exists dst then
	    Sys.remove dst ;
	  Sys.rename src dst
        )
      ) oc_ext

let main () =
  try
    Arg.parse [
    "-o", 		Arg.String(fun dir -> dest := Some dir),"" ;
    "-mlext",        Arg.Set mlext, "" ;
    "-nocmi",        Arg.Set nocmi, "" ;
    "-verbose",      Arg.Set verbose ,"";
    "-plat",         Arg.String(fun s -> plat := "-"^s),""
    ] (fun file -> files := file :: !files) "" ;
    List.iter install !files
  with x -> raise x

let _ = 
  Printexc.catch main () ;
  exit 0
