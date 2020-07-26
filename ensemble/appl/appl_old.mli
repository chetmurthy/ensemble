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
(* APPL_OLD.MLI *)
(* Author: Mark Hayden, 12/98 *)
(**************************************************************)
open Trans
open Appl_intf open Old
(**************************************************************)

(* A debugging interface: it takes an interface as an argument
 * and wraps itself around the interface, printing debugging
 * information on most events.
 *)
val debug : debug -> ('a,'b,'c,'d) full -> ('a,'b,'c,'d) full

(* Conversion functions for various types
 * of interfaces.
 *)
val full : ('a,'b,'c,'d) full -> t
val timed : debug -> ('a,'b,'c,'d) full -> ('a,'b,'c,'d) full
val iov : Mbuf.t -> iov -> t

(**************************************************************)
