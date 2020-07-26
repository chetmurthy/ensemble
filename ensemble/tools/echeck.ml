(**************************************************************)
(*
 *  Ensemble, 1.10
 *  Copyright 2001 Cornell University, Hebrew University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
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
open Printf
open Format
open Mkutil

module Junk = struct
  let exec_magic_number = "Caml1999X006"
  and cmi_magic_number = "Caml1999I006"
  and cmo_magic_number = "Caml1999O004"
  and cma_magic_number = "Caml1999A005"
  and cmx_magic_number = "Caml1999Y006"
  and cmxa_magic_number = "Caml1999Z007"
  and ast_impl_magic_number = "Caml1999M008"
  and ast_intf_magic_number = "Caml1999N007"
  
  type signature
  type module_components
 

  type pers_struct =
    { ps_name: string;
      ps_sig: signature;
      ps_comps: module_components;
      ps_crcs: (string * Digest.t) list }

  type reloc_info

  type compilation_unit =
    { cu_name: string;                    (* Name of compilation unit *)
      mutable cu_pos: int;                (* Absolute position in file *)
      cu_codesize: int;                   (* Size of code block *)
      cu_reloc: (reloc_info * int) list;  (* Relocation information *)
      cu_imports: (string * Digest.t) list; (* Names and CRC of intfs imported *)
      cu_primitives: string list;         (* Primitives declared inside *)
      mutable cu_force_link: bool;        (* Must be linked even if unref'ed *)
      mutable cu_debug: int;              (* Position of debugging info, or 0 *)
      cu_debugsize: int }                 (* Length of debugging info *)

  type function_description

  type value_approximation =
      Value_closure of function_description * value_approximation
    | Value_tuple of value_approximation array
    | Value_unknown
    | Value_integer of int

  type unit_infos =
    { mutable ui_name: string;                    (* Name of unit implemented *)
      mutable ui_imports_cmi: (string * Digest.t) list; (* Interfaces imported *)
      mutable ui_imports_cmx: (string * Digest.t) list; (* Infos imported *)
      mutable ui_approx: value_approximation;     (* Approx of the structure *)
      mutable ui_curry_fun: int list;             (* Currying functions needed *)
      mutable ui_apply_fun: int list;             (* Apply functions needed *)
      mutable ui_force_link: bool }               (* Always linked *)

end
open Junk

type name = string 

type kinds =
  | Cmi
  | Cmo
  | Cma
  | Cmx
  | Cmxa

type descriptor = {
  name : string ;
  kind : kinds ;
  export_int : Digest.t ;
  export_imp : Digest.t option ;
   
  import_int : (name * Digest.t) list ;
  import_imp : (name * Digest.t) list
}   

let string_of_kinds = function
  | Cmi -> "Cmi"
  | Cmo -> "Cmo"
  | Cma -> "Cma"
  | Cmx -> "Cmx"
  | Cmxa -> "Cmxa"

let string_of_desc d =
  sprintf "{name=%s;kind=%s;exint=%s;eximp=%s;imint=%s;imimp=%s}"
    d.name
    (string_of_kinds d.kind)
    (hex_of_string d.export_int)
    (string_of_option hex_of_string d.export_imp)
    (string_of_list (string_of_pair ident hex_of_string) d.import_int)
    (string_of_list (string_of_pair ident hex_of_string) d.import_imp)

(* Dump a compilation unit description *)


let print_digest d =
  for i = 0 to String.length d - 1 do
    print_string(Printf.sprintf "%02x" (Char.code d.[i]))
  done

let print_info cu =
  print_string "  Unit name: "; print_string cu.cu_name; print_newline();
  print_string "  Digest of interface implemented: ";
(*  print_digest cu.cu_interface; print_newline();*)
  print_string "  Interfaces imported:"; print_newline();
  List.iter
    (fun (name, digest) ->
      print_string "\t"; print_digest digest; print_string "\t";
      print_string name; print_newline())
    cu.cu_imports;
  print_string "  Uses unsafe features: ";
  begin match cu.cu_primitives with
    [] -> print_string "no"; print_newline()
  | l  -> print_string "YES"; print_newline();
          print_string "  Primitives declared in this module:";
          print_newline();
          List.iter
            (fun name -> print_string "\t"; print_string name; print_newline())
            l
  end

(*
let print_name_crc (name, crc) =
  print_space(); print_string name;
  print_string " ("; print_digest crc; print_string ")"
*)
(*
let print_infos (ui, crc) =
  print_string "Name: "; print_string ui.ui_name; print_newline();
  print_string "CRC of implementation: "; print_digest crc; print_newline();
(*  print_string "CRC of interface: "; print_digest ui.ui_interface; print_newline();*)
  open_vbox 2;
  print_string "Interfaces imported:";
  List.iter print_name_crc ui.ui_imports_cmi;
  close_box(); print_newline();
  open_vbox 2;
  print_string "Implementations imported:";
  List.iter print_name_crc ui.ui_imports_cmx;
  close_box(); print_newline()
(*
  open_vbox 2;
  print_string "Approximation:"; print_space(); print_approx ui.ui_approx;
  close_box(); print_newline();
  open_box 2;
  print_string "Currying functions:";
  List.iter
    (fun arity -> print_space(); print_int arity)
    ui.ui_curry_fun;
  close_box(); print_newline();
  open_box 2;
  print_string "Apply functions:";
  List.iter
    (fun arity -> print_space(); print_int arity)
    ui.ui_apply_fun;
  close_box(); print_newline()
*)

let print_unit_info filename =
  let ic = open_in_bin filename in
  try
    let buffer = String.create (String.length cmx_magic_number) in
    really_input ic buffer 0 (String.length cmx_magic_number);
    if buffer = cmx_magic_number then (
      let ui = (input_value ic : unit_infos) in
      let crc = Digest.input ic in
      close_in ic;
      print_infos (ui, crc)
    ) else if buffer = cmxa_magic_number then (
      let info_crc_list = (input_value ic : (unit_infos * Digest.t) list) in
      close_in ic;
      List.iter print_infos info_crc_list
    ) else if buffer = cmo_magic_number then (
      let cu_pos = input_binary_int ic in
      seek_in ic cu_pos;
      let cu = (input_value ic : compilation_unit) in
      close_in ic;
      print_info cu
    ) else if buffer = cma_magic_number then (
      let toc_pos = input_binary_int ic in
      seek_in ic toc_pos;
      let toc = (input_value ic : compilation_unit list) in
      close_in ic;
      List.iter print_info toc
    ) else if buffer = cmi_magic_number then (
      let (name, sign, comps) = input_value ic in
      let crcs = input_value ic in
      close_in ic;
      let ps = { ps_name = name;
		 ps_sig = sign;
		 ps_comps = comps;
		 ps_crcs = crcs } in
      let _,crc = List.hd crcs in
(*
      if ps.ps_name <> modname then
      	raise(Error(Illegal_renaming(ps.ps_name, filename)));
*)
      print_string "Name: "; print_string ps.ps_name; print_newline();
      print_string "CRC of interface: "; print_digest crc; print_newline();
    ) else (
      close_in ic;
      prerr_string buffer ;
      prerr_endline "Wrong magic number [0]";
      exit 2
    )
  with End_of_file | Failure _ ->
    close_in ic;
    prerr_endline "Error reading file";
    exit 2
*)

let descriptor filename =
  (*log2 "descriptor" filename ;*)
  if not (Sys.file_exists filename) then (
    None
  ) else (
    let ic = open_in_bin filename in
    try
      let buffer = String.create (String.length cmx_magic_number) in
      really_input ic buffer 0 (String.length cmx_magic_number);
      if buffer = cmx_magic_number then (
	let ui = (input_value ic : unit_infos) in
	let crc = Digest.input ic in
	
	(* Assumes own interface is imported.
	 *)
	let int_crc = List.assoc ui.ui_name ui.ui_imports_cmi in
	close_in ic;
  (*
	print_infos (ui, crc) ;
  *)
	Some { name = ui.ui_name ;
	       kind = Cmx;
	  export_int = int_crc ;
	  export_imp = Some crc ;
	  import_int = ui.ui_imports_cmi ;
	  import_imp = ui.ui_imports_cmx
	}	
      ) else if buffer = cmxa_magic_number then (
	let info_crc_list = (input_value ic : (unit_infos * Digest.t) list) in
	close_in ic;
  (*
	List.iter print_infos info_crc_list ;
  *)
	None
      ) else if buffer = cmo_magic_number then (
	let cu_pos = input_binary_int ic in
	seek_in ic cu_pos;
	let cu = (input_value ic : compilation_unit) in
	close_in ic;
  (*
	print_info cu ;
  *)

	let export_int = List.assoc cu.cu_name cu.cu_imports in
	Some { name = cu.cu_name ;
	       kind = Cmo;
	  export_int = export_int ;
	  export_imp = None ;
	  import_int = cu.cu_imports ;
	  import_imp = []
	}	
      ) else if buffer = cma_magic_number then (
	let toc_pos = input_binary_int ic in
	seek_in ic toc_pos;
	let toc = (input_value ic : compilation_unit list) in
	close_in ic;
  (*
	List.iter print_info toc ;
  *)
	None
      ) else if buffer = cmi_magic_number then (
	let (name, sign, comps) = input_value ic in
	let crcs = input_value ic in
	close_in ic;
(*
	let ps = { ps_name = name;
		   ps_sig = sign;
		   ps_comps = comps;
		   ps_crcs = crcs } in
*)
	let (_,crc) = List.hd crcs in
  (*
	if ps.ps_name <> modname then
	  raise(Error(Illegal_renaming(ps.ps_name, filename)));
  *)
(*
	print_string "Name: "; print_string ps.ps_name; print_newline();
	print_string "CRC of interface: "; print_digest crc; print_newline();
*)
	Some { name = name ;
	       kind = Cmi;
	  export_int = crc ;
	  export_imp = None ;
	  import_int = List.tl crcs ;
	  import_imp = []
	}	
      ) else (
	close_in ic;
	prerr_string "Wrong magic number crc='";
	prerr_string buffer ;
	prerr_string "' filename='";
	prerr_string filename ;
	prerr_endline "'";
	exit 2
      )
    with End_of_file | Failure _ ->
      close_in ic;
      prerr_endline (sprintf "Error reading file '%s'" filename) ;
      exit 2
  )

(*
let cache = ref None

let get_cache cache =
  let cache =
    match cache with
    | None -> (
  	try
	  let ch = open_in_bin cache in
	  input_value ch
  	with _ ->
	  Hashtbl.create 10
      )
    | Some cache -> cache
  in 
  cache

let descriptor cache filename =
  let cache = get_cache cache in
*)

exception Mismatch

let zeros = String.make (String.length (Digest.string "")) (Char.chr 0)

let diff a b =
  a <> b && a <> zeros

let log s =
  if !verbose then
    eprintf "echeck:%s\n" s

let log2 s t =
  log (sprintf "%s:%s" s t)

let check file path stdlib =
  match descriptor file with
  | None -> 
      log2 "no descriptor for dest file" file ;
      false
  | Some d ->
      let descriptor file = 
	try 
	  let file = find_path (stdlib::path) file in
	  descriptor file
	with Not_found ->
	  log2 "dependency file missing" file ;
	  None
      in

      try
(*
	if d.kind = Cmi then (
	  log "destination file is .cmi" ;
	  raise Mismatch 
	) ;
*)
	
	if d.kind = Cmx || d.kind = Cmo then (
	  let int = (String.lowercase d.name)^".cmi" in
	  match descriptor int with
	  | None -> 
	      log2 "missing interface" d.name ;
	      raise Mismatch
	  | Some int ->
	      if d.export_int <> int.export_int then (
		log2 "imp" (string_of_desc d) ;
		log2 "int" (string_of_desc int) ;
		log2 "mismatched interface" d.name ;
		raise Mismatch
	      )
        ) ;

	List.iter (fun (name,dig) ->
	  let int = (String.lowercase name)^".cmi" in
	  match descriptor int with
	  | None -> 
	      log2 "missing interface[2]" name ;
	      raise Mismatch
	  | Some int ->
	      if dig <> int.export_int then (
		log2 "mismatched interface[2]" name ;
(*
		log2 (hex_of_string dig) (hex_of_string int.export_int) ;
 *)
		raise Mismatch
	      )
	) d.import_int ;

	if d.kind = Cmx then (
	  List.iter (fun (name,dig) ->
	    if dig <> zeros then (
	      let ext = match d.kind with
	      | Cmo -> ".cmo"
	      | Cmx -> ".cmx"
	      | _ -> ""
	      in

	      let imp = (String.lowercase name)^ext in
	      match descriptor imp with
	      | None ->
		  log2 "missing implementation" name ;
		  raise Mismatch
	      | Some imp ->
		  match imp.export_imp with
		  | None -> 
		      log2 "missing implementation signature" name ;
		      raise Mismatch
		  | Some imp ->
		      if dig <> imp then (
			log2 "mismatched implementation" name ;
			raise Mismatch
		      )
	    )
	  ) d.import_imp
	) ;
	true
      with Mismatch -> false

(*
let main() =
  for i = 1 to Array.length Sys.argv - 1 do
    print_unit_info Sys.argv.(i)
  done;
  exit 0

let _ = Printexc.catch main (); exit 0
*)
