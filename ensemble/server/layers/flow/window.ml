(**************************************************************)
(* WINDOW.ML : window based flow control *)
(* Author: Takako M. Hickey, 12/95 *)
(**************************************************************)
open Layer
open Trans
open Event
open Util
open View
(**************************************************************)
let name = Trace.filel "WINDOW"
(**************************************************************)

type 'a state = {
  window	: seqno ;		(* window size *)
  fuzzy_th  : int ;         (* fuzzy threahold for this layer *)
  mutable acked	: seqno ;		(* seqno of last msg acked *)
  mutable seqno	: seqno ;		(* seqno of last msg sent *)
  mutable local_fuzzy : bool array ; (* All nodes' fuzziness estimates *)
  mutable failed : bool Arrayf.t ; (* What nodes have failed *)
  buffer	: ('a * Iovecl.t) Queuee.t (* msgs yet to be casted *)
}

(**************************************************************)

let dump vf s = Layer.layer_dump name (fun (ls,vs) s -> [|
  sprintf "window=%d, seqno=%d, acked=%d\n"  s.window s.seqno s.acked
|]) vf s

let init _ (ls,vs) = {
  (* Window related variables *)
  window      = Param.int vs.params "window_window" ;
  fuzzy_th       = Param.int vs.params "window_fuzzy_th" ;
  seqno	      = 0 ;
  acked       = 0 ;
  local_fuzzy = Array.create ls.nmembers false ;
  failed      = ls.falses ;
  buffer      = Queuee.create ()
}

let hdlrs s ((ls,vs) as vf) {up_out=up;upnm_out=upnm;dn_out=dn;dnlm_out=dnlm;dnnm_out=dnnm} =
  let failwith = layer_fail dump vf s name in
  let log = Trace.log2 name ls.name in
  let loga = Trace.log2 (name^"A") ls.name in

  let up_hdlr ev abv () = up ev abv
  and uplm_hdlr ev hdr = failwith "got uplm event"
  and upnm_hdlr ev = match getType ev with
  | EStable ->
      let len = Queuee.length s.buffer in

      (* Update ack information.
       *)
      let acks = getOwnAcked ev in
      s.acked <- Arrayf.get acks ls.rank;
      for i = 0 to pred ls.nmembers do
        if (not s.local_fuzzy.(i)) & not (Arrayf.get s.failed i) &
                                   s.acked > (Arrayf.get acks i) then
          s.acked <- Arrayf.get acks i
      done;
      let avail = s.window - (s.seqno - s.acked) in
      
      (* If window opens up again, send out buffered messages.
       *)
      for i = 1 to min len avail do
        let (abv,iov) = some_of name (Queuee.takeopt s.buffer) in
        s.seqno <- succ s.seqno ;
        dn (castIov name iov) abv ()
      done ;
      upnm ev

  | EFail ->
      s.failed <- getFailures ev ;
      upnm ev

  | EFuzzy ->
      (* Remember new local fuzzy information *)
      s.local_fuzzy <- 
        Array.map (fun fuzziness -> fuzziness > s.fuzzy_th)
          (Arrayf.to_array (getLocalFuzziness ev)) ;
      upnm ev

  | EAccount ->
      loga (fun () -> sprintf "acked=%d, seqno=%d, #buffer=%d" 
	s.acked s.seqno (Queuee.length s.buffer)) ;
      upnm ev

  | EDump -> ( dump vf s ; upnm ev )
  | _ -> upnm ev

  and dn_hdlr ev abv = match getType ev with
  | ECast iovl ->
      (* If too many unacknowledged messages, buffer the message
       * for future sending.
       *)
      if (s.seqno - s.acked) >= s.window then (
	log (fun () -> sprintf "window ECast: buffering seqno: %d ack: %d\n" 
	  (succ s.seqno) s.acked) ;
        Queuee.add (abv,iovl) s.buffer
      ) else (
        s.seqno <- succ s.seqno ;
        dn ev abv ()
      )

  | _ -> dn ev abv ()

  and dnnm_hdlr = dnnm

in {up_in=up_hdlr;uplm_in=uplm_hdlr;upnm_in=upnm_hdlr;dn_in=dn_hdlr;dnnm_in=dnnm_hdlr}

let l args vf = Layer.hdr init hdlrs None (FullNoHdr ()) args vf

let _ = 
  Param.default "window_window" (Param.Int 100) ;
  Param.default "window_fuzzy_th" (Param.Int 5) ;
  Layer.install name l

(**************************************************************)
