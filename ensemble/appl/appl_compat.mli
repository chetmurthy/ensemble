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
(* APPL_COMPAT.MLI: conversion from old to new interfaces *)
(* Author: Mark Hayden, 12/98 *)
(**************************************************************)

type ('a,'b) header
val compat : Appl_intf.Old.t -> ((unit,unit)header * Iovecl.t) Appl_intf.New.full
val pcompat : ('a,'b,'c,'d) Appl_intf.Old.power -> (('a,'b)header) Appl_intf.New.power
