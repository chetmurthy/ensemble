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
(* ELINK.ML *)
(* Author: Mark Hayden, 12/98 *)
(**************************************************************)
open Trans
open Util
(**************************************************************)
let name = Trace.file "ELINK"
let failwith s = Trace.make_failwith name s
let log = Trace.log name
(**************************************************************)

let inited = ref false

(* This a list of all modules that need to be made available
 * to dynamically linked code.  This is probably incomplete
 * and should be grown when other modules are found to be
 * needed.  They are all put into one string to make them
 * compact for GC.
 *)
let modules = "\
  Priq Route Socket Hsys Hsyssupp \
  Alarm Appl_intf Appl_lwe Appl_multi \
  Trans Timestamp Alarm Domain Conn \
  Queuee Fqueue Mcredit Version \
  Param Addr Manage Mutil Proxy Actual \
  Security Ipmc Unique Endpt Group \
  Event Once Property Async Buf Refcnt \
  Powermarsh Iovec Iovecl Pool Marsh \
  Partition Iq Lset Mbuf Arge Appl \
  Glue Proto Request Sched Stack_id \
  Switch Time Trace Transport Layer \
  Util Arrayop View Bottom Mnak Pt2pt \
  Sync Top_appl Partial_appl Resource \
  Arraye Arrayf Elink Protos \
  Lset Handler \
\
  Queue List Unix Array Weak Digest \
  Gc Obj Arg String Pervasives Random \
  Hashtbl Sort"

let ensemble_lib = ref None
let set_ensemble_lib s = ensemble_lib := Some s
let ensemble_lib () =
  match !ensemble_lib with
  | None -> "."
  | Some s -> s

let init modname =
  if not !inited then (
    inited := true ;
    begin
      try Dynlink.init ()
      with Not_found ->
	  eprintf "ELINK:unable to initialize Dynlink library (for %s), exiting\n" modname ;
	  eprintf "  (this probably means that you configured Ensemble to use a subset\n" ;
          eprintf "  of its libraries and you did not enable dynamic linking.  A module\n" ;
          eprintf "  your program needs is not staticly linked\n" ;
	  exit 1
    end ;

    let camllib = 
      try [Sys.getenv "CAMLLIB"] with Not_found -> []
    in
    let loadpath = ensemble_lib () :: camllib  in

    let interfaces =
      let modules = Util.string_split " " modules in
      List.map (fun unit -> 
	try
	  (unit, Dynlink.digest_interface unit loadpath)
	with e ->
	  eprintf "ELINK:looking up interface for %s, exiting:%s\n" unit (Hsys.error e) ;
	  eprintf "  (load path is %s)\n" (string_of_list ident loadpath) ;
	  exit 1
      ) modules
    in
    begin
      try Dynlink.add_available_units interfaces
      with Dynlink.Error e ->
	eprintf "ELINK:dynlink error:%s\n" (Dynlink.error_message e) ;
	exit 1
    end
  )

let load_module debug name =
  init (debug^":"^name) ;
  log (fun () -> sprintf "dynamically linking %s" name) ;
  let name = String.lowercase name in
  begin try
    Dynlink.loadfile (Filename.concat (ensemble_lib ()) (name ^ ".cmo"))
  with Dynlink.Error e ->
    eprintf "ELINK:dynlink error:%s\n" (Dynlink.error_message e) ;
    raise Not_found
  end

type package = {
  name : string ;
  mutable loaded : bool ;
  modules : string list ;
  requires : package list
}

type 'a t = {
  vname : string ;
  package : package ;
  mutable data : 'a option
}

type alpha = string
type beta = string
type gamma = string
type delta = string

let package name modules requires = {
  name = name ;
  loaded = false ;
  modules = modules ;
  requires = requires
} 

let package_simple name = package name [name] []

let create name package = {
  vname = name ;
  package = package ;
  data = None
}

(* Create a simple, single file, single value module.
 *)
let create_simple modu vname =
  create vname (package_simple modu)

let put r v =
  r.data <- Some v

let rec load debug p =
  let debug = debug^":"^p.name in
  if not p.loaded then (
    List.iter (fun reqs ->
      load debug reqs
    ) p.requires ;
    List.iter (fun name ->
      load_module debug name
    ) p.modules ;
    p.loaded <- true
  )

let get debug r =
  if r.data = None then
    load debug r.package ;
  match r.data with
  | None ->
      eprintf "ELINK:error looking for package %s:%s\n" r.package.name r.vname ;
      failwith "not available"
  | Some data ->
      data

