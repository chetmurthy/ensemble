(**************************************************************)
(* FZ_SUSPECT.ML *)
(* Deciding that a node has failed based on its fuzziness level *)
(* Author: Roy Friedman 07/02 *)
(* Includes a few lines from suspect.ml by Mark Hayden *)
(**************************************************************)
open Trans
open Buf
open Util
open Layer
open View
open Event
(**************************************************************)
let name = Trace.filel "FZ_SUSPECT"
(**************************************************************)

type state = {
  fz_threshold	: int ;
  fz_aggressive_th : int ;
  mutable failed : bool Arrayf.t ;
  mutable blocked : bool ;
}

let dump = Layer.layer_dump name (fun (ls,vs) s -> [|
  sprintf "fuzzy_threshold=%d\n" s.fz_threshold;
  sprintf "failed=%s\n" (Arrayf.bool_to_string s.failed)
|])

let init _ (ls,vs) =
{
  fz_threshold   = Param.int vs.params "fz_suspect_th" ;
  fz_aggressive_th   = Param.int vs.params "fz_suspect_aggressive" ;
  failed  = Arrayf.create ls.nmembers false ;
  blocked = false
}

let hdlrs s ((ls,vs) as vf) {up_out=up;upnm_out=upnm;dn_out=dn;dnlm_out=dnlm;dnnm_out=dnnm} =
  let failwith = layer_fail dump vf s name in
  let log = Trace.log2 name ls.name in
  let logp = Trace.log2 (name^"P") ls.name in

  let up_hdlr ev abv () = up ev abv

  and uplm_hdlr ev hdr = failwith unknown_local

  and upnm_hdlr ev = match getType ev with

    (* EFail: mark the failed members.
     *)
  | EFail ->
      s.failed <- getFailures ev ;
      upnm ev

    (* EBLock: remember that we are blocking. From this point on, we use
     * the agressive_fuzzy_th to determine failures. The rationale is twofold:
     * 1) since we are already changing a view, why be lenient about this
     * 2) from this point on, until the view change completes, the application
     *    is blocked, so this way we shortened the blocking period for the
     *    application.
     *)
  | EBlock ->
      s.blocked <- true;
      upnm ev

    (* EFuzzy: every so often:
     *   1. check for lagre changes in fuzziness
     *   2. ping the other members
     *)
  | EFuzzy ->
      let local_fuzziness = getLocalFuzziness ev in
      let any = ref false in
      let suspicions = Array.create ls.nmembers false in
      for i = 0 to pred ls.nmembers do
        if i <> ls.rank & not (Arrayf.get s.failed i) &
                   ((Arrayf.get local_fuzziness i) > s.fz_threshold or
                    (s.blocked &
                     (Arrayf.get local_fuzziness i) > s.fz_aggressive_th))
                                                                    then (
          suspicions.(i) <- true;
          any := true
        )
      done;
      if !any then (
        let suspicions = Arrayf.of_array suspicions in
        log (fun () -> sprintf "FZ Suspect:%s" (Arrayf.bool_to_string suspicions)) ;
        dnnm (suspectReason name suspicions name)
      );
      upnm ev

  | EDump -> dump vf s ; upnm ev
  | _ -> upnm ev

  and dn_hdlr ev abv = dn ev abv ()
  and dnnm_hdlr = dnnm

in {up_in=up_hdlr;uplm_in=uplm_hdlr;upnm_in=upnm_hdlr;dn_in=dn_hdlr;dnnm_in=dnnm_hdlr}

let l args vf = Layer.hdr init hdlrs None NoOpt args vf

let _ =
  Param.default "fz_suspect_th" (Param.Int 30) ;
  Param.default "fz_suspect_aggressive" (Param.Int 10) ;
  Layer.install name l

(**************************************************************)
