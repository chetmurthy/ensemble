(**************************************************************)
(* LINKER.MLI *)
(* Author: Mark Hayden, 12/98 *)
(**************************************************************)
open Trans
(**************************************************************)

(* The type of an exported object.
 *)
type 'a t
type alpha
type beta
type gamma
type delta

(* Get is used to acquire a (possibly) dynamically
 * linked object.
 *)
val get : debug -> 'a t -> 'a

(* Put is used by the dynamically linked object
 * to install it's value upon initialization.
 *)
val put : 'a t -> 'a -> unit

(**************************************************************)
val set_ensemble_lib : string -> unit
(**************************************************************)
(* Manage alarm tables.
 *)

val alarm_install  : name -> (Alarm.gorp -> Alarm.t) -> unit
val alarm_choose   : name -> Alarm.gorp -> Alarm.t
val alarm_get_hack : unit -> Alarm.t

(**************************************************************)
(* Domain management.
 *)

val domain_of_mode : Alarm.t -> Addr.id -> Domain.t
val domain_install : Addr.id -> (Alarm.t -> Domain.t) -> unit

(**************************************************************)
(* Layer management.
 *)

val layer_install : name -> ('a,'b,'c) Layer.basic -> unit
val layer_get : name -> ('a,'b,'c) Layer.basic
val layer_look_again : name -> (alpha,beta,gamma) Layer.basic
val layer_install_finder : string -> (name -> (alpha,beta,gamma) Layer.basic) -> unit

(**************************************************************)
(* The rest of this interface includes the non-layer objects
 * that may be dynamically linked into the system.  Usually,
 * the names refer to module and an object within the module.
 * For instance, the function "init" in the "Reflect" module
 * is exported from here as "reflect_init".  Other modules
 * can then get the value corresponding to "Reflect.init" as
 * [Elink.get Elink.reflect_init].
 *)

(* Groupd stuff.
 *)
type manage_t = View.full -> (View.full -> (Event.up -> unit) -> (Event.dn -> unit)) -> unit
val manage_create :  (Alarm.t -> View.full -> (manage_t * View.full * Appl_intf.Old.t)) t
val manage_proxy : (Alarm.t -> Hsys.socket -> manage_t) t
val manage_create_proxy_server : (Alarm.t -> port -> View.full -> (View.full * Appl_intf.Old.t)) t

(* Gossip server.
 *)
val reflect_init :
  (Alarm.t -> View.full -> port -> bool -> (View.full * Appl_intf.New.t)) t

(* Hsyssupp.
 *)
type 'a hsyssupp_conn =
  debug -> (Iovecl.t -> unit) ->
  ((Iovecl.t -> unit) * (unit -> unit) * 'a)

type 'a hsyssupp_client =
  debug -> Alarm.t -> Hsys.socket -> 'a hsyssupp_conn -> 'a

val hsyssupp_connect : (debug -> port -> inet list -> bool -> bool -> Hsys.socket) t
val hsyssupp_server : (debug -> Alarm.t -> port -> unit hsyssupp_conn -> unit) t
val hsyssupp_client : (alpha hsyssupp_client) t
val get_hsyssupp_client : debug -> 'a hsyssupp_client

(* Protos.
 *)
type protos_config = View.full -> Layer.state -> unit
val protos_make_marsh :
  (Mbuf.t ->
   (Appl_intf.Protosi.message -> Iovecl.t) * 
    (Iovecl.t -> Appl_intf.Protosi.message)) t

val protos_client :
  (Alarm.t -> debug -> (Appl_intf.Protosi.message -> unit) ->
  ((Appl_intf.Protosi.message -> unit) * (unit -> unit) * protos_config)) t

val protos_server :
 (Alarm.t ->
  (Addr.id list -> Addr.set) ->
  (Appl_intf.New.t -> View.full -> unit) ->
  debug -> (Appl_intf.Protosi.message -> unit) ->
  ((Appl_intf.Protosi.message -> unit) * (unit -> unit) * unit)) t


(* Transport and alarm stuff.
 *)
val udp_domain : (Alarm.t -> Domain.t) t
val tcp_domain : (Alarm.t -> Domain.t) t
val netsim_domain : (Alarm.t -> Domain.t) t
val netsim_alarm : (Alarm.gorp -> Alarm.t) t
val real_alarm : (Alarm.gorp -> Alarm.t) t
val htk_alarm : (Alarm.gorp -> Alarm.t) t
val htk_init : (Alarm.t -> unit) t
val mpi_domain : (Alarm.t -> Domain.t) t
val atm_domain : (Alarm.t -> Domain.t) t

(* Routers.
 *)
val scale_f : (Mbuf.t -> (Trans.rank -> Obj.t option -> int -> Iovecl.t -> unit) Route.t) t
val unsigned_f : (Mbuf.t -> (Obj.t option -> int -> Iovecl.t -> unit) Route.t) t
val raw_f : (Mbuf.t -> (Iovecl.t -> unit) Route.t) t
val signed_f : (Mbuf.t -> (Obj.t option -> int -> Iovecl.t -> unit) Route.t) t
val bypassr_f : (Mbuf.t -> (int -> Iovecl.t -> unit) Route.t) t

(* Powermarsh.
 *)
type 'a powermarsh_f  = 
  debug -> Mbuf.t -> (('a * Iovecl.t) -> Iovecl.t) * (Iovecl.t -> ('a * Iovecl.t))
val powermarsh_f : alpha powermarsh_f t
val get_powermarsh_f : debug -> 'a powermarsh_f

(* Appl_old.
 *)
type ('a,'b,'c,'d) appl_old_full = ('a,'b,'c,'d) Appl_intf.Old.full -> Appl_intf.Old.t
type ('a,'b,'c,'d) appl_old_ident = debug -> ('a,'b,'c,'d) Appl_intf.Old.full -> ('a,'b,'c,'d) Appl_intf.Old.full
val appl_old_full : (alpha,beta,gamma,delta) appl_old_full t
val get_appl_old_full : debug -> ('a,'b,'c,'d) appl_old_full
val appl_old_debug : (alpha,beta,gamma,delta) appl_old_ident t
val get_appl_old_debug : debug -> ('a,'b,'c,'d) appl_old_ident
val appl_old_timed : (alpha,beta,gamma,delta) appl_old_ident t
val get_appl_old_timed : debug -> ('a,'b,'c,'d) appl_old_ident
val appl_old_iov : (Mbuf.t -> Appl_intf.Old.iov -> Appl_intf.Old.t) t

(* Appl_power.
 *)
type ('a,'b,'c,'d) appl_power_oldf = Mbuf.t -> ('a,'b,'c,'d) Appl_intf.Old.power -> Appl_intf.Old.t
val appl_power_oldf : (alpha,beta,gamma,delta) appl_power_oldf t
val get_appl_power_oldf : debug -> ('a,'b,'c,'d) appl_power_oldf

type 'a appl_power_newf = Mbuf.t -> 'a Appl_intf.New.power -> Appl_intf.New.t
val appl_power_newf : alpha appl_power_newf t
val get_appl_power_newf : debug -> 'a appl_power_newf

(* Appl_debug.
 *)
type 'a appl_new_debug = debug -> 'a Appl_intf.New.full -> 'a Appl_intf.New.full
val appl_debug_f : alpha appl_new_debug t
val get_appl_debug_f : debug -> 'a appl_new_debug
val appl_debug_view : alpha appl_new_debug t
val get_appl_debug_view : debug -> 'a appl_new_debug

(* Appl_lwe.
 *)
val appl_lwe_f : (Alarm.t -> View.full -> 
  (Endpt.id * Iovecl.t Appl_intf.New.full) list -> 
    (View.full * ((Appl_intf.appl_lwe_header * unit) * Iovecl.t)Appl_intf.New.full)) t
type 'a appl_lwe_pf =
 Alarm.t -> View.full -> 
  (Endpt.id * ('a * Iovecl.t) Appl_intf.New.full) list -> 
    (View.full * ((Appl_intf.appl_lwe_header * 'a) * Iovecl.t) Appl_intf.New.full)
val appl_lwe_pf : alpha appl_lwe_pf t
val get_appl_lwe_pf : debug -> 'a appl_lwe_pf

(* Appl_multi.
 *)
val appl_multi_f : (Appl_intf.New.t array -> Appl_intf.appl_multi_header Appl_intf.New.power) t

(* Appl_aggr.
 *)
type 'a appl_aggr_f = 'a Appl_intf.New.full -> Appl_intf.New.t
val appl_aggr_f : alpha appl_aggr_f t
val get_appl_aggr_f : debug -> 'a appl_aggr_f

(* Appl_compat.
 *)
val appl_compat_compat : (Appl_intf.Old.t -> ((unit,unit)Appl_intf.appl_compat_header * Iovecl.t) Appl_intf.New.full) t
type ('a,'b,'c,'d) appl_compat_pcompat = ('a,'b,'c,'d) Appl_intf.Old.power -> (('a,'b)Appl_intf.appl_compat_header * Iovecl.t) Appl_intf.New.full
val appl_compat_pcompat : (alpha,beta,gamma,delta) appl_compat_pcompat t
val get_appl_compat_pcompat : debug -> ('a,'b,'c,'d) appl_compat_pcompat

(* Appl_handle.
 *)
val appl_handle_new : (alpha Appl_handle.New.full -> Appl_handle.handle_gen * alpha Appl_intf.New.full) t
val appl_handle_old : ((alpha,beta,gamma,delta) Appl_handle.Old.full -> 
  Appl_handle.handle_gen * (alpha,beta,gamma,delta) Appl_intf.Old.full) t

(* Debug.
 *)
val debug_client : (Alarm.t -> inet -> port -> unit) t
val debug_server : (Alarm.t -> port -> unit) t

(* Heap analysis.
 *)
val heap_analyze : (unit -> unit) t

(* Partition simulation.
 *)
val partition_connected : (float -> Endpt.id -> Endpt.id -> bool) t

(* Timestamp.
 *)
val timestamp_add : (string -> unit -> unit) t
val timestamp_print : (unit -> unit) t
