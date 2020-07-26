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

(* $Id: printe.mli,v 1.4 2002/10/13 10:06:47 orodeh Exp $ *)

(* Module [Printf]: formatting printing functions *)

val f : (string -> 'b) -> ('a, unit, 'b) format -> 'a
