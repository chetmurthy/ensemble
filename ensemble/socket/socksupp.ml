(**************************************************************)
(* SOCKSUPP.ML *)
(* Author: Mark Hayden, 8/97 *)
(**************************************************************)

let unit _ = ()

let print_line s =
  output_string stderr s ;
  output_char stderr '\n' ;
  flush stderr

(**************************************************************)

let is_unix =
  match Sys.os_type with
  | "Unix" -> true
  | "Win32" -> false
  | s -> 
      print_line ("SOCKSUPP:get_config:failed:os="^s) ;
      exit 1
  
(**************************************************************)
