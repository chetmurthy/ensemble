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
(* ECAMLDEP.ML: modified from ocamldep.ml in Objective Caml *)
(* Author: Mark Hayden, 12/96 *)
(**************************************************************)
(* Note: this file is modified from the Objective Caml 
 * distribution.  Does the above copyright apply?
 *)

(***********************************************************************)
(*                                                                     *)
(*                           Objective Caml                            *)
(*                                                                     *)
(*            Xavier Leroy, projet Cristal, INRIA Rocquencourt         *)
(*                                                                     *)
(*  Copyright 1996 Institut National de Recherche en Informatique et   *)
(*  Automatique.  Distributed only by permission.                      *)
(*                                                                     *)
(***********************************************************************)


{
(* Remember the possibly free structure identifiers *)

module StringSet = 
  Set.Make(struct type t = string let compare = compare end)

let free_structure_names = ref StringSet.empty

let add_structure name =
  free_structure_names := StringSet.add name !free_structure_names

(* For nested comments *)

let comment_depth = ref 0

}

rule main = parse
    "open" [' ' '\010' '\013' '\009' '\012'] *
      { struct_name lexbuf; main lexbuf }
  | ['A'-'Z' '\192'-'\214' '\216'-'\222' ]
    (['A'-'Z' 'a'-'z' '_' '\192'-'\214' '\216'-'\246' '\248'-'\255'
      '\'' '0'-'9' ]) * '.'
      { let s = Lexing.lexeme lexbuf in
        add_structure(String.sub s 0 (String.length s - 1));
        main lexbuf }
  | "\""
      { string lexbuf; main lexbuf }
  | "(*"
      { comment_depth := 1; comment lexbuf; main lexbuf }
  | eof
      { () }
  | _
      { main lexbuf }

and struct_name = parse
    ['A'-'Z' '\192'-'\214' '\216'-'\222' ]
    (['A'-'Z' 'a'-'z' '_' '\192'-'\214' '\216'-'\246' '\248'-'\255'
      '\'' '0'-'9' ]) *
      { add_structure(Lexing.lexeme lexbuf) }
  | ""
      { () }

and comment = parse
    "(*"
      { comment_depth := succ !comment_depth; comment lexbuf }
  | "*)"
      { comment_depth := pred !comment_depth;
        if !comment_depth > 0 then comment lexbuf }
  | "\""
      { string lexbuf; comment lexbuf }
  | "''"
      { comment lexbuf }
  | "'" [^ '\\' '\''] "'"
      { comment lexbuf }
  | "'\\" ['\\' '\'' 'n' 't' 'b' 'r'] "'"
      { comment lexbuf }
  | "'\\" ['0'-'9'] ['0'-'9'] ['0'-'9'] "'"
      { comment lexbuf }
  | eof
      { () }
  | _
      { comment lexbuf }

and string = parse
    '"'
      { () }
  | '\\' ("\010" | "\013" | "\010\013") [' ' '\009'] *
      { string lexbuf }
  | '\\' ['\\' '"' 'n' 't' 'b' 'r']
      { string lexbuf }
  | '\\' ['0'-'9'] ['0'-'9'] ['0'-'9']
      { string lexbuf }
  | eof
      { () }
  | _
      { string lexbuf }

