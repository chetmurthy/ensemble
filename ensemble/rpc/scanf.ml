(**************************************************************)
(* SCANF.ML *)
(* Author: Robbert vanRenesse *)
(**************************************************************)
(*
 * This implements sscanf.  It returns a list of the matched items.
 *)

open Printf

exception Parse_error

type value
  = Char of char
  | Int of int
  | Float of float
  | String of string
  | End of int

let iscanf str offset fmt =
  (* See if c is included in one of the characters in the string chars.
   *)
  let included c chars =
    let len = String.length chars in
    let rec find i =
      if i = len then false
      else if c = (String.get chars i) then true
      else find (i + 1)
    in find 0
  in
  let len_str = String.length str in
  (* Return a substring of s, starting at offset i, consisting of
   * characters in the given string chars.  Also return the new offset.
   *)
  let scan_chunk s i chars =
    let len_s = String.length s in
    let j = ref i in
    while (!j < len_s) && (included (String.get s !j) chars) do
      incr j
    done;
    ((if i = !j then "" else String.sub s i (!j - i)), !j)
  (* Return a substring of s, starting at offset i, consisting of
   * characters *not* in the given string chars.  Also return the
   * new offset.
   *)
  and scan_but_chunk s i chars =
    let len_s = String.length s in
    let j = ref i in
    while (!j < len_s) && not (included (String.get s !j) chars) do
      incr j
    done;
    ((if i = !j then "" else String.sub s i (!j - i)), !j)
  in
  (* Skip all blanks starting at offset i.  Return the new offset.
   *)
  let skip_blanks i =
    let j = ref i in
    while (!j < len_str) && (included (String.get str !j) " \t\n") do
      incr j
    done;
    !j
  in
  let scan_char i =
    (String.get str i, i + 1)
  and scan_int i =
    let (s, i) = scan_chunk str i "0123456789" in
    (int_of_string s, i)
  and scan_float i =
    let (s, i) = scan_chunk str i "0123456789.eE" in
    (float_of_string s, i)
  and scan_string i =
    scan_but_chunk str i " \t\n"
  in
  let len_fmt = String.length fmt in
  (* i is an offset in str, and j an offset in fmt.  Scan the next item
   * as specified in fmt.
   *)
  let rec doscan i j =
    let do_match c j =    
      if (String.get str i) = c then
        doscan (i + 1) j
      else
        raise Parse_error
    in
    if j = len_fmt then
      [End i]
    else
      let c = String.get fmt j in
      if j < (len_fmt - 1) & c = '%' then
        match String.get fmt (j + 1) with
          | 'c' ->
	      let (v, i) = scan_char i in
	      (Char v) :: (doscan i (j + 2))
	  | 'd' ->
	      let i = skip_blanks i in
	      let (v, i) = scan_int i in
	      (Int v) :: (doscan i (j + 2))
	  | 'f' ->
	      let i = skip_blanks i in
	      let (v, i) = scan_float i in
	      (Float v) :: (doscan i (j + 2))
	  | 's' ->
	      let i = skip_blanks i in
	      let (v, i) = scan_string i in
	      (String v) :: (doscan i (j + 2))
	  | '[' ->
	      if (String.get fmt (j + 2)) = '^' then
	        let (chars, j) = scan_but_chunk fmt (j + 3) "]" in
	        let (v, i) = scan_but_chunk str i chars
	        in (String v) :: (doscan i (j + 1))
	      else
	        let (chars, j) = scan_but_chunk fmt (j + 2) "]" in
	        let (v, i) = scan_chunk str i chars
	        in (String v) :: (doscan i (j + 1))
	  | _ as c ->
	      do_match c (j + 2)
      else
        do_match c (j + 1)
  in doscan offset 0

let sscanf str fmt =
  iscanf str 0 fmt
(*
(* For debugging...
 *)
let rec print_result =
  let print = function
    | Char c ->
        printf "Char '%c'\n" c
    | Int v ->
        printf "Int '%d'\n" v
    | Float v ->
        printf "Float '%f'\n" v
    | String v ->
        printf "String '%s'\n" v
    | End o ->
	printf "End '%d'\n" o
  in function
    | hd :: tl ->
        print hd; flush stdout;
	print_result tl
    | [] ->
	()
*)
