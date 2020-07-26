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
(* EVAL.MLI *)
(* Author: Robbert vanRenesse *)
(**************************************************************)
val half_time : float
type availability = UP | DOWN of Time.t
type server_info =
  { mutable avail: availability;
    mutable conf_value: float;
    mutable pref_value: float }
val servers : ((string * int) * server_info) list ref
val hosts : (string * float) list ref
val bring_down : string * int -> unit
val bring_up : string * int -> unit
val conf_servers : ('a * server_info) list -> unit
val conf_hosts : ((string * 'a) * server_info) list -> unit
val pref_servers : ((string * 'a) * server_info) list -> unit
val add_server : string -> int -> unit
val recalculate : 'a -> unit
val pick_server : (string * int) list -> string * int
