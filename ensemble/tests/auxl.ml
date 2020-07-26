(**************************************************************)
(* AUX.ML: Auxilary code and definitions *)
(* Author: Ohad Rodeh , 9/99 *)
(**************************************************************)
let name = "AUXL"
(**************************************************************)

open Printf

(**************************************************************)
let base_dir = "/cs/phd/orodeh/zigzag/lang/caml/viewperf/dsh"
let client   = "/cs/phd/orodeh/zigzag/lang/caml/viewperf/dsh/client"
let par = ["par1";"par2";"par3";"par4";"par5";"par6";"par7";"par8";
           "par9";"par10";"par11";"par12";"par13";"par14";"par15";"par16"]
let pd = ["pd-1"; "pd-2"; "pd-3"; "pd-4"; "pd-5"; "pd-6"; "pd-7"; "pd-8";
          "pd-9"; "pd-10"; "pd-11"; "pd-12"; "pd-13"; "pd-14"; "pd-15"; 
          "pd-16"; "pd-17"; "pd-18";  "pd-19"; "pd-20"]
let apollo = ["apollo-1";"apollo-2";"apollo-3";"apollo-4"]
let amos= ["amos-1";"amos-2";"amos-3";"amos-4";
           "amos-5";"amos-6";"amos-7";"amos-8"]
let rh = ["rh-01"; "rh-02"; "rh-03"; "rh-04"; "rh-05"; "rh-06"; "rh-07"; "rh-08";
          "rh-09"; "rh-10"; "rh-11"; "rh-12"; "rh-13"; "rh-14"; "rh-15"; 
          "rh-16"; "rh-17"; "rh-18";  "rh-19"; "rh-20"]
let pomela = ["pomela1";"pomela2";"pomela3";"pomela4"] 
let limon  = ["limon2"]
(**************************************************************)


(* Output redirection options. To_coord redirect output to 
 * the coord. Local keeps it local.
*)
type re_opts = 
  | To_coord
  | Local
  | File of string
  | Time
  | Record
  | Num of int

let string_of_re_opts = function
  | To_coord -> "To_coord"
  | Local    -> "Local"
  | File s   -> "File " ^ s
  | Time     -> "Time"
  | Record   -> "Record"
  | Num i    -> "Num " ^ (string_of_int i)

type mngr_msg = 
  | Do_command of string 
  | Do_finish
  | Do_unit

type res_msg = 
  | Line of string
  | Finish

let string_of_res_msg = function 
  | Line   s -> "Line " ^ s
  | Finish -> "Finish"

let string_of_mngr_msg = function
  | Do_command c -> "Do_command " ^ c
  | Do_finish    -> "Do_finish"
  | Do_unit      -> "Do_unit"

let machine m = 
  let i = String.index m '.' in
  String.sub m 0 i 

let res_port = 9002 

let flush_out () = flush Pervasives.stdout

let print s = print_string s; flush_out ()

(**************************************************************)
(* From Ensemble's Util module
*)

let string_of_list  f l = sprintf "[%s]" (String.concat "|" (List.map f l))

(* The identity function.
 *)
let ident a = a
(**************************************************************)
(* Ensemble utitlites
*)
let hsys_error e =
  match e with
  | Out_of_memory  -> "Out_of_memory";
  | Stack_overflow -> "Stack_overflow";
  | Not_found      -> "Not_found"
  | Failure s      -> sprintf "Failure(%s)" s
  | Sys_error s    -> sprintf "Sys_error(%s)" s
  | Unix.Unix_error(err,s1,s2) ->
      let msg = 
	try Unix.error_message err 
      	with _ -> "Unix(unknown error)"
      in
      let s1 = if s1 = "" then "" else ","^s1 in
      let s2 = if s2 = "" then "" else ","^s2 in
      sprintf "Unix(%s%s%s)" msg s1 s2
  | Invalid_argument s -> 
      raise e
  | _ -> "Other error"

let string_of_unit ()      = "()"
let string_of_pair fa fb (a,b) = sprintf "(%s,%s)" (fa a) (fb b)
let string_of_list     f l = sprintf "[%s]" (String.concat "|" (List.map f l))
let string_of_array    f a = string_of_list f (Array.to_list a)
let string_of_int_array  a = string_of_array string_of_int a
let string_of_int_list   l = string_of_list string_of_int l
let string_of_bool         = function true -> "T" | false -> "f"
let string_of_bool_list  l = string_of_list string_of_bool l
let string_of_bool_array l = string_of_array string_of_bool l
let string_of_string_list l = string_of_list ident l
(**************************************************************)
