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

(* $Id: printe.mli,v 1.2 1999/01/10 21:13:07 hayden Exp $ *)

(* Module [Printf]: formatting printing functions *)

val f : (string -> 'b) -> ('a, unit, 'b) format -> 'a
