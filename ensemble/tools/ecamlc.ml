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
(* ECAMLC.ML *)
(* Author: Mark Hayden, 12/96 *)
(**************************************************************)
open Printf
open Mkutil
(**************************************************************)

let unsafe = ref false
let noassert = ref false
let thread = ref false
let profile = ref false
let gprofile = ref false
let assembler = ref false
let compact = ref false
let destdir = ref None
let includes = ref []
let execdir = Sys.getcwd ()
let debugger = ref false
let ccopts = ref []
let inline = ref ""

let compile srcfile =
  let srcdir  = Filename.dirname srcfile in
  let srcbase = Filename.basename srcfile in
  let srcchop = Filename.chop_extension srcbase in
  let interface = Filename.check_suffix srcfile ".mli" in
  let comp =
    match !optflag, !profile, interface with
    | false, true, false -> "ocamlcp -p fil "
    | false, _, _ -> "ocamlc"
    | true, _, _ -> "ocamlopt"
  in

  let errout = 
  if platform = Unix then (
    Filename.temp_file "ecamlc" "err"
  ) else ""
  in

  let debugger = if !debugger && not !optflag then ["-g"] else [] in
  let inline = if !inline <> "" && !optflag then [!inline] else [] in
  let assembler = if !assembler && !optflag then ["-S"] else [] in
  let compact = if !compact && !optflag then ["-compact"] else [] in
  let noassert = if !noassert then ["-noassert"] else [] in
  let unsafe = if !unsafe then ["-unsafe"] else [] in
  let thread = if !thread && not !optflag then ["-thread"] else [] in
  let output = 
    if platform = Unix then
      [sprintf "1> %s 2> %s" errout errout] 
    else 
      [] 
  in
  let gprofile = if !gprofile then ["-p"] else [] in
  let includes =
    List.map (fun dir ->
      let dir =
	if Filename.is_relative dir then
	  Filename.concat execdir dir	  
	else 
	  dir
      in
      sprintf "-I %s" dir
    ) !includes 
  in

  let com = [
    [comp ; "-c"] ;
    gprofile ; 
    inline ;
    assembler ;
    gprofile ;
    compact ;
    debugger ;
    unsafe ;
    noassert ;
    inline ;
    thread ;
    !ccopts ;
    includes ;
    [srcbase] ;
    output
  ] in

  let com = List.concat com in
  let com = String.concat " " com in 

  (* Change to the source directory, compile, and change back.
   *)
  Sys.chdir srcdir ;
  if !verbose then (
    eprintf "ecamlc: %s\n" com ;
    flush stderr
  ) ;
  let ret = Sys.command com in
  Sys.chdir execdir ;

  if platform = Unix then (
(*  if ret <> 0 then *)  (
    if !verbose then (
      eprintf "ecamlc: compiler returned error code %d\n" ret ;
      flush stderr
    ) ;
    if Sys.file_exists errout then (
      let ch = open_in errout in
      (try while true do
        let line = (try input_line ch ;
		   with _ -> raise End_of_file ) in	
	let line = global_replace line srcbase srcfile in
	let line =
	  match hacker () with 
	  | Some login ->
(*	    let eroot = sprintf "/home/%s/mnt/sakhalin/ensemble/" login in*)
	    let eroot = sprintf "/home/%s/ensemble/" login in
(*	    let eroot = sprintf "/home/%s/spool/ensemble/" login in*)
	    let line = global_replace line "../" eroot in
	    let line = global_replace line (sprintf "/amd/gulag/a/%s/" login) eroot in
	    let line = global_replace line (sprintf "/amd/sunup/a/%s/" login) eroot in
	    let line = global_replace line (sprintf "/amd/night/e/%s/" login) eroot in
	    line
	  | None -> line
	in
        print_string line ;
        print_newline () ;
      done with End_of_file -> ()) ;
      (try Sys.remove errout;
       with _ -> if !verbose then eprintf "Can't remove %s\n"  errout)
    ) ;

    if !verbose then
      eprintf "ecamlc: exiting\n"

   )
  );

  begin
    let efile_exists f =
      if Sys.file_exists f then (
      	let ch = open_in f in	
      	let len = in_channel_length ch in
	close_in ch ;
	if len = 0 then (
	  Sys.remove f ;
	  false
	) else true
      ) else false
    in

    match !destdir with
    | None -> ()
    | Some destdir -> (
	Array.iter (fun ext ->
	  let src = Filename.concat srcdir (srcchop ^ ext) in
	  let dst = Filename.concat destdir (srcchop ^ ext) in

	  if src <> dst && efile_exists src then (
	    if !verbose then 
	      eprintf "ecamlc: moving %s -> %s\n" src dst ;
	    if Sys.file_exists dst then
	      Sys.remove dst ;

            Sys.catch_break true ;
      	    begin try 

	      if !verbose then
		eprintf "ecamlc: actual rename being done\n" ;

      	      Sys.rename src dst ;
	      
	      (* For cmx files, also make a .cmx copy (for inlining).
	       *)
	      (* This is a total hack: prevent there from being
	       * a socket.cmx so that inlining cannot be done against
	       * it.
	       *)

      	      Sys.catch_break false
      	    with
	    | Sys.Break ->
	        if Sys.file_exists dst then
		  Sys.remove dst ;
		exit 1
	    | e ->
	        Sys.catch_break false ;
      	        raise e 
	    end
	  )
	) (oc_extc ())
      )
  end ;

  if ret <> 0 then 
    exit ret