{
(* Print the dependencies *)

open Filename
open Queue
open Printf
open Misc

let memo = Hashtbl.create 10
let memo_path = ref []

(* Try memoizing find_in_path to improve performance.
 *)
let find_in_path path name =
  if path <> !memo_path then (
    memo_path := path ;
    Hashtbl.clear memo
  ) ;

  try
    match 
      let v = Hashtbl.find memo name in
(*    eprintf "HIT\n" ; flush stderr ;*)
      v
    with
    | None -> raise Empty		(* hack *)
    | Some name -> name
  with 
  | Empty -> raise Not_found
  | Not_found -> (
(*    eprintf "MISS\n" ; flush stderr ;*)
      try 
      	let full_name = find_in_path path name in
	Hashtbl.add memo name (Some full_name) ;
	full_name
      with Not_found -> (
	Hashtbl.add memo name None ;
	raise Not_found
      )      
    )

let loc = ref 0

let verbose_print name =
  let name = basename name in
  eprintf "%s " name ;
  loc := !loc + (String.length name) + 1 ;
  if !loc > 77 then (
    loc := 0 ;
    eprintf "\n   "
  ) ;
  flush stderr

let load_path = ref [""]
let opt_flag = ref true
let command = ref "ocamlc -c"
let dependdir = ref "$(OBJD)"
let destdir = ref "$(OBJD)"
let dependobj = ref ""

let find_dependency modname (byt_deps, opt_deps) =
  let name = Misc.lowercase modname in
  try
    let filename = find_in_path !load_path (name ^ ".mli") in
    let basename = Filename.chop_suffix filename ".mli" in
    ((basename ^ "$(CMI)") :: byt_deps,
     (if !opt_flag && Sys.file_exists (basename ^ ".ml")
      then basename ^ "$(CMO)"
      else basename ^ "$(CMI)") :: opt_deps)
  with Not_found ->
  try
    let filename = find_in_path !load_path (name ^ ".ml") in
    let basename = Filename.chop_suffix filename ".ml" in
    ((basename ^ "$(CMO)") :: byt_deps,
     (basename ^ "$(CMO)") :: opt_deps)
  with Not_found ->
    (byt_deps, opt_deps)

let print_dependencies target_file source_file deps =
  let targs = sprintf "%s : %s %s " 
    (Filename.concat !destdir (basename target_file)) source_file !dependobj in
  print_string targs ;
  let rec print_items pos = function
    [] -> print_string "\n"
  | dep :: rem ->
    let dep = Filename.concat !dependdir (basename dep) in
      if pos + String.length dep <= 77 then (
        print_string dep; print_string " ";
        print_items (pos + String.length dep + 1) rem
      ) else (
        print_string "\\\n    "; print_string dep; print_string " ";
        print_items (String.length dep + 5) rem
      ) in
  print_items (String.length targs + 2) deps ;
  printf "\t%s %s\n" !command source_file

let file_dependencies source_file =
  verbose_print source_file ;
  print_newline () ;
  try
    free_structure_names := StringSet.empty;
    let ic = open_in source_file in
    let lb = Lexing.from_channel ic in
    main lb;
    if Filename.check_suffix source_file ".ml" then (
      let root = Filename.chop_suffix source_file ".ml" in
      let init_deps =
        if Sys.file_exists (root ^ ".mli")
        then let cmi_name = root ^ "$(CMI)" in ([cmi_name], [cmi_name])
        else ([], []) in
      let (byt_deps, opt_deps) =
        StringSet.fold find_dependency !free_structure_names init_deps in
      if !opt_flag then
        print_dependencies (root ^ "$(CMO)") source_file opt_deps
      else
        print_dependencies (root ^ "$(CMO)") source_file byt_deps
    ) else if Filename.check_suffix source_file ".mli" then (
      let root = Filename.chop_suffix source_file ".mli" in
      let (byt_deps, opt_deps) =
        StringSet.fold find_dependency !free_structure_names ([], []) in
      if !opt_flag then
        print_dependencies (root ^ "$(CMI)") source_file opt_deps
      else
        print_dependencies (root ^ "$(CMI)") source_file byt_deps
    ) else if Filename.check_suffix source_file ".c" then (
      let root = Filename.chop_suffix source_file ".c" in
      let targ = Filename.concat !dependdir ((basename root) ^ "$(OBJ)") in
(*    printf "%s: %s\n" targ source_file ;*)
      printf "%s: %s ../socket/skt.h\n" targ source_file ;
      printf "\t$(CC) -o %s $(CFLAGS) -c %s\n" targ source_file
    ) else ();
    close_in ic
  with Sys_error msg -> ()

(* Entry point *)

let _ =
  printf "# Dependency file generated by ecamldep\n" ;
  eprintf "ecamldep: checking dependencies\n   " ;
  Arg.parse
    ["-I", Arg.String(fun dir -> load_path := dir :: !load_path),"";
     "-opt", Arg.Set opt_flag,"";
     "-noopt", Arg.Clear opt_flag,"";
     "-dep", Arg.String (fun s -> dependdir := s),"";
     "-dest", Arg.String (fun s -> destdir := s),"";
     "-depend", Arg.String (fun s -> dependobj := s),"";
     "-com", Arg.String (fun s -> command := s),""]
  file_dependencies "" ;
  eprintf "\n" ;
  exit 0
}
