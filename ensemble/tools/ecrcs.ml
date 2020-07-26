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

(* $Id: ecrcs.ml,v 1.2 2000/04/14 06:34:27 hayden Exp $ *)

(* Print the digests of unit interfaces *)

let load_path = ref ["."]
let first = ref true

module Config = struct
  let exec_magic_number = "Caml1999X006"
  and cmi_magic_number = "Caml1999I006"
  and cmo_magic_number = "Caml1999O004"
  and cma_magic_number = "Caml1999A005"
  and cmx_magic_number = "Caml1999Y006"
  and cmxa_magic_number = "Caml1999Z007"
  and ast_impl_magic_number = "Caml1999M008"
  and ast_intf_magic_number = "Caml1999N007"
end

type linking_error =
    Undefined_global of string
  | Unavailable_primitive of string

type error =
    Not_a_bytecode_file of string
  | Inconsistent_import of string
  | Unavailable_unit of string
  | Unsafe_file
  | Linking_error of string * linking_error
  | Corrupted_interface of string

exception Error of error

let digest_interface filename =
  let ic = open_in_bin filename in
  try
    let buffer = String.create (String.length Config.cmi_magic_number) in
    really_input ic buffer 0 (String.length Config.cmi_magic_number);
    if buffer <> Config.cmi_magic_number then begin
      close_in ic;
      raise(Error(Corrupted_interface filename))
    end;
    input_value ic;
    let crc =
      match input_value ic with
        (_, crc) :: _ -> crc
      | _             -> raise(Error(Corrupted_interface filename))
    in
    close_in ic;
    crc
  with End_of_file | Failure _ ->
    close_in ic;
    raise(Error(Corrupted_interface filename))

let print_crc filename =
  let unit = Filename.chop_extension (Filename.basename filename) in
  try
    let crc = digest_interface filename in
    if !first then first := false else print_string ";\n";
    print_string "  \""; print_string (String.capitalize unit);
    print_string "\",\n    \"";
    for i = 0 to String.length crc - 1 do
      Printf.printf "\\%03d" (Char.code crc.[i])
    done;
    print_string "\""
  with exn ->
    prerr_string "Error while reading the interface for ";
    prerr_endline unit;
    begin match exn with
      Sys_error msg -> prerr_endline msg
    | Error _ -> prerr_endline "Ill formed .cmi file"
    | _ -> raise exn
    end;
    exit 2

let usage = "Usage: extract_crc [-I <dir>] <files>"

let main () =
  print_string "let crc_unit_list = [|\n";
  Arg.parse
    ["-I", Arg.String(fun dir -> load_path := !load_path @ [dir]),
           "<dir>  Add <dir> to the list of include directories"]
    print_crc usage;
  print_string "\n|]\n"

let _ = main(); exit 0

     
