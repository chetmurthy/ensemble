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
(* XLIST.MLI *)
(* Author: Robbert vanRenesse *)
(**************************************************************)
val map : 'a -> 'b -> ('a * 'b) list -> ('a * 'b) list
val take : 'a -> ('a * 'b) list -> 'b * ('a * 'b) list
val remove : 'a -> ('a * 'b) list -> ('a * 'b) list
val except : 'a -> ('a * 'b) list -> ('a * 'b) list
val strtolower : string -> string
val strassoc : string -> (string * 'a) list -> 'a
val insert : 'a * 'b -> ('a * 'b) list -> ('a * 'b) list
val insert_if_new : 'a * 'b -> ('a * 'b) list -> ('a * 'b) list
val add : 'a -> 'a list -> 'a list
val minus : 'a -> 'a list -> 'a list