let timestamp file =
  try
    let stat = Unix.stat file in
    Some stat.Unix.st_mtime
  with _ -> None

let need_compile srcfile =
  let srcdir  = Filename.dirname srcfile in
  let srcbase = Filename.basename srcfile in
  let srcchop = Filename.chop_extension srcbase in
  let interface = Filename.check_suffix srcfile ".mli" in
  let destext = match !optflag, (Filename.check_suffix srcfile ".mli") with
  | _,true -> ".cmi"
  | true,false -> !plat^".cmx"
  | false,false -> ".cmo"
  in

  let dstfile = srcchop^destext in
  let dstfile =
    match !destdir with
    | Some d -> Filename.concat d dstfile
    | None -> dstfile
  in
  
  let modified =
    match (timestamp srcfile),(timestamp dstfile) with
    | Some(srctime),Some(dsttime) ->
      	srctime > dsttime 
    | _ -> true
  in

  let consistent =
    let stdlib =
      try Some(Sys.getenv "CAMLLIB") 
      with Not_found -> None
    in
    match stdlib with
    | None -> 
	if !verbose then
	  eprintf "ecamlc: CAMLLIB undefined\n" ;
	false
    | Some stdlib ->
	try
	  Echeck.check dstfile !includes stdlib
	with _ -> false
  in

  if !verbose then
    eprintf "ecamlc: modified=%b inconsistent=%b\n" modified (not consistent) ;
  
  let ret = modified || not consistent in
  if not ret then (
    touch dstfile false
  ) ;
  ret

let compile srcfile =
  if hacker () = None || need_compile srcfile then (
    compile srcfile
  ) else (
    (* Destination file is modified above.
     *)
    eprintf "ecamlc: no recompilation necessary for %s\n" srcfile ;
  )

let main () =
  try
    Arg.parse
      ["-I", Arg.String(fun dir -> includes := dir :: !includes),"";
       "-o", Arg.String(fun dir -> destdir := Some dir),"";
       "-Io", Arg.String(fun dir -> destdir := Some dir ; includes := dir :: !includes),"both -o and -I";
       "-S", 		Arg.Set assembler,"" ;
       "-g",            Arg.Set debugger,"" ;
       "-verbose",      Arg.Set verbose,"" ;
       "-unsafe",	Arg.Set unsafe,"" ;
       "-noassert",	Arg.Set noassert,"" ;
       "-thread",       Arg.Set thread,"" ;
       "-profile",      Arg.Set profile,"" ;
       "-p",            Arg.Set gprofile,"" ;
       "-plat",         Arg.String(fun s -> plat := "-"^s),"" ;
       "-inline",       Arg.Int(fun i -> inline := sprintf "-inline %d" i),"" ;
       "-compact",      Arg.Set compact,"" ;
       "-ccopt",        Arg.String(fun s -> ccopts := !ccopts @ [" -ccopt "^s]),"" ;
       "-opt",          Arg.Set optflag,""]
      (fun file -> compile file)
      ""
  with x -> raise x

let _ = 
  Printexc.catch main () ;
  exit 0
