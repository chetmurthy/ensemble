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
(* PERFREKEY.ML : D_WGL algorithm *)
(* Author: Ohad Rodeh 2/99 *)
(**************************************************************)
(* This layer accepts rekey actions from the user and initiates
 * the optimized rekey protocol. It acts in concert with the
 * OPTREKEY and REALKEYS layers. 
 * 
 * 1. A rekey action is accepted from below. 
 * 2. It is diverted to the leader. 
 * 3. The leader initiates the optimized rekey sequence by 
 *    passing the request up to optrekey. 
 * 4. Once optrekey is done, it passes a RekeyPrcl event with 
 *    the new group key back down. 
 * 5. Members log the new group key. A tree spanning the group 
 *    is computing through which acks will propogate. The leaves 
 *    sends Acks up tree.
 * 6. When Acks from all the children are received at the root,
 *    it prompts the group for a view change. 
*)
(**************************************************************)
open Util
open Layer
open View
open Event
open Trans
open Shared
(**************************************************************)
let name = Trace.filel "PERFREKEY"
(**************************************************************)

type header =
  | NoHdr
  | Cleanup 
  | AckCleanup
  | Ack of int * int
  | Rekey of bool 

(**************************************************************)

type state = {
  mutable agreed_key : Security.key ;
  rekeying           : Once.t ;
  blocking           : Once.t ;
  father             : rank option ;
  children           : rank list ;
  mutable commit     : bool ; (* Set only at the leader *)
  mutable acks       : int ;

  (* For cleanup sub-protocol *)
  mutable cleanup    : bool ;
  mutable init_time  : float ;

  (* For performance measurments *)
  mutable causal     : int ;
  mutable sum        : int ;
} 
	       
(**************************************************************)
	       
let dump = Layer.layer_dump name (fun (ls,vs) s -> [|
  sprintf "agreed_key=%s\n" (Security.string_of_key s.agreed_key);
  sprintf "blocking=%s, rekeying=%s\n"
    (Once.to_string s.blocking) (Once.to_string s.rekeying)
|])

(**************************************************************)

let init s (ls,vs) =   
  let degree = Param.int vs.params "perfrekey_ack_tree_degree" in
  let first_child n = degree * n + 1 in
  let father n = 
    if n<=0 then None
    else Some ((n-1)/degree)
  in
  let children =
    let rec loop rank degree =
      if (degree = 0) || (rank >= ls.nmembers) then []
      else rank :: (loop (succ rank) (degree - 1))
    in loop (first_child ls.rank) degree
  in { 
      agreed_key = Security.NoKey ;
      rekeying   = Once.create "rekeying" ;
      blocking   = Once.create "blocking" ;
      father     = father ls.rank ;
      children   = children ;
      commit     = false ;
      acks       = 0 ;

      cleanup    = false ;
      init_time  = 0.0 ;

      causal     = 0 ;
      sum        = 0 
    }
       
(**************************************************************)