(**************************************************************)
(* Alarm management.
 *)

let alarms = ref []

let alarm_install id a =
  alarms := (id,a) :: !alarms

let chosen = ref None

let alarm_choose alarm gorp =
  let alarm = string_uppercase alarm in
  let a = 
    try List.assoc alarm !alarms with Not_found ->
      eprintf "ELINK:alarm %s not installed, exiting" alarm ;
      exit 1
  in
  match !chosen with
  | Some a -> a
  | None ->
      let a = a gorp in
      chosen := Some a ;
      a

let alarm_get_hack () = 
  match !chosen with
  | None -> failwith "no alarm chosen"
  | Some a -> a

(**************************************************************)
(* Domain management.
 *)

let dormant = ref []
let activated = ref []

let domain_install id d =
  dormant := (id,d) :: !dormant

let domain_of_mode alarm mode =
  (* Use the Udp domain for Deering and Sp2.
   *)
  let mode = match mode with
  | Addr.Deering -> Addr.Udp
  | Addr.Sp2 -> Addr.Udp
  | _ -> mode
  in

  (* If in activated list, use that.
   *)
  try 
    List.assoc mode !activated 
  with Not_found -> (
    try
      (* Look up in dormant list.
       *)
      let d = List.assoc mode !dormant in

      (* Remove it from dormant list.
       *)
      dormant := 
        List.fold_left (fun o ((i,_) as it) ->
	  if mode = i then o else it :: o
        ) [] !dormant ;

      (* Enable the domain and add to activated list.
       *)
      let d = d alarm in
      activated := (mode,d) :: !activated ;
      d
    with Not_found ->
      eprintf "DOMAIN:domain '%s' not installed, exiting\n"
      (Addr.string_of_id mode) ;
      exit 1
  )

(**************************************************************)
(* Layer management.  The type casting here is kind of messed
 * up here, but things still work.
 *)

let layer_table = 
  let table = Hashtbl.create 47 in
  Trace.install_root (fun () ->
    [sprintf "ELINK:#layers=%d" (hashtbl_size table)]
  ) ;
  table

