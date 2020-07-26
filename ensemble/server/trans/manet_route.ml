(**************************************************************)
(* MANET_ROUTE.ML : route messages in a mobile ad-hoc network *)
(* Author: Alon Kama, 02/03 *)
(**************************************************************)
open View
open Event
open Util
open Layer
open Trans
  (**************************************************************)
let name = Trace.filel "MANET_ROUTE"
(**************************************************************)
type msgid_t = int
type msgtype_t = MCAST_DATA | P2P_DATA | PATH | SEARCH

(* A route is a tuple containing the path, where the first element is the dest
   and the last element is the source (me), and the time the route was 
   established *)
type routes_t = rank array * Time.t

type 'abv bufmsg_t = BufMsg of msgid_t * Event.dn * 'abv * msgtype_t * rank * bool (*unrel*)

(* RouteInfo header consists of local seqno; route; msg tyupe; and destination*)
type header = 
NoHdr 
| RouteInfo of msgid_t * rank array * msgtype_t * rank * bool  (* Last BOOL is for unrel *)
| Ping of msgid_t

type 'abv state = {
  routes : routes_t option array;               (* all routes to peers *)
  p2p_buffer : 'abv bufmsg_t Queuee.t Arraye.t; (* store outgoing P2P msgs
                                                 * until there is a path to
                                                 * dest *)
	stagger_queue : 'abv bufmsg_t Queuee.t ;
  mutable msgid_count : msgid_t;                (* local seqno counter*)
  mutable forget_next: Time.t;                  (* When to delete old routes*)
  forget_interval : Time.t;                   (* How long til routes expire *)
  neighbor_inverse_probability : float;      (* Weight for how many immediate 
                                              * neighbors *)
  pt2pt_path_probability : float;            (* Weight for if this node is 
                                              * on a path *)
  mutable policy_flooding : bool;                   (* Whether the policy is to flood
                                             * all messages *)
  mutable neighbor_count : int;             (* How many immed neighbors *)
  mutable neighbor_count_var : int;         (* This is used for the actual 
                                             * counting.  Not valid until 
                                             * copied into neighbor_count. *)
  mutable debug_prob_val : int;
  mutable debug_prob_cnt : int;
  mutable debug_prob_hist : int array;
  mutable debug_prob_neighb : int array;
  mutable debug_prob_pt2pt : int array;
	mutable track_send : rank array;
  mutable last_seen : int array ;
	mutable search_count : int ;
	mutable path_count : int ;
	mutable blocked : bool
}

let routes_ref = ref (Some([|None|]))
let last_view  = ref None

let msgtype_to_int msgtype =
match msgtype with 
  | MCAST_DATA -> 1
  | P2P_DATA   -> 2
  | PATH       -> 3
  | SEARCH     -> 4

let msgtype_to_string msgtype =
match msgtype with 
  | MCAST_DATA -> "MCAST_DATA"
  | P2P_DATA -> "P2P_DATA"
  | PATH -> "PATH"
  | SEARCH -> "SEARCH"

(**************************************************************)

let find a me = 
let rec f i =
if i = Array.length a then
  -1
else if a.(i) = me then
  i
else f (succ i) in
  f 0

let get_backroute route = 
let backroute = Array.create (Array.length route) 0 in
  try 
    for i = 0 to Array.length route - 1 do
      backroute.(i) <- route.(Array.length route - i - 1);
    done;
    backroute
  with Invalid_argument s -> (
    Trace.make_failwith "Catch manet_route1: %s" s;
  )
    

(* Given route=[a1,a2,...,loc,...a_n-1], return
   init_subroute=[loc,loc-1,...,a1] and
   dest_subroute=[loc,loc+1,...,a_n-1] *)
let make_subroutes route loc = 
	let route_length = Array.length route in
	let init_subroute = Array.create (loc+1) 0 in
	let dest_subroute = Array.create (route_length - loc) 0 in
		assert (loc < Array.length route);
    Array.blit route 0   init_subroute 0 (Array.length init_subroute);
    Array.blit route loc dest_subroute 0 (Array.length dest_subroute);
    let init_subroute = get_backroute init_subroute in
      (init_subroute,dest_subroute)



(**************************************************************)
    
let dump vf s = Layer.layer_dump name (fun (ls,vs) s -> [|
                                         sprintf "p2p_buffer sizes = %s\n" (Arraye.int_to_string (Arraye.map Queuee.length s.p2p_buffer))
                                       |]) vf s

(**************************************************************)


