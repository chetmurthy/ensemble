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
(* APPL_POWER.MLI *)
(* Author: Mark Hayden, 12/98 *)
(**************************************************************)
open Trans

val oldf : Mbuf.t -> ('a,'b,'c,'d) Appl_intf.Old.power -> Appl_intf.Old.t
val newf : Mbuf.t -> 'a Appl_intf.New.power -> Appl_intf.New.t
