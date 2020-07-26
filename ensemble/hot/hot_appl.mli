(**************************************************************)
(*
 *  Ensemble, 1.10
 *  Copyright 2001 Cornell University, Hebrew University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
(**************************************************************)
(* HOT_APPL.MLI *)
(* Authors: Alexey Vaysburd, Mark Hayden 11/96 *)
(**************************************************************)
open Trans
open Appl_intf.Protosi
(**************************************************************)

(* Types of C application's downcalls to Ensemble.  The
 * 'unit's are to force Ocaml to not use constant tags
 * in the representation.
 *)
type c_dncall = 
  | C_Join of Hot_util.join_options 
  | C_Cast of Buf.t
  | C_Send of endpt * Buf.t
  | C_Suspect of endpt array 
  | C_XferDone of unit
  | C_Protocol of string
  | C_Properties of string
  | C_Leave of unit
  | C_Prompt of unit
  | C_Rekey of unit
  | C_BlockOk of unit
  | C_Void of unit

type context

val context : debug -> context

val get : context -> id -> c_dncall -> unit

val join : 
  Mbuf.t ->
  context ->
  id ->					(* group ctx id *)
  (unit -> bool) ->			(* get downcalls *)
  View.full ->				(* initial view state *)
  Appl_intf.New.t ->			(* application interface *)
  unit

