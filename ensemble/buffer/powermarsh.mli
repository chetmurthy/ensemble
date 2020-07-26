(**************************************************************)
(*
 *  Ensemble, (Version 1.00)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
(**************************************************************)
(* POWERMARSH *)
(* Author: Mark Hayden, 8/97 *)
(**************************************************************)
open Trans
(**************************************************************)

(* Support for marshalling objects + Iovecl to Iovecl and back.
 *)

(* Reference counting policy:

 * Marshalling: the original Iovecl reference is passed into
 * the return Iovecl, along with new entries for the object
 * area.

 * Unmarshalling: the returned Iovecl reference is
 * independently incremented, so both the input and return
 * Iovecl's need to be freed.

 *)
val f : debug -> Mbuf.t -> (('a * Iovecl.t) -> Iovecl.t) * (Iovecl.t -> ('a * Iovecl.t))
