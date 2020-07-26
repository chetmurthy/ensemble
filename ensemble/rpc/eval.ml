(**************************************************************)
(* EVAL.ML *)
(* Author: Robbert vanRenesse *)
(**************************************************************)
(*********************************************************************

Each server is identified by a host address and a port on that host.
Each RPC specifies a list of servers.  The list of servers may be
updated.  The question is:  how do we pick a server?

The current idea is to assign to each server a preference value.
We also assign a preference value to each host.  The preference value
of the server may depend on:

	1) the preference value of the host
		(depends on distance, load, and availability)
	2) the confidence in the server
		(depends on availability)
	3) load information provided by the server
		(depends on load)

It's probably convenient to keep these values between 0 and 1.
Initially, let's use the following simple rules:

	1) the confidence value of a server is initially .5.  When a
	   connection to it fails, we reduce it to 0.  After that it
	   goes up using the function 1 - 1/(t + 1.1), where t is time.
	   When a connect succeeds, we improve it all the way to 1.
	2) the confidence value of a host is the maximum of the
	   confidence values of the servers on that host.
	3) the preference value of a server is half the confidence
	   value of the server + half the confidence value of the
	   host.

We chose a server based on a probabilistic rule.  Let S be the sum
of the preference values of the list of servers.  The probability
that we pick a particular server is then its preference value divided
by S.

*********************************************************************)

(* This is the time that is needed in seconds for a confidence value
 * to grow from 0 to 1/2.
 *)
let half_time = 60.

(* The up/down state of a server or host.  In case of DOWN, it specifies
 * since when it has been down.
 *)
type availability = UP | DOWN of Time.t

(* This describes a server.
 *)
type server_info = {
  mutable avail : availability;
  mutable conf_value : float;
  mutable pref_value : float
}

(* This is a list that associates servers with their server_info.
 *)
let servers = ref ([] : ((string * int) * server_info) list)

(* This is a list that associates hosts with their confidence value.
 *)
let hosts = ref []

(* Bring a server down.
 *)
let bring_down server =
  let info = List.assoc server !servers in
  info.avail <- DOWN (Time.gettimeofday())

(* Take a server up.
 *)
let bring_up server =
  let info = List.assoc server !servers in
  info.avail <- UP

(* Calculate the confidence values of all servers.
 *)
let conf_servers servers =
  let now = Time.gettimeofday() in
  let now = Time.to_float now in
  let confidence = function
      UP -> 1.
    | DOWN time ->
	let time = Time.to_float time in
        let down_time = (now -. time) /. half_time in
        1. -. 1. /. (1. +. down_time)
  in
  let set_conf (_, info) = info.conf_value <- confidence info.avail in
  List.iter set_conf servers

(* Calculate the confidence values of all hosts based on the
 * confidence values of the given servers.
 *)
let conf_hosts servers =
  let update ((host, _), info) =
    let (current, rest) = Xlist.take host !hosts in
    hosts := (host, max current info.conf_value) :: rest
  in
  List.iter update servers

(* Calculate the preference values of all servers in the given list.
 *)
let pref_servers servers =
  let preference host info =
    let conf_host = List.assoc host !hosts in
    (0.5 *. conf_host) +. (0.5 *. info.conf_value)
  in
  let set_pref ((host, _), info) =
    info.pref_value <- preference host info
  in
  List.iter set_pref servers

(* Add a new server to the list of servers.
 *)
let add_server host port =
  hosts := Xlist.insert_if_new (host, 1.0) !hosts;
  servers := Xlist.insert_if_new ((host, port),
    { avail = UP; conf_value = 1.0; pref_value = 1.0 }) !servers

(* Recalculate the preference values for all the servers.
 *)
let recalculate _ =
  conf_servers !servers;
  conf_hosts !servers;
  pref_servers !servers

(* Pick a server at random from the given list, based on their
 * preference values.
 *)
let pick_server list =
  let rec project total sublist = function
      hd :: tl ->
	let info = List.assoc hd !servers in
        project (total +. info.pref_value) ((hd, info) :: sublist) tl
    | [] ->
	(total, sublist)
  in
  let rec pick total choice = function
      (server, info) :: tl ->
	let total = info.pref_value +. total in
        if total >= choice then
	  server
	else
	  pick total choice tl
    | [] ->
	raise Not_found
  in	  
  let (total, info_list) = project 0. [] list in
  let choice = Random.float total in
  pick 0. choice info_list

