(**************************************************************)
(*
 *  Ensemble, 1.10
 *  Copyright 2001 Cornell University, Hebrew University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
open Arge
(**************************************************************)

let run top =
  let username = username () in
  let ept,trans_info,alarm = default_info "wb" true in
  init top trans_info ept username ;
  horus_init ()

(**************************************************************)

let wb ctx _ args =
  match ctx.viewer_frame with
  | Some w -> run w
  | None -> failwith "Requires widget"

let _ = Applets.register "wb" wb

(**************************************************************)