let route_convert old_routes new_view = 
	let old_view = some_of name !last_view in
	let mapping = Arrayf.init (Arrayf.length old_view) 
		(fun i ->
			 let id_i = Arrayf.get old_view i in
				 try
					 Arrayf.index id_i new_view
				 with Not_found -> -1
		) in
	let translate_old = Arrayf.init (Array.length old_routes)
		(fun i ->
			 match old_routes.(i) with
				 | None -> None
				 | Some(old_route,time) ->
						 let new_route = Arrayf.init (Array.length old_route)
							 (fun i ->
									let id = old_route.(i) in
										Arrayf.get mapping id) in
							 if Arrayf.mem (-1) new_route then
								 None
							 else
								 Some(Arrayf.to_array new_route,time))
	in
	let new_routes = Arrayf.init (Arrayf.length new_view)
		(fun i -> 
			 let mapped_loc = 
				 try Arrayf.index i mapping 
				 with Not_found -> -1 
			 in
				 if mapped_loc = -1 then
					 None
				 else 
					 Arrayf.get translate_old mapped_loc)
	in
		Arrayf.to_array new_routes
				 

let init s (ls,vs) = 
try
  let forget_int = Time.of_int (Param.int vs.params "manetroute_forget_interval") in
  let neighbor_inverse_prob = 
  Param.float vs.params "manetroute_neighbor_inverse_probability" in
  let pt2pt_path_prob =
  Param.float vs.params "manetroute_pt2pt_path_probability" in
(*  let flooding = Param.bool vs.params "manetroute_flooding" in*)
  let buffer = Arraye.init ls.nmembers (fun _ -> Queuee.create ()) in
  let routes = 
		if ls.nmembers = 1 then 
			Array.create ls.nmembers None
		else
      route_convert (some_of name !routes_ref) vs.view
	in
    routes_ref := Some(routes);
		last_view := Some(vs.view);

(*    if (Array.length !routes_ref) > 1 then
      !routes_ref
    else *)
    routes.(ls.rank) <- Some([|ls.rank|], Time.gettimeofday ());
    { 
      routes = routes;
      p2p_buffer = buffer;
			stagger_queue = Queuee.create ();
      msgid_count = 0;
      forget_interval = forget_int;
      forget_next = Time.zero;
      neighbor_inverse_probability = neighbor_inverse_prob;
      pt2pt_path_probability = pt2pt_path_prob;
      policy_flooding = true;
      neighbor_count = 0;
      neighbor_count_var = 0;
      debug_prob_val = 0;
      debug_prob_cnt = 0;
      debug_prob_hist = Array.create 21 0;
      debug_prob_neighb = Array.create 11 0;
      debug_prob_pt2pt = Array.create 11 0 ;
			track_send = Array.create ls.nmembers 0;
      last_seen = Array.create ls.nmembers 0 ;
			search_count = 0;
			path_count = 0;
			blocked = false
    }
with Invalid_argument s -> (
  Trace.make_failwith "Catch manet_route4: %s" s;
)
  
(**************************************************************)

let hdlrs s ((ls,vs) as vf) {up_out=up;upnm_out=upnm;dn_out=dn;dnlm_out=dnlm;dnnm_out=dnnm;my_in=my} =
let failwith = layer_fail dump vf s name in
let log = Trace.log name  in
let next_msgid () = 
	let msgid = s.msgid_count in
		s.msgid_count <- succ s.msgid_count;
		msgid
in
let new_route route = Array.append route [|ls.rank|] in

let save_route s dest route = 
try
  let assign_route () = 
  log (fun () -> sprintf "Recording path to %d: %s\n" dest 
				                                            (string_of_int_array route));
  s.routes.(dest) <- Some(route,Time.gettimeofday ()) 
  in
		if dest <> ls.rank then
    match s.routes.(dest) with 
      | Some(old_route,_) -> 
        let route_length = Array.length route in
        let old_route_length = Array.length old_route in
          if route_length < old_route_length then
            assign_route ()
      | None ->
          assign_route ();
          let f bufmsg = match bufmsg with
            BufMsg(msgid,ev,abv,tag,dest,unrel) -> 
              log (fun () -> sprintf "Sending messages from Queue to %d\n" dest);
              dn ev abv (RouteInfo(msgid,route,tag,dest,unrel)) in
            Queuee.clean f (Arraye.get s.p2p_buffer dest)
with Invalid_argument s -> (
  Trace.make_failwith "Catch manet_route5: %s" s;
)
in

