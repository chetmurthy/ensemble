(**************************************************************)
(* FZ_DECIDE.ML *)
(* Author: Roy Friedman 07/02 *)
(* Decide local and global fuzzy levels *)
(* Adapted from slander.ml by Zhen Xiao and Mark Hayden *)
(**************************************************************)
open Trans
open Util
open Layer
open Event
open View
(**************************************************************)
let name = Trace.filel "FZ_DECIDE"
(**************************************************************)

type fuzziness_t = int array option array
(* This type is an array indexed by number rank, 
 * where each cell is an option array of size nmembers 
 *)

let string_of_fuzziness fuzziness =
	String.concat "\n"
	  (Array.to_list (Array.map (fun f ->
	    string_of_option string_of_int_array f
	  ) fuzziness))

type header = Slander of int Arrayf.t

type state = {
  fuzzy_th : int ; 
  fuzziness : fuzziness_t ;
  mutable global_fuzziness : int Arrayf.t ;
  mutable failed : bool Arrayf.t
}

let dump = Layer.layer_dump name (fun (ls,vs) s -> [|
  sprintf "fuzziness=\n%s\n" (string_of_fuzziness s.fuzziness) ;
  sprintf "global_fuzziness=%s\n" (Arrayf.int_to_string s.global_fuzziness) ;
  sprintf "failed=%s\n" (Arrayf.bool_to_string s.failed)
|])

let init _ (ls,vs) =
  let fuzziness = Array.create ls.nmembers None in
  fuzziness.(ls.rank) <- (Some (Array.create ls.nmembers 0));
  {
    fuzzy_th = Param.int vs.params "fz_decide_threshold" ;
    fuzziness = fuzziness;
    global_fuzziness = Arrayf.create ls.nmembers 0;
    failed = ls.falses
  }

let hdlrs s ((ls,vs) as vf) {up_out=up;upnm_out=upnm;dn_out=dn;dnlm_out=dnlm;dnnm_out=dnnm} =
  let failwith = layer_fail dump vf s name in
  let log = Trace.log2 name ls.name in

  (* Compute new global fuzzy estimates. For each node we compute the minimal
   * fuzziness level reported by any non failed and non fuzzy member.
   *)
  let compute_global_fuzziness () =
    let global_fuzziness = Array.copy (some_of name s.fuzziness.(ls.rank)) in
    for node = 0 to pred ls.nmembers do
      if not (Arrayf.get s.failed node) &
               (some_of name s.fuzziness.(ls.rank)).(node) < s.fuzzy_th &
               not (is_none s.fuzziness.(node)) then
        for i = 0 to pred ls.nmembers do
          global_fuzziness.(i) <-
                int_min (some_of name s.fuzziness.(node)).(i) global_fuzziness.(i)
      done
    done;
    s.global_fuzziness <- Arrayf.of_array global_fuzziness

  in

  let up_hdlr ev abv () = up ev abv

  and uplm_hdlr ev hdr = match getType ev,hdr with
  (* Got slander message from another member.
   *)    
  | (ECast iov|ESend iov), Slander(new_local_fuzziness) ->
      let origin = getPeer ev in
      log (fun () -> sprintf "got Slander(%s) from %d" 
        (Arrayf.int_to_string new_local_fuzziness) origin) ;

      s.fuzziness.(origin) <- Some (Arrayf.to_array new_local_fuzziness);
      compute_global_fuzziness ();

      (* Inform everyone about the new local and global fuzziness levels
       *)
      dnnm (create name EFuzzy [
        LocalFuzziness (Arrayf.of_array (some_of name s.fuzziness.(ls.rank)));
        GlobalFuzziness s.global_fuzziness
      ]);      

      free name ev
      
  | _ -> failwith unknown_local
   
  (* Got FuzzyRequest event from the fz_detect layer of other nodes. 
   * Change local Fuzzy information
   *)
  and upnm_hdlr ev  = match getType ev  with
  | EFuzzyRequest ->
      let local_fuzziness = getLocalFuzziness ev in
      (* Slander the new fuzziness information
       *)
      s.fuzziness.(ls.rank) <- Some (Arrayf.to_array local_fuzziness);
      log (fun () -> sprintf "cast Slander on %s"
	    (Arrayf.int_to_string local_fuzziness)) ;
      dnlm (castEv name) (Slander local_fuzziness);
      compute_global_fuzziness ();
        
      (* Inform everyone about the new local and global fuzziness levels
       *)
      dnnm (create name EFuzzy [
        LocalFuzziness local_fuzziness;
        GlobalFuzziness s.global_fuzziness
      ]);

      free name ev
      
  | EFail ->
      s.failed <- getFailures ev ;
      upnm ev

  | EDump -> ( dump vf s ; upnm ev )
  | _ -> upnm ev

  and dn_hdlr ev abv = dn ev abv ()

  and dnnm_hdlr = dnnm

	in {up_in=up_hdlr;uplm_in=uplm_hdlr;upnm_in=upnm_hdlr;dn_in=dn_hdlr;dnnm_in=dnnm_hdlr}

let l args vf = Layer.hdr init hdlrs None NoOpt args vf

let _ =
  Param.default "fz_decide_threshold" (Param.Int 15) ;
  Layer.install name l

(**************************************************************)