let hdlrs s ((ls,vs) as vf) {up_out=up;upnm_out=upnm;dn_out=dn;dnlm_out=dnlm;dnnm_out=dnnm} =
  let failwith = layer_fail dump vf s name in
  let log = Trace.log2 name ls.name in
  let log1 = Trace.log2 (name^"1") ls.name in
  let log2 = Trace.log2 (name^"2") "" in
  let logm = Trace.log2 (" " ^ name) "" in
  
  let init_rekey () = 
    if ls.nmembers > 1 
      && ls.rank = 0 
      && not (Once.isset s.rekeying)
      && not (Once.isset s.blocking) then (
	Once.set s.rekeying ;
	log (fun () -> "init_rekey");
	upnm (create name ERekeyPrcl[]) 
      )
  in

  let check_send_ack () = 
    if s.agreed_key <> Security.NoKey then
      match s.children,s.father with 
	| [], None -> 
	    s.commit <- true ;
	    dnnm (create name EPrompt[])
	| [], Some father -> dnlm (sendPeer name father) (Ack(s.causal, s.sum))
	| children, None -> 
	    if s.acks = List.length children then (
	      logm (fun () -> sprintf " %d causal=%d sum=%d\n" ls.nmembers s.causal s.sum);
	      log1 (fun () -> "EPrompt");
	      dnnm (create name EPrompt[])
	    )
	| children, Some father -> 
	    if s.acks = List.length children then 
	      dnlm (sendPeer name father) (Ack(s.causal,s.sum))
  in

  let all_ack_cleanup () = 
    if not (Once.isset s.blocking) 
      && s.acks = List.length s.children then (
	s.acks <- 0;
	match s.father with 
	  | None -> 
	      let now = Unix.gettimeofday () in
	      logm (fun () -> sprintf " %d Done cleanup %1.4f" ls.nmembers (now -. s.init_time));
	      init_rekey () 
	  | Some father ->  dnlm (sendPeer name father) AckCleanup
      )
  in

  let init_cleanup () = 
    assert (ls.rank = 0);
    log (fun () -> "Started cleanup");
    dnlm (castEv name) Cleanup;
    s.cleanup <- true;
    dnnm (create name ERekeyCleanup[])
  in

  let init_rekey_full flg = 
    if flg then (
      s.init_time <- Unix.gettimeofday ();  (* HACK, for perf measurements *)
      init_cleanup () 
    ) else init_rekey () 
  in

  let up_hdlr ev abv () = up ev abv
			    
  and uplm_hdlr ev hdr = match getType ev,hdr with
    (* Got a request to start rekeying the group.
     *)
  | ESend, Rekey flg->
      if ls.rank<>0 then failwith "got a rekey request, but I'm leader";
      init_rekey_full flg

  | ESend, Ack (causal, sum) -> 
      let origin = getPeer ev in
      (*log2 (fun () -> sprintf "<- [%d] Ack(%d,%d)" origin causal sum);*)
      assert (List.mem origin s.children);
      s.acks <- succ s.acks ;
      s.sum <- s.sum + sum;
      s.causal <- max s.causal causal;
      check_send_ack ()

  | (ECast|ESend), Cleanup ->
      if not s.cleanup then (
	log (fun () -> "Member cleanup");
	s.cleanup <- true;
	dnnm (create name ERekeyCleanup[])
      );
      free name ev

  | (ECast|ESend), AckCleanup ->
      s.acks <- succ s.acks ;
      all_ack_cleanup ()

  | _ -> failwith unknown_local
	
  and upnm_hdlr ev = match getType ev with
  | ERekey ->
      let flg = getRekeyFlag ev in 
      log (fun () -> sprintf "ERekey(%b) event" flg) ;
      if ls.rank = 0 then 
	init_rekey_full flg
      else if not (Once.isset s.blocking) then 
      	dnlm (sendPeer name 0) (Rekey flg)

  (* Rekey protocol is complete. The final key, being delivered to 
   * all other group members, is attached. All leaves must send Acks to
   * their respective fathers. 
   *)
  | ERekeyPrcl -> 
      let agreed_key = getAgreedKey ev in
      let num, causal = getSecStat ev in
      s.sum <- s.sum + num;
      s.causal <- max s.causal causal ;
      s.agreed_key <- agreed_key ;
      log2 (fun () -> sprintf "AgreedKey=%s" (Security.string_of_key s.agreed_key));
      check_send_ack ()


  (* EBlock: Mark that we are now blocking.
   *)
  | EBlock ->
      Once.set s.blocking ;
      upnm ev
	
  (* EView: If a new_key has been selected, then change the appropriate
   * field in the view. 
   *)
  | EView ->
      log1 (fun () -> "up EView");
      let vs_new = getViewState ev in
      let ev = 
	if s.agreed_key <> Security.NoKey 
	  && vs_new.key = Security.NoKey then (
	    log1 (fun () -> "setting new key (up)");

	    (* HACK !!!, for peformance testing only.
	     *)
	    (*let key = Security.Common (Buf.of_string name "1234567812345678") in*)
	    let key = s.agreed_key in
	    let vs_new = View.set vs_new [Vs_key key; Vs_new_key true] in
	    set name ev[ViewState vs_new] 
	  ) else ev
      in
      upnm ev

  | EDump -> ( dump vf s ; upnm ev )
  | _ -> upnm ev
	
  and dn_hdlr ev abv = dn ev abv ()

  and dnnm_hdlr ev = match getType ev with
  (* If key dissemination is complete then Erase the key from the 
   * outgoing view. Add it on the way up.
   *)
  | EView ->
      log1 (fun () -> "dn EView");
      let vs_new = getViewState ev in
      let ev = 
	if s.agreed_key <> Security.NoKey then (
	  log1 (fun () -> "Erasing view key");
	  let vs_new = View.set vs_new [Vs_key Security.NoKey] in
	  set name ev[ViewState vs_new]
	) else ev
      in
      dnnm ev
	
  (* SECCHAN and REKEY/OPTREKEY+REALKEYS finished cleanup
   *)
  | ERekeyCleanup -> all_ack_cleanup ()
      
  | _ -> dnnm ev
	
in {up_in=up_hdlr;uplm_in=uplm_hdlr;upnm_in=upnm_hdlr;dn_in=dn_hdlr;dnnm_in=dnnm_hdlr}
     
let l args vf = Layer.hdr init hdlrs None NoOpt args vf
		  
let _ = 
  Param.default "perfrekey_ack_tree_degree" (Param.Int 6);
  Elink.layer_install name l

(**************************************************************)
    