let cast_probability origin msgid = false
(*
if not (s.last_seen.(origin) >= msgid) && msgid < 10 then true
else match s.policy_flooding with
  true -> true
  | false -> (
      (* let prob = if (s.debug_prob_cnt mod 100) = 99 then 0.5 else 1.1 in *)
      let neighbor_prob = match s.neighbor_count with
        0 -> 1.
        | x -> s.neighbor_inverse_probability /. (float x) in
        (*      let neighbor_prob = min (abs_float neighbor_prob) 1. in *)
        
      let pt2pt_prob = match s.routes.(origin) with
        None -> 0.5
        | Some(_,route_started) ->
            let route_age = Time.sub (Time.gettimeofday ()) route_started in
            let route_age_ratio = (Time.to_float route_age) /. 
            (Time.to_float s.forget_interval) in
              s.pt2pt_path_probability *. route_age_ratio in
      let pt2pt_prob = min (abs_float pt2pt_prob) 1. in 
      let prob = (*(Random.float 100.) *.*) (neighbor_prob +. pt2pt_prob) in 

      (*      if s.debug_prob_cnt mod 500 = 0 then
              eprintf "neighb = %f, pt2pt = %f, prob = %f" neighbor_prob pt2pt_prob prob;*)
      let prob_round = (int_of_float (ceil (prob *. 10.))) in
      let neighb_round = (int_of_float (ceil (neighbor_prob *. 10.))) in
      let pt2pt_round = (int_of_float (ceil (pt2pt_prob *. 10.))) in

        if prob >= 1. then 
          s.debug_prob_val <- succ s.debug_prob_val;
        s.debug_prob_cnt <- succ s.debug_prob_cnt;
        (*      s.debug_prob_neighb.(neighb_round) <- succ s.debug_prob_neighb.(neighb_round);*)
        s.debug_prob_pt2pt.(pt2pt_round) <- succ s.debug_prob_pt2pt.(pt2pt_round);
        (*      s.debug_prob_hist.(prob_round) <- succ s.debug_prob_hist.(prob_round); *)
        prob > 1.
    ) 
*)
in






