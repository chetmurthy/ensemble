(**************************************************************)
(* FZ_DETECT.ML *)
(* Detecting fuzziness by exchaning heartbeats *)
(* Author: Roy Friedman 07/02 *)
(* Modified from suspect.ml by Mark Hayden, 11/96 *)
(**************************************************************)
open Trans
open Buf
open Util
open Layer
open View
open Event
(**************************************************************)
let name = Trace.filel "FZ_DETECT"
(**************************************************************)

type header = Ping of bool Arrayf.t * ltime Arrayf.t

type state = {
  sweep		: Time.t ;
  spacing	: Time.t ;

  send	    : ltime array ;
  (* Send lists how many Ping messages that the other hosts have sent, and
   *  how many Ping messages that this node send 
   *)
  recv      : ltime array ;
  (* Recv lists how many Ping messages the other hosts report to have 
   * received from me 
   *)
  fz_threshold	: int ;
  fuzziness : int array ;
  mutable last_reported : int Arrayf.t ;
  mutable failed : bool Arrayf.t ;
  mutable next_sweep : Time.t
}

let conv rank ofs idles =
  let idles = Array.map (fun idle -> string_of_int (ofs - idle)) idles in
  idles.(rank) <- "_" ;
  string_of_array ident idles

let dump = Layer.layer_dump name (fun (ls,vs) s -> [|
  sprintf "failed=%s\n" (Arrayf.bool_to_string s.failed) ;
  sprintf "fuzziness=%s\n" (string_of_int_array s.fuzziness) ;
  sprintf "send=%s\n" (string_of_int_array s.send) ;
  sprintf "recv=%s\n" (string_of_int_array s.recv) ;
  sprintf "idle=%s\n" (conv ls.rank s.send.(ls.rank) s.recv)
|])

(* Stagger out stability events based on the rank and the time
 * frame over which to space things. 
*)
let space_out rank nmembers spacing = 
  let spacing = Time.to_float spacing in
  let rltv = (float rank) /. (float nmembers) in
  let time = mod_float rltv spacing in
  Time.of_float time

let init _ (ls,vs) =
  let spacing    = Param.time vs.params "fz_detect_spacing" in
{
  sweep	     = Param.time vs.params "fz_detect_sweep" ;
  spacing    = spacing ;

  failed     = ls.falses ;
  send 	     = Array.create ls.nmembers 0 ;
  recv       = Array.create ls.nmembers 0 ;
  fz_threshold   = Param.int vs.params "fz_detect_threshold" ;
  fuzziness  = Array.create ls.nmembers 0 ;
  last_reported = Arrayf.create ls.nmembers 0;
  
  (* We stagger heartbeats a little bit. 
   *)
  next_sweep = space_out ls.rank ls.nmembers spacing
}

let hdlrs s ((ls,vs) as vf) {up_out=up;upnm_out=upnm;dn_out=dn;dnlm_out=dnlm;dnnm_out=dnnm} =
  let failwith = layer_fail dump vf s name in
  let log = Trace.log2 name ls.name in
  let logp = Trace.log2 (name^"P") ls.name in

  let up_hdlr ev abv () = up ev abv
  and uplm_hdlr ev hdr = match getType ev,hdr with

    (* Ping Message.
     *)
  | (ECast iov|ESend iov|ECastUnrel iov|ESendUnrel iov), Ping(failed,cnts) ->
      let origin = getPeer ev in
      logp (fun () -> sprintf "Ping from %d %s" origin (Arrayf.int_to_string cnts)) ;
      if origin <> ls.rank		(* Check just in case. *)
      & (not (Arrayf.get failed ls.rank)) (* BUG: could auto-fail him *)
      & (not (Arrayf.get s.failed origin))
      then (
	s.recv.(origin) <- int_max s.recv.(origin) (Arrayf.get cnts ls.rank) ;
        s.send.(origin) <- int_max s.send.(origin) (Arrayf.get cnts origin) ;
(*	dump vf s*)
      ) else (
	logp (fun () -> sprintf "dropping ping") ;
      ) ;
      free name ev

  | _ -> failwith unknown_local

  and upnm_hdlr ev = match getType ev with

    (* EFail: mark the failed members.
     *)
  | EFail ->
      s.failed <- getFailures ev ;
      upnm ev

    (* EInit: request a first timer alarm to bootstrap things.
     *)
  | EInit ->
      dnnm (timerAlarm name Time.zero) ;
      upnm ev

    (* ETimer: every so often:
     *   1. check for lagre changes in fuzziness
     *   2. ping the other members
     *)
  | ETimer ->
      let time = getTime ev in
      if Time.ge time s.next_sweep then (
        s.next_sweep <- Time.add time s.sweep ;
        dnnm (timerAlarm name s.next_sweep) ; (* request next sweep *)
      	logp (fun () -> sprintf "Pinging:%s" (Time.to_string time)) ;

        let ev = castUnrel name in
        array_incr s.send ls.rank ;
        log (fun () -> sprintf "sending ping %s" (Time.to_string s.next_sweep));
        dnlm ev (Ping(s.failed,Arrayf.of_array s.send)) ;

        let any = ref false in
        for i = 0 to pred ls.nmembers do
          if i <> ls.rank & not (Arrayf.get s.failed i) then (
            s.fuzziness.(i) <- s.send.(ls.rank) - s.recv.(i);
            if (abs (s.fuzziness.(i) - (Arrayf.get s.last_reported i))) >= s.fz_threshold then
              any := true
          )
        done;
	    logp (fun () -> sprintf "FZ Idles:%s" (conv ls.rank s.send.(ls.rank) s.recv)) ;
	    if !any then (
	      s.last_reported <- Arrayf.of_array (Array.copy s.fuzziness);
	      log (fun () -> sprintf "Fuzziness:%s" (Arrayf.int_to_string s.last_reported)) ;
	      dnnm (create name EFuzzyRequest[LocalFuzziness s.last_reported]) ;
        )
      ) ;
      upnm ev
  | EDump -> dump vf s ; upnm ev
  | _ -> upnm ev

  and dn_hdlr ev abv = dn ev abv ()
  and dnnm_hdlr = dnnm

in {up_in=up_hdlr;uplm_in=uplm_hdlr;upnm_in=upnm_hdlr;dn_in=dn_hdlr;dnnm_in=dnnm_hdlr}

let l args vf = Layer.hdr init hdlrs None NoOpt args vf

let _ =
  Param.default "fz_detect_spacing" (Param.Time (Time.of_int 1)) ;
  Param.default "fz_detect_sweep" (Param.Time (Time.of_int 1)) ;
  Param.default "fz_detect_threshold" (Param.Int 1) ;
  Layer.install name l

(**************************************************************)