let rec(*no inline*) layer_install name l = 
  let name = string_uppercase name in
  let l = (l : ('a,'b,'c) Layer.basic) in
  let l = Obj.magic l in
  let l = (l : (alpha,beta,gamma) Layer.basic) in
  Hashtbl.add layer_table name l

let layer_lookup name = 
  let name = string_uppercase name in
  Hashtbl.find layer_table name

let procurers = ref ["internal_table",layer_lookup]

let layer_install_finder name lookup =
  procurers := !procurers @ [name,lookup]

let layer_get name =
  let rec loop = function
  | [] ->
      eprintf "ELINK:couldn't find layer:%s\n" name ;
      failwith "no such layer"
  | (_,lookup) ::tl -> (
      try
	let l = lookup name in
	let l = (l : (alpha,beta,gamma) Layer.basic) in
	let l = Obj.magic l in
	let l = (l : ('a,'b,'c) Layer.basic) in
	l
      with Not_found ->
	loop tl
    )
  in loop !procurers

let layer_look_again name =
  layer_lookup name

let layer_list () =
  eprintf "  ELINK:Installed Layers\n" ;
  Hashtbl.iter (fun name _ ->
    eprintf "	%s\n" name
  ) layer_table

(**************************************************************)
(* Layer dynamic linking.
 *)

let requires = [
  "Total",["Request"] ;
  "Mflow",["Mcredit"] ;
  "Causal",["Mcausal"];
  "Dbg",["Dtbl"];
  "Pr_stable",["Arrayop"];
  "Pr_suspect",["Arrayop"];
  "DbgBatch",["Dtbl";"Dtblbatch"]
] 

let find name =
  let requires = 
    try List.assoc name requires
    with Not_found -> []
  in
  List.iter (load_module "Elink.layer:requires") requires ;
  load_module "Elink.layer" name ;
  layer_look_again name

let _ =
  layer_install_finder "DynamicLink" find

(**************************************************************)

(* Groupd.
 *)
type manage_t = View.full -> (View.full -> (Event.up -> unit) -> (Event.dn -> unit)) -> unit
let groupd = package "Groupd" ["mutil"; "proxy"; "member"; "coord"; "actual"; "manage"] []
let manage_create = create "Manage.create" groupd
let manage_proxy = create "Manage.proxy" groupd
let manage_create_proxy_server = create "Manage.create_proxy_server" groupd

(* Reflect.
 *)
let reflect = package_simple "Reflect"
let reflect_init = create "init" reflect

(* Protos.
 *)
type protos_config = View.full -> Layer.state -> unit
let protos = package_simple "Protos"
let protos_server = create "server" protos
let protos_client = create "client" protos
let protos_make_marsh = create "make_marsh" protos

(* Hsyssupp.
 *)
type 'a hsyssupp_conn =
  debug -> (Iovecl.t -> unit) ->
  ((Iovecl.t -> unit) * (unit -> unit) * 'a)

let hsyssupp = package_simple "Hsyssupp"
let hsyssupp_connect = create "connect" hsyssupp
let hsyssupp_server = create "server" hsyssupp
let hsyssupp_client = create "client" hsyssupp

(* Powermarsh.
 *)
let powermarsh_f = create_simple "Powermarsh" "f"

(* Appl_old.
 *)
let appl_old = package_simple "Appl_old"
let appl_old_debug = create "debug" appl_old
let appl_old_full = create "full" appl_old
let appl_old_timed = create "timed" appl_old
let appl_old_iov = create "iov" appl_old

(* Appl_lwe.
 *)
let appl_lwe = package_simple "Appl_lwe"
let appl_lwe_f = create "f" appl_lwe
let appl_lwe_pf = create "pf" appl_lwe

(* Appl_multi.
 *)
let appl_multi_f = create_simple "Appl_multi" "f"

(* Appl_aggr.
 *)
let appl_aggr_f = create_simple "Appl_aggr" "f"

(* Appl_power.
 *)
let appl_power_oldf = create_simple "Appl_power" "oldf"
let appl_power_newf = create_simple "Appl_power" "newf"

(* Appl_debug.
 *)
let appl_debug = package_simple "Appl_debug"
let appl_debug_f = create "f" appl_debug
let appl_debug_view = create "view" appl_debug

(* Appl_compat.
 *)
let appl_compat = package_simple "Appl_compat"
let appl_compat_compat = create "compat" appl_compat
let appl_compat_pcompat = create "pcompat" appl_compat

(* Appl_handle/Handle.
 *)
let appl_handle = package_simple "Handle"
let appl_handle_old = create "old" appl_handle
let appl_handle_new = create "new" appl_handle

(* Install dynamic linkers for the various domains.
 *)
let domain = "domain"
let alarm = "alarm"
let real_alarm = create_simple "Real" alarm
let udp = package "Udp" ["ipmc";"udp"] []
let udp_domain = create domain udp
let tcp_domain = create_simple "Tcp" domain
let eth_domain = create_simple "Eth" domain
let mpi_domain = create_simple "Mpi" domain
let atm_domain = create_simple "Atm" domain
let netsim = package_simple "Netsim"
let netsim_domain = create domain netsim
let netsim_alarm = create alarm netsim
let htk = package_simple "Htk"
let htk_alarm = create alarm htk
let htk_init = create "init" htk

let _ = 
  alarm_install "REAL" (fun s -> (get name real_alarm s)) ;
  alarm_install "NETSIM" (fun s -> (get name netsim_alarm s)) ;
  domain_install Addr.Udp (fun a -> (get name udp_domain) a) ;
  domain_install Addr.Tcp (fun a -> (get name tcp_domain) a) ;
  domain_install Addr.Eth (fun a -> (get name eth_domain) a) ;
  domain_install Addr.Netsim (fun a -> (get name netsim_domain) a)

(* Routers.
 *)
let scale_f = create_simple "Scale" "f"
let unsigned_f = create_simple "Unsigned" "f"
let signed_f = create_simple "Signed" "f"
let raw_f = create_simple "Raw" "f"
let bypassr_f = create_simple "Bypassr" "f"

(* Debug.
 *)
let debug = package_simple "Debug"
let debug_client = create "client" debug
let debug_server = create "server" debug

(* Heap analysis.
 *)
let heap_analyze = create_simple "Heap" "analyze"

(* Partion simulation.
 *)
let partition_connected = create_simple "Partition" "connected"

(* Timestamps. 
 *)
let timestamp = package_simple "Timestamp"
let timestamp_add = create "add" timestamp 
let timestamp_print = create "print" timestamp 

(**************************************************************)
(**************************************************************)

(* The polymorphic values exported in these interface all use
 * the fixed "alpha" types.  In the following code we generate
 * special "get" functions to generalize the types of these
 * values to make them polymorphic once again using
 * Obj.magic via this fuction, generalize.  This stuff is
 * inherently not type safe, but the hackery it is wrapped in
 * should make it difficult to mess things up.  
 *)

let generalize = Obj.magic

type 'a hsyssupp_client =
  debug -> Alarm.t -> Hsys.socket ->
    'a hsyssupp_conn -> 'a

let get_hsyssupp_client name = 
  (generalize (get name hsyssupp_client : alpha hsyssupp_client) : 'a hsyssupp_client)

type 'a powermarsh_f  = 
  debug -> Mbuf.t -> (('a * Iovecl.t) -> Iovecl.t) * (Iovecl.t -> ('a * Iovecl.t))

let get_powermarsh_f name = (generalize (get name powermarsh_f : alpha powermarsh_f) : 'a powermarsh_f)

type ('a,'b,'c,'d) appl_old_full = ('a,'b,'c,'d) Appl_intf.Old.full -> Appl_intf.Old.t
type ('a,'b,'c,'d) appl_old_ident = debug -> ('a,'b,'c,'d) Appl_intf.Old.full -> ('a,'b,'c,'d) Appl_intf.Old.full

let get_appl_old_debug name = 
  (generalize (get name appl_old_debug : (alpha,beta,gamma,delta)appl_old_ident) : ('a,'b,'c,'d) appl_old_ident)
let get_appl_old_timed name =
  (generalize (get name appl_old_timed : (alpha,beta,gamma,delta)appl_old_ident) : ('a,'b,'c,'d) appl_old_ident)
let get_appl_old_full name =
  (generalize (get name appl_old_full : (alpha,beta,gamma,delta)appl_old_full) : ('a,'b,'c,'d) appl_old_full)

type 'a appl_lwe_pf =
 Alarm.t -> View.full -> 
  (Endpt.id * ('a * Iovecl.t) Appl_intf.New.full) list -> 
    (View.full * ((Appl_intf.appl_lwe_header * 'a) * Iovecl.t) Appl_intf.New.full)

let get_appl_lwe_pf name = (generalize (get name appl_lwe_pf : alpha appl_lwe_pf) : 'a appl_lwe_pf)

type 'a appl_aggr_f = 'a Appl_intf.New.full -> Appl_intf.New.t

let get_appl_aggr_f name = (generalize (get name appl_aggr_f : alpha appl_aggr_f) : 'a appl_aggr_f)

type ('a,'b,'c,'d) appl_power_oldf = Mbuf.t -> ('a,'b,'c,'d) Appl_intf.Old.power -> Appl_intf.Old.t

let get_appl_power_oldf name =
  (generalize (get name appl_power_oldf : (alpha,beta,gamma,delta)appl_power_oldf) : ('a,'b,'c,'d)appl_power_oldf)

type 'a appl_power_newf = Mbuf.t -> 'a Appl_intf.New.power -> Appl_intf.New.t

let get_appl_power_newf name = 
  (generalize (get name appl_power_newf : alpha appl_power_newf) : 'a appl_power_newf)

type 'a appl_new_debug = debug -> 'a Appl_intf.New.full -> 'a Appl_intf.New.full

let get_appl_debug_f name = (generalize (get name appl_debug_f : alpha appl_new_debug) : 'a appl_new_debug)

let get_appl_debug_view name = (generalize (get name appl_debug_view : alpha appl_new_debug) : 'a appl_new_debug)

type ('a,'b,'c,'d) appl_compat_pcompat = ('a,'b,'c,'d) Appl_intf.Old.power -> (('a,'b)Appl_intf.appl_compat_header * Iovecl.t) Appl_intf.New.full

let get_appl_compat_pcompat name = (generalize (get name appl_compat_pcompat : (alpha,beta,gamma,delta) appl_compat_pcompat) : ('a,'b,'c,'d) appl_compat_pcompat)

type 'a appl_handle_new = 'a Appl_handle.New.full -> Appl_handle.handle_gen * 'a Appl_intf.New.full
type ('a,'b,'c,'d) appl_handle_old = ('a,'b,'c,'d) Appl_handle.Old.full -> Appl_handle.handle_gen * ('a,'b,'c,'d) Appl_intf.Old.full

let get_appl_handle_new name = (generalize (get name appl_handle_new : alpha appl_handle_new) : 'a appl_handle_new)
let get_appl_handle_old name = (generalize (get name appl_handle_old : (alpha,beta,gamma,delta) appl_handle_old) : ('a,'b,'c,'d) appl_handle_old)

(**************************************************************)
(**************************************************************)
