(**************************************************************)
(*
 *  Ensemble, (Version 1.00)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
(**************************************************************)
(* EMV.ML *)
(* Author: Mark Hayden, 12/96 *)
(**************************************************************)
open Mkutil
open Printf

let path = ref []
let files = ref []
let dest = ref None
let mlfile = ref false

let proc_file oc file =
(*
  let file =
    try find_path !path file with Not_found ->
      exit 0
  in
*)
  let modul = Filename.basename file in
  let modul = Filename.chop_extension modul in
  let modul = String.capitalize modul in

  if !mlfile then (
    fprintf oc "module %s = %s\n" modul modul
(*
    fprintf oc "module %s : sig\n" modul ;

    if not (Sys.file_exists file) then
      failwith "file does not exist" ;
    let ch = open_in file in
    let lines = read_lines ch in
    List.iter (fun line ->
      fprintf oc "    %s\n" line
    ) lines ;

    fprintf oc "end = struct\n" ;

    let file = (Filename.chop_extension file)^".ml" in
    if not (Sys.file_exists file) then
      failwith ("file does not exist:"^file) ;
    let ch = open_in file in
    let lines = read_lines ch in
    List.iter (fun line ->
      fprintf oc "    %s\n" line
    ) lines ;

    fprintf oc "end\n\n"
*)
  ) else (
    fprintf oc "module %s : sig\n" modul ;

    if not (Sys.file_exists file) then
      failwith "file does not exist" ;
    let ch = open_in file in
    let lines = read_lines ch in
    List.iter (fun line ->
      fprintf oc "  %s\n" line
    ) lines ;

    fprintf oc "end\n\n"
  )

let main () =
  Arg.parse [
    "-I",Arg.String(fun s -> path := s :: !path),": add dir to path" ;
    "-o",Arg.String(fun s -> dest := Some s),"" ;
    "-ml",Arg.Set mlfile,"" ;
    "-mli",Arg.Clear mlfile,""
  ] (fun file -> files := file :: !files) "" ;

  let dest = 
    match !dest with
    | None -> failwith "no destination file given"
    | Some dest -> dest
  in

  if Sys.file_exists dest then
    Sys.remove dest ;
  let oc = open_out_bin dest in
  List.iter (proc_file oc) (List.rev !files) ;
  flush oc ;
  close_out oc ;

  if platform = Unix then (
    let cmd = sprintf "chmod -w %s" dest in
    let _ = Sys.command cmd in
    ()
  )

let _ = main ()
