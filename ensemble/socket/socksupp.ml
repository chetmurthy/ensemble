(**************************************************************)
(*
 *  Ensemble, 1_42
 *  Copyright 2003 Cornell University, Hebrew University
 *           IBM Israel Science and Technology
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
(**************************************************************)
(* SOCKSUPP.ML *)
(* Author: Mark Hayden, 8/97 *)
(**************************************************************)

type buf = string
type len = int
type ofs = int
type socket = Unix.file_descr

type timeval = {
  mutable sec10 : int ;
  mutable usec : int
} 

type mcast_send_recv = 
  | Recv_only
  | Send_only
  | Both

type win = 
    Win_3_11
  | Win_95_98
  | Win_NT_3_5
  | Win_NT_4
  | Win_2000

type os_t_v = 
    OS_Unix
  | OS_Win of win

(**************************************************************)

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
let max_msg_size = 8 * 1024