let up_hdlr ev abv hdr= match getType ev,hdr with
(*	| (ECast iov | ESend iov | ECastUnrel iov | ESendUnrel iov),NoHdr -> up ev abv*)

  | (ECast iov|ECastUnrel iov), RouteInfo(msgid,route,type_tag,dest,is_unrel) ->
			begin match type_tag with 
        | MCAST_DATA ->
						let source_id = route.(0) in
            let ttl = match getTTL ev with 
                Some i -> i | None -> 256 in
              (* Only process casts with ttl>=1 that haven't been 
							 * processed yet. 
               *)
              if ttl < 1 then
                log (fun () -> sprintf "TTL < 1, dropping %s" (to_string ev))
              else (
								(* Only consume a Cast message that I haven't seen before*)
								if find route ls.rank == -1 then (
									let new_ev = 
										if is_unrel then
											let new_iov () = Iovecl.copy iov in
												castUnrelIov name (new_iov ())
										else
											ev
									in
										up (setPeer name new_ev source_id) abv;
										if is_unrel then
											free name ev;
									
									(* PBcast the message, attaching my ID to the route *)
	                if cast_probability source_id msgid then (
                        (* Copy the event but decrement the TTL *)
                        let new_iov = Iovecl.copy iov in
                        let new_ev = match (getApplMsg ev) with
                          | true -> castIovAppl name new_iov
                          | false -> castIov name new_iov in
                        let new_ev = match ttl with 
                          | 256 -> new_ev
                          | x   -> set name new_ev [TTL (pred x)] in
                          log (fun () -> sprintf "ReBCast %d towards %d"
																                  msgid dest);
                          dn new_ev abv (RouteInfo(msgid, new_route route, 
																									 MCAST_DATA,dest,is_unrel))
  								)
								)
							)

				| P2P_DATA ->
						(* In P2P, route is [originator,...,recipient=dest] *)
						let source_id = route.(0) in
							if ls.rank = dest then begin
								log (fun () -> sprintf "(rank:%d)Received P2P message from %d" ls.rank source_id);
								let new_iov = Iovecl.copy iov in
								let new_ev = match (getApplMsg ev) with
									| false -> sendPeerIov name source_id new_iov
									| true  -> sendPeerIovAppl name source_id new_iov in
								let new_ev = 
									if is_unrel then
										setSendUnrelPeer name new_ev source_id
									else
										new_ev in
									up new_ev abv
							end;
							free name ev
				| _ -> failwith "Unexpected type_tag on up_hdlr"
			end






(*
      let source_id = route.(pred (Array.length route)) in
      let msg_type_str = msgtype_to_string type_tag in
        (*      eprintf "Got %s: #%d from P%d (via %d), route=%s\n" 
								msg_type_str msgid source_id (getPeer ev) 
								(string_of_int_array route) ;
        *)
        begin
          match type_tag with 
            | MCAST_DATA -> begin
                let ttl = match getTTL ev with 
                  Some i -> i
                  | None -> 256 in
                    (* Only process casts with ttl>=1 that haven't been 
										 * processed yet. Identify previously-seen casts by 
										 *  marking the routes array.
                     *)
                  if ttl < 1 then
                    log (fun () -> sprintf "TTL < 1, dropping %s" (to_string ev))
                  else 
										if find route ls.rank = -1 then begin
                      if cast_probability source_id msgid then
                        (* Copy the event but decrement the TTL *)
                        let new_iov = Iovecl.copy iov in
                        let new_ev = match (getApplMsg ev) with
                          | true -> castIovAppl name new_iov
                          | false -> castIov name new_iov in
                        let new_ev = match ttl with 
                          | 256 -> new_ev
                          | x   -> set name new_ev [TTL (pred x)] in
                          log (fun () -> sprintf "ReBCast %d towards %d" 
																                  msgid dest);
                          dn new_ev abv (RouteInfo(msgid, new_route route, 
																									 MCAST_DATA,dest))
                      end;
											if msgid > s.last_seen.(source_id) then (
												s.last_seen.(source_id) <- msgid;
												up (setPeer name ev source_id) abv;
											)
											else
												free name ev
              end
								
            | P2P_DATA ->
                (* If I am the intended recipient then deliver the message up.
                 * Otherwise if I am one of the nodes in the route, then 
                 * propagate the message.
                 *)


                if ls.rank = dest then begin
									if (getAlonFlag ev) then
										printf "MANET_ROUTE: COORD receiving AlonFlag message\n";
                  (* When sending up, spoof the origin to be the original sender *)
									if msgid > s.last_seen.(source_id) then (
										s.last_seen.(source_id) <- msgid;
										let new_iov = Iovecl.copy iov in
										let new_ev = match (getApplMsg ev) with
											| true -> sendPeerIovAppl name source_id new_iov
											| false-> sendPeerIov name source_id new_iov in
											up new_ev abv
									)
                end
                else if ls.rank <> source_id && ls.rank <>(getPeer ev) then begin
                  (* Propagate only when flooding or when received from the n
									 * neighbor immediately before me in line 
                   *)
                  let position = find route ls.rank in
                  let position_diff = position - (find route (getPeer ev)) in
                      if s.policy_flooding || position_diff = 1 then begin
												if msgid > s.last_seen.(source_id) then (
													s.last_seen.(source_id) <- msgid;

													let new_iov = Iovecl.copy iov in
													let new_ev = match (getApplMsg ev) with
														| true -> castIovAppl name new_iov
														| false -> castIov name new_iov in
														dn new_ev abv (RouteInfo(msgid, route, type_tag,dest))
												)
                      end
                end;
                free name ev
              | _ -> failwith "unknown tag for non-local message"
        end;
				s.last_seen.(source_id) <- max s.last_seen.(source_id) msgid
*)
  | ECast iov, NoHdr -> failwith "Got ECast with no header\n";
  | ECastUnrel iov, NoHdr -> failwith "Got ECastUnrel with no header\n";
  | (ESend _|ESendUnrel _),NoHdr ->failwith "Got ESend[Unrel] with no header\n";
  | _ ->  failwith "Got blahblah";
		



and uplm_hdlr ev hdr = match getType ev,hdr with
	| (ECast _|ECastUnrel _), RouteInfo(msgid,route,type_tag,dest,is_unrel) -> begin
      let source_id = route.(0) in
        match type_tag with 
          | SEARCH -> begin
              (* If I am the destination, then begin propagating a
               * PATH message
               *)
							if find route ls.rank <> -1 then 
								log (fun () -> sprintf "Dropping SEARCH message; already seen\n")
							else if ls.rank = dest then begin
								let full_route = new_route route in
                  log (fun () -> sprintf "Search from %d found me! %s\n"
												                  source_id "Sending PATH message" );
 									s.path_count <- succ s.path_count;
									dnlm (castEv name) (RouteInfo(msgid, full_route,
																								PATH,dest,is_unrel));
									save_route s source_id (get_backroute full_route)
							end
							else begin
                if not (is_none s.routes.(dest)) && (Random.float 100.) < 50. then (
                  let (myroute,_) = some_of name s.routes.(dest) in
                  let full_route = Array.append route myroute in
										if (Array.length myroute) > 2 then (
											(* If the destination is within earshot, I will
												 suppress sending anything, since the dest will
												 surely respond.  Therefore I will reply only if 
												 the dest is further away. *)
											log (fun () -> sprintf "Sending PATH %s from intermediate node %d"
														 (string_of_int_array full_route) ls.rank);
 											s.path_count <- succ s.path_count;
											dnlm (castEv name) (RouteInfo(msgid,full_route,
																										PATH,dest,is_unrel))
										)
                )
                else (
								  let full_route = new_route route in
									  if (Array.length full_route) < 1 && (Random.float 100.) < 50.
then (
(*								let route_to_dest = s.routes.(dest) in 
								let propagate_q = 
									if is_none route_to_dest then true
									else 
										let (r,_) = some_of name route_to_dest in
											(Array.length r) > (Array.length full_route)
								in
									if propagate_q then 
*)
										  log (fun () -> sprintf "Propagating SEARCH to %d: %s"
												     dest (string_of_int_array full_route));
 											s.search_count <- succ s.search_count;
									dnlm (castEv name) (RouteInfo(msgid, full_route,
																									SEARCH,dest,is_unrel));
										(* Save the route that was created thus far *)
										save_route s source_id (get_backroute full_route)
									  )
                )
							end;
							free name ev
						end
					| PATH -> begin
              (* This is a message signifying that a route has been 
							 * established. The route's first cell corresponds to the node 
               * that initiated SEARCH (the "initiator"); the route's last cell
               * is the node that initiated PATH (the "destination").
               * If I am an intermediate node, then I will save portions of 
               * this route to both initiator and destination.
               *)
              let initiator = route.(0) in
                if (initiator = ls.rank) then begin
									log (fun () -> sprintf "Received PATH message from %d: %s"
                                dest (string_of_int_array route));
                  save_route s dest route
                end
								else begin
									(* Propagate this PATH message only if I am on it, and
										 its previous sender is right before me in the path *)
                  let my_pos = find route ls.rank in
                  let sender_pos = find route (getPeer ev) in
                  let pos_diff = my_pos - sender_pos in
										if my_pos <> -1 && pos_diff = -1 then begin
                      let (init_subroute,dest_subroute) = 
												                  make_subroutes route my_pos in
                        save_route s initiator init_subroute;
                        save_route s dest dest_subroute;
												log (fun () -> sprintf "Propagating PATH to %d: %s"
															              dest (string_of_int_array route));
 												s.path_count <- succ s.path_count;
                        dnlm(castEv name)(RouteInfo(msgid, route,PATH,dest,is_unrel))
                    end
								end;
								free name ev
						end
					| _ -> failwith "unknown tag for local message"
		end















(*  match getType ev,hdr with
    | (ECast iov|ECastUnrel iov), RouteInfo(msgid,route,type_tag,dest) ->
        let source_id = route.(pred (Array.length route)) in
        let msg_type_str = msgtype_to_string type_tag in
          (* if (source_id <> ls.rank) && (getPeer ev <> ls.rank) then 
             log (fun () -> sprintf "Got %s: #%d from P%d (via %d), 
						                         dest=%d route=%s\n"
                                     msg_type_str msgid source_id (getPeer ev) 
                                     dest (string_of_int_array route)) ;
          *)
        let new_ev iov = castIov name (Iovecl.copy iov) in 
          begin
            match type_tag with 
              | SEARCH -> (
                  (* If I am the destination, then begin propagating a
                   * PATH message
                   *)
                  try
                    if find route ls.rank = -1 && ls.rank = dest then begin
                      let nroute = new_route route in
                        log (fun () -> sprintf "Search from %d found me! %s\n"
												                      source_id "Sending PATH message" );
                        dnlm (new_ev iov) (RouteInfo(msgid, nroute, PATH, 
																										 source_id));
                        save_route s source_id nroute;
                    end
                    else if find route ls.rank <> -1 then
                      (* I am already in the route, don't make it cyclic *)
                      ()
                    else (
                      let nroute = new_route route in
                        (* Propagate the message to my neighbors *)
                        log (fun () -> sprintf "Propagating SEARCH to %d: %s" 
															               dest (string_of_int_array nroute));
                        dnlm (new_ev iov) (RouteInfo(msgid, nroute, SEARCH,dest))
                    )
                  with Invalid_argument s -> (
                    Trace.make_failwith "Catch manet_route15: %s" s;
                  )
                )
              | PATH -> (
                  (* This is a message signifying that a route has been 
									 * established. The route's first cell corresponds to the node 
                   * that initiated PATH (the "initiator"); the route's last cell
                   * is the node that initiated SEARCH (the "destination").
                   * If I am an intermediate node, then I will save portions of 
                   * this route to both initiator and destination.
                   *)
                  try 
                    let initiator = route.(0) in
                      if (dest = ls.rank) then begin
                        save_route s initiator route
                      end
                      else if initiator <> ls.rank then
                        let my_pos = find route ls.rank in
                        let sender_pos = find route (getPeer ev) in
                        let pos_diff = my_pos - sender_pos in
                          if (my_pos <> -1) && pos_diff = 1 then begin
                            let (init_subroute,dest_subroute) = 
                                                   make_subroutes route my_pos in
                              save_route s initiator init_subroute;
                              save_route s dest dest_subroute;
															log (fun () -> sprintf "Propagating PATH to %d: %s"
																		          dest (string_of_int_array route));

                              dnlm(new_ev iov)(RouteInfo(msgid, route,PATH,dest))
                          end
                  with Invalid_argument s -> (
                    Trace.make_failwith "Catch manet_route11: %s" s;
                  )
                )
              | _ -> failwith "unknown tag for local message"
          end; 
          free name ev

    | ECastUnrel iov, Ping(rank) ->
        (* Count every EStable message coming in, because this shows who my 
         * neighbors are.  This counter is reset when I send out my own EStable
         * message. 
         *)
        if rank <> ls.rank then
          s.neighbor_count_var <- succ s.neighbor_count_var;
				free name ev
*)             
    | _ -> failwith unknown_local

and upnm_hdlr ev = match getType ev with
  | ETimer -> if not s.blocked then (
      (*      if ls.am_coord then printf "I am coord\n";*)
      try
				let is_timerset = not (Queuee.empty s.stagger_queue) in
(*					if is_timerset then begin
						let space_out  = 
							let spacing = 0.3 in
							let rltv = (float ls.rank) /. (float ls.nmembers) in
							let time = mod_float rltv spacing in
								printf "MANET_ROUTE stagger: %f\n" time;
								Time.add (Time.of_float 0.3) (Time.of_float time)
						in
						let f bufmsg = match bufmsg with
								BufMsg(msgid,ev,abv,tag,dest) -> 
									log (fun () -> sprintf "Sending messages from Queue to %d\n" dest);
									dn ev abv (RouteInfo(msgid,[|ls.rank|],tag,dest)) in 
							(
								match Queuee.takeopt s.stagger_queue with
									| None -> ()
									| Some v -> f v
							);
							my (timerAlarm name (Time.add (getTime ev) space_out))
					end;
							
								
*)

(*				if ls.am_coord then printf "isBlocked=%b\n" s.blocked;*)

(*        let time = getTime ev in
          if Time.ge time s.forget_next then begin
            s.forget_next <- Time.add time s.forget_interval ;
            
            let time = Time.sub time s.forget_interval in
              for i = 0 to pred (Array.length s.routes) do
                if_some s.routes.(i) 
                  (fun (_,oldTime) -> 
                     if Time.ge time oldTime then
                       s.routes.(i) <- None)
              done
          end;
*)
(*          log (fun () -> sprintf "(%d) Manet_route ETimer: s.blocked=%b\n" vs.ltime s.blocked);*)
          for i = 0 to pred (Arraye.length s.p2p_buffer) do
            if not (Queuee.empty (Arraye.get s.p2p_buffer i)) then begin
							let msgid = next_msgid () in
              log (fun () -> sprintf "Sending duplicate SEARCH #%d to P%d\n" msgid i);
								let debug_send = s.track_send.(i) > 10 in
									if debug_send then printf "Sending duplicate SEARCH #%d to P%d\n" msgid i;
 									s.search_count <- succ s.search_count;
									dnlm (castEv name) (RouteInfo(msgid, [|ls.rank|], SEARCH,i,true));
            end
          done;
					if not is_timerset then
						my (timerAlarm name (Time.add (getTime ev) (Time.of_int 2)));

(*
          let ping_ev = castUnrel name in
          let ping_ev = set name ping_ev [TTL 1] in
            dnlm ping_ev (Ping(ls.rank));
            s.neighbor_count <- s.neighbor_count_var;
            s.neighbor_count_var <- 0;

            free name ev
*)      with Invalid_argument s -> (
        Trace.make_failwith "Catch manet_route11: %s" s;
      )
    )
  | EView ->
      log (fun () -> sprintf "Average cast probability (%d casts):  %f\n" s.debug_prob_cnt ((float s.debug_prob_val) /. (float s.debug_prob_cnt)));
      upnm ev

  | EDump -> ( dump vf s ; upnm ev )
	| EBlock -> 
			log (fun () -> sprintf "Manet_route EBLOCK\n");
			s.blocked <- true ;
			s.policy_flooding <- true;
			for i = 0 to pred ls.nmembers do
				Queuee.clear (Arraye.get s.p2p_buffer i)
			done;
			upnm ev

  | EInit ->
				if not ls.am_coord && is_none s.routes.(vs.coord) then (
					log (fun ()->sprintf "Manet_route: EInit, starting SEARCH to coord");
 					s.search_count <- succ s.search_count;
					dnlm (castEv name) (RouteInfo(next_msgid (), [|ls.rank|], SEARCH,vs.coord,true));
				);
				my (timerAlarm name (Time.add (getTime ev) (Time.of_int 0))) ;
				upnm ev
  | EExit -> 
			s.blocked <- true;
			for i = 0 to pred ls.nmembers do
				let f bufmsg = match bufmsg with
          BufMsg(_,_,_,_,_,_) -> () in
          Queuee.clean f (Arraye.get s.p2p_buffer i)
			done;
			printf "\n\n\n\nSEARCH MESSAGES=%d,  PATH MESSAGES=%d\n\n\n\n\n" s.search_count s.path_count;

			log (fun () -> sprintf "Manet_route: EExit\n");
          (*      printf "Average cast probability (%d casts):  %f\n" s.debug_prob_cnt ((float s.debug_prob_val) /. (float s.debug_prob_cnt));*)
          (*      printf "Histogram (0.1 -> 2.0): %s\n" (string_of_int_array s.debug_prob_hist);  
                  printf "Nieghb hist (0.0 -> 1.0): %s\n" (string_of_int_array s.debug_prob_neighb);*)
          (*      printf "Pt2pt hist (0.0 -> 1.0): %s\n" (string_of_int_array s.debug_prob_pt2pt); *)
      upnm ev
				
  | _ -> upnm ev

and dn_hdlr ev abv = 
					let msgid = next_msgid () in
	let new_ev iov = 
		let new_iov = Iovecl.copy iov in
			match (getApplMsg ev) with
					true -> castIovAppl name new_iov
				| false -> castIov name new_iov
	in
		match getType ev with
			| ECast iov ->			

						dn ev abv (RouteInfo(msgid, [|ls.rank|], MCAST_DATA,ls.rank,false))
			| ECastUnrel iov  -> 
(*						if msgid < 5*ls.nmembers then (				
							Queuee.add (BufMsg(msgid, new_ev iov, abv, MCAST_DATA,(getPeer ev))) s.stagger_queue;
							free name ev
						)
						else
*)							dn ev abv (RouteInfo(msgid, [|ls.rank|], MCAST_DATA,ls.rank,true))
			| ESend iov ->
					let dest = getPeer ev in
						
					let debug_send = s.track_send.(dest) > 10 in
						s.track_send.(dest) <- succ s.track_send.(dest);
						
						(*          let route = [|ls.rank;dest|] in  *)
						let route =
							if is_none s.routes.(dest) then
								[|ls.rank|]
							else
								let (r,_) = some_of name s.routes.(dest) in r
						in
							if (Array.length route > 1) then (
							log (fun () -> sprintf "(rank=%d)Sending P2P to %d" ls.rank dest);
(*								if debug_send then
									printf "MANET_ROUTE:DEBUG:(rank=%d)Sending P2P to %d\n" ls.rank dest;*)
								let msgid = next_msgid () in
(*									if msgid < 10 then (
										Queuee.add (BufMsg(msgid, new_ev iov, abv, P2P_DATA,dest)) s.stagger_queue;
										free name ev
									)
									else
*)
									dn (new_ev iov) abv (RouteInfo(next_msgid(),route, P2P_DATA, dest,false));
									free name ev
							)
							else (
(*							if debug_send then
								printf "MANET_ROUTE:DEBUG:No path to %d, queueing\n." dest;*)

							let dest_queue = Arraye.get s.p2p_buffer dest in
								if Queuee.empty dest_queue then (
									log (fun () -> sprintf "No path to %d, queueing msg" dest);
 									s.search_count <- succ s.search_count;
									dnlm (castEv name) (RouteInfo(next_msgid (), [|ls.rank|], SEARCH,dest,true));
								);
								log (fun () -> sprintf "Queueing message intended for %d" dest);
								Queuee.add (BufMsg(next_msgid (), new_ev iov, abv, P2P_DATA,dest,false)) dest_queue;
								free name ev
						)

			| ESendUnrel iov ->
					let dest = getPeer ev in
						
					let debug_send = s.track_send.(dest) > 10 in
						s.track_send.(dest) <- succ s.track_send.(dest);
						
						(*          let route = [|ls.rank;dest|] in  *)
						let route =
							if is_none s.routes.(dest) then
								[|ls.rank|]
							else
								let (r,_) = some_of name s.routes.(dest) in r
						in
							if (Array.length route > 1) then (
							log (fun () -> sprintf "(rank=%d)Sending P2P to %d" ls.rank dest);
(*								if debug_send then
									printf "MANET_ROUTE:DEBUG:(rank=%d)Sending P2P to %d\n" ls.rank dest;*)
								let msgid = next_msgid () in
(*									if msgid < 10 then (
										Queuee.add (BufMsg(msgid, new_ev iov, abv, P2P_DATA,dest)) s.stagger_queue;
										free name ev
									)
									else
*)
									dn (new_ev iov) abv (RouteInfo(next_msgid(),route, P2P_DATA, dest,true));
									free name ev
							)
							else (
(*							if debug_send then
								printf "MANET_ROUTE:DEBUG:No path to %d, queueing\n." dest;*)

							let dest_queue = Arraye.get s.p2p_buffer dest in
								if Queuee.empty dest_queue then (
									log (fun () -> sprintf "No path to %d, queueing msg" dest);
 									s.search_count <- succ s.search_count;
									dnlm (castEv name) (RouteInfo(next_msgid (), [|ls.rank|], SEARCH,dest,true));
								);
								log (fun () -> sprintf "Queueing message intended for %d" dest);
								Queuee.add (BufMsg(next_msgid (), new_ev iov, abv, P2P_DATA,dest,true)) dest_queue;
								free name ev
						)

(*  | ECast iov | ECastUnrel iov ->
      (* Multicast: message is sent along with a unique signature *)
      s.msgid_count <- succ s.msgid_count; 
			if s.msgid_count == 200*ls.nmembers then (
				s.policy_flooding <-  Param.bool vs.params "manetroute_flooding"; 
			)
      dn ev abv (RouteInfo(s.msgid_count, [|ls.rank|], MCAST_DATA,ls.rank)) 
			*) 
(*  | ESend iov | ESendUnrel iov -> (
			if (getAlonFlag ev) then
				printf "MANET_ROUTE: Sending P2P to COORD\n";

      try
        let dest = getPeer ev in
        let new_ev iov = 
					let new_iov = Iovecl.copy iov in
					let tmp_new_ev = 
						match (getApplMsg ev) with
								true -> castIovAppl name new_iov
							| false -> castIov name new_iov in
					let tmp_new_ev2 = 
						if getAlonFlag ev then 
							setAlonFlag name tmp_new_ev
						else 
							tmp_new_ev in
						set name tmp_new_ev2 (getExtend ev) in
					
          s.msgid_count <- succ s.msgid_count;
					if s.msgid_count = 200*ls.nmembers then (
						s.policy_flooding <-  Param.bool vs.params "manetroute_flooding";
					);

          (* Send:  If the route is unknown, keep the message in the buffer
           * and send out a SEARCH message; otherwise send the pt2pt message
           * along the route
           *)
          if (not s.policy_flooding) && is_none s.routes.(dest) then begin
            log (fun () -> sprintf "No route to dest=%d; message responsible: 
                                    %s\n" dest (Event.to_string ev));
            Queuee.add (BufMsg(s.msgid_count, new_ev iov, abv, P2P_DATA)) 
              (Arraye.get s.p2p_buffer dest);
          end
          else begin
            let (route,_) = 
							if s.policy_flooding then ([|dest ; ls.rank|],Time.zero)
							else some_of name s.routes.(dest) in
							if (getAlonFlag ev) then
								printf "MANET_ROUTE(%d): _Really_ sending P2P to COORD\n" vs.ltime;
							
              dn (new_ev iov) abv (RouteInfo(s.msgid_count,route, P2P_DATA, dest))
          end;
          free name ev
      with Invalid_argument s -> (
        Trace.make_failwith "Catch manet_route10: %s" s;
      )
    )*)
  | _ -> dn ev abv NoHdr

and dnnm_hdlr ev = match getType ev with
  | _ -> dnnm ev

in {up_in=up_hdlr;uplm_in=uplm_hdlr;upnm_in=upnm_hdlr;dn_in=dn_hdlr;dnnm_in=dnnm_hdlr}

let l args vs = Layer.hdr init hdlrs None NoOpt args vs

let _ = 
(* How often to forget routes *)
Param.default "manetroute_forget_interval" (Param.Int 5);
Param.default "manetroute_neighbor_inverse_probability" (Param.Float 1.);
Param.default "manetroute_pt2pt_path_probability" (Param.Float 1.);
Param.default "manetroute_flooding" (Param.Bool false);
Layer.install name l

(**************************************************************)
