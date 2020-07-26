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
(* XLIST.ML *)
(* Author: Robbert vanRenesse *)
(**************************************************************)

(* Map a to b in the given association list.
 *)
let rec map a b = function
    (x, _) :: tl when x = a -> (a, b) :: tl
  | (x, y) :: tl -> (x, y) :: (map a b tl)
  | [] -> [a, b]

(* Take the given element from the list.  Return the element and the
 * list.
 *)
let rec take e = function
    (a, b) :: tl ->
      if a = e then
	b, tl
      else
	let f, l = take e tl in
	f, ((a, b) :: l)
  | [] ->
      raise Not_found

(* Remove (a, _) from the given association list.
 *)
let rec remove a = function
    (x, _) :: tl when x = a -> tl
  | (x, y) :: tl -> (x, y) :: (remove a tl)
  | [] -> raise Not_found

(* Like remove, but doesn't raise an exception if the element
 * isn't there.
 *)
let rec except e = function
    (a, b) :: tl ->
      if a = e then tl else (a, b) :: (except e tl)
  | [] -> []

(* Convert a string to all lower-case.
 *)
let strtolower str =
  let tolower = function
      'A'..'Z' as c ->
	Char.chr ((Char.code c) - (Char.code 'A') + Char.code ('a'))
    | _ as c ->
	c
  in
  let len = String.length str in
  let out = String.make len 'x' in
  for i = 0 to len - 1 do
    String.set out i (tolower (String.get str i))
  done;
  out

(* Like List.assoc, but ignore case of key.
 *)
let strassoc x l =
  let y = strtolower x in
  let rec assoc = function
      [] -> raise Not_found
    | (a,b)::tl -> if (strtolower a) = y then b else assoc tl
  in
  assoc l

(* Insert the given pair in the given association list.
 *)
let rec insert (name, valu) = function
    (hdn, hdv) :: tl ->
      if name = hdn then
	(name, valu) :: tl
      else
	(hdn, hdv) :: (insert (name, valu) tl)
  | [] ->
      [ (name, valu) ]

(* Insert the given pair in the given association list
 * only if there is no entry yet.
 *)
let rec insert_if_new (name, valu) = function
    (hdn, hdv) :: tl ->
      if name = hdn then
	(hdn, hdv) :: tl
      else
	(hdn, hdv) :: (insert (name, valu) tl)
  | [] ->
      [ (name, valu) ]

(* Add the given element to the given list.
 *)
let rec add v = function
    hd :: tl ->
      if hd = v then
	hd :: tl
      else
	hd :: (add v tl)
  | [] ->
      [v]

(* Remove the given element of the given list.
 *)
let rec minus v = function
    hd :: tl ->
      if hd = v then
	tl
      else
	hd :: (minus v tl)
  | [] ->
      []
