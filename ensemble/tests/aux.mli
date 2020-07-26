(**************************************************************)
(* AUX.MLI: Auxilary code and definitions *)
(* Author: Ohad Rodeh , 9/99 *)
(**************************************************************)

(* useful string names 
*)
val base_dir : string 
val client   : string
val par : string list
val pd : string list
val apollo : string list
val rh : string list

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

val string_of_re_opts : re_opts -> string

type mngr_msg = 
  | Do_command of string 
  | Do_finish
  | Do_unit

type res_msg = 
  | Line of string
  | Finish


val string_of_res_msg : res_msg -> string 
val string_of_mngr_msg : mngr_msg -> string 

(* This machine's name (short)
*)
val machine : string -> string

val res_port : int 

val flush_out : unit -> unit
val print : string -> unit 
val string_of_list : ('a -> string) -> 'a list -> string
val ident          : 'a -> 'a

(**************************************************************)
(* From the Ensemble package.
*)
val hsys_error : exn -> string

val string_of_unit      : unit -> string
val string_of_pair      : 
  ('a -> string) -> ('b -> string) -> ('a * 'b -> string)
val string_of_list 	: ('a -> string) -> 'a list -> string
val string_of_array 	: ('a -> string) -> 'a array -> string
val string_of_int_list 	: int list -> string
val string_of_int_array : int array -> string
val string_of_bool	: bool -> string
val string_of_bool_list : bool list -> string
val string_of_bool_array : bool array -> string
val string_of_string_list : string list -> string
(**************************************************************)



