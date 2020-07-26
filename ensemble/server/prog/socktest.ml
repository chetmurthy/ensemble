(**************************************************************)
(* SOCKTEST.ML: A test program for the native socket library. *)
(* Author: Ohad Rodeh 7/2001 *)
(**************************************************************)
open Ensemble
open Printf
open Buf

let ident x = x
let string_of_list f c l = "[" ^ String.concat c (List.map f l) ^ "]"
let string_of_string_list l =  string_of_list ident "|" l

let flush () = Pervasives.flush Pervasives.stdout

let split s = 
  let rec loop s accu = 
    try 
      if String.length s = 0 then accu
      else 
	let i =	String.index s ' ' in
	let s1 = String.sub s 0 i in
	if i < String.length s then 
	  let s2 = String.sub s (i+1) (String.length s - (i+1)) in
	  loop s2 (s1::accu)
	else s1::accu
    with Not_found -> s::accu
  in 
  let l = List.rev (loop s []) in
  List.find_all (fun x -> x <> "") l
       

(**************************************************************)
let setup_xmit_sock xmitport = 
  try 
    let sock = Hsys.socket_mcast () in
    Hsys.setsockopt sock Hsys.Reuse;
    Hsys.bind sock Unix.inet_addr_any xmitport;
    Hsys.setsockopt sock (Hsys.Nonblock true);
    sock
  with e -> 
    printf "%s\n" (Util.error e);
    raise e

let setup_recv_sock rmtaddr = 
  printf "setup_recv_sock\n"; flush ();
  let port = 
    match rmtaddr with 
	Unix.ADDR_INET (inet,port) -> 
	  if not (Hsys.in_multicast inet) then (
	    printf "address = %s is not a D class address\n" 
	  (Unix.string_of_inet_addr inet); 
	  flush ();
	  failwith "Sanity"
	) else
	  port
    | _ -> failwith "Sanity"
  in
  let sock = Hsys.socket_mcast () in
  Hsys.setsockopt sock (Hsys.Loopback true);
  Hsys.setsockopt sock Hsys.Reuse;
  Hsys.bind sock Unix.inet_addr_any port;
  Hsys.setsockopt sock (Hsys.Nonblock true);
  sock


(**************************************************************)
let xmit_sock = ref None

type ipm_rec = {
  addr : Unix.inet_addr ;
  recv_sock : Unix.file_descr
}

type gs = {
  group_arr : ipm_rec option array ;
  mutable sock_l : Unix.file_descr list
}

let gs = {
  group_arr = Array.create 10 None ;
  sock_l = []
}

let remove_addr addr = 
  Array.iteri (fun i x  -> 
    match x with 
	None -> () 
      | Some x -> 
	  if x.addr = addr then (
	    Hsys.setsockopt x.recv_sock (Hsys.Leave addr);
	    Hsys.close x.recv_sock;
	    gs.group_arr.(i) <- None
	  ) 
  ) gs.group_arr;
  let sock_l = Array.fold_left (fun accu x -> 
    match x with 
	None -> accu
      | Some x ->x.recv_sock :: accu 
  ) [] gs.group_arr in
  gs.sock_l <- sock_l


let send_addr addr msg = 
  Array.iteri (fun i x -> 
    match x with 
	None -> ()
      | Some x -> 
	  if x.addr = addr then (
	    match !xmit_sock with 
		None -> 
		  printf "No xmit socket yet\n"
	      | Some xmit -> 
		  let info = Hsys.sendto_info xmit [|addr,2000|] in
		  let msg = Buf.of_string msg in
		  Hsys.udp_send info msg len0 (Buf.length msg);
		  ()
	  )
  ) gs.group_arr;
  ()

let add_new_group sock ipm_rec = 
  (try 
    Array.iteri (fun i x -> 
      match x with 
	  None -> 
	    gs.group_arr.(i) <- Some ipm_rec;
	    raise Exit
	| Some _ -> ()
    ) gs.group_arr;
    failwith "The number of groups has been exeeded. The maximum is 10\n"
  with Exit -> 
    ()
  );
  gs.sock_l <- sock :: gs.sock_l ;
  ()

let input_handler xmitsock line = 
  try (
    let words = split line in 
    printf "words=%s\n" (string_of_string_list words); flush ();
    match words with 
	[] ->
	  raise Exit
      | hd::tl -> 
	  match hd with 
	    | "Join" -> 
		let ipm_addr = 
		  match tl with 
		      [hd] -> hd
		    | _ -> 
			printf "wrong number of arguments\n";
			raise Exit
		in
		let ipm_addr = Unix.inet_addr_of_string ipm_addr in
		let rmt_addr = Unix.ADDR_INET(ipm_addr,2000) in
		let recv_sock = setup_recv_sock rmt_addr in
		let ipm_rec = {
		  addr = ipm_addr;
		  recv_sock = recv_sock
		} in
		Hsys.setsockopt recv_sock (Hsys.Join (ipm_addr,Hsys.Both)) ;
		add_new_group recv_sock ipm_rec ;
		()

	    | "Leave" -> 
		let ipm_addr = 
		  match tl with 
		      [hd] -> hd
		    | _ -> 
			printf "wrong number of arguments";
			raise Exit
		in
		let ipm_addr = Unix.inet_addr_of_string ipm_addr in
		remove_addr ipm_addr;
		printf "Leave\n"; flush () ;
		()

	    | "Cast" -> 
		let ipm_addr,msg = 
		  match tl with 
		      [hd;msg] -> hd,msg
		    | _ -> 
			printf "wrong number of arguments\n";
			raise Exit
		in
		let ipm_addr = Unix.inet_addr_of_string ipm_addr in
		send_addr ipm_addr msg;
		()
	    | "Ttl" -> 
		let ttl = 
		  match tl with
		      [ttl] -> (
			try 
			  int_of_string ttl
			with _ -> 
			  printf "argument must be a string\n";
			  raise Exit
		      )
		    | _ -> 
			printf "wrong number of arguments\n";
			raise Exit
		in
		Hsys.setsockopt xmitsock (Hsys.Ttl ttl);
		printf "Set the xmit TTL to %d\n" ttl;
		()

	    | "Loopback" -> 
		let onoff = 
		  match tl with
		      [onoff] -> (
			try 
			  bool_of_string onoff
			with _ -> 
			  printf "argument must be a boolean [true; false]\n";
			  raise Exit
		      )
		    | _ -> 
			printf "wrong number of arguments\n";
			raise Exit
		in
		Hsys.setsockopt xmitsock (Hsys.Loopback onoff);
		printf "Set the loopback on the xmit socket to %b\n" onoff;
		()

	    | "Sendbuf" -> 
		let size = 
		  match tl with
		      [size] -> (
			try 
			  int_of_string size
			with _ -> 
			  printf "argument must be an int\n";
			  raise Exit
		      )
		    | _ -> 
			printf "wrong number of arguments\n";
			raise Exit
		in
		Hsys.setsockopt xmitsock (Hsys.Sendbuf size);
		printf "Set the size of the sendbuf to to %d\n" size;
		()

	    | "Recvbuf" -> 
		let size = 
		  match tl with
		      [size] -> (
			try 
			  int_of_string size
			with _ -> 
			  printf "argument must be an int\n";
			  raise Exit
		      )
		    | _ -> 
			printf "wrong number of arguments\n";
			raise Exit
		in
		Hsys.setsockopt xmitsock (Hsys.Recvbuf size);
		printf "Set the size of the recvbuf to to %d\n" size;
		()

	    | "Nonblock" -> 
		let onoff = 
		  match tl with
		      [onoff] -> (
			try 
			  bool_of_string onoff
			with _ -> 
			  printf "argument must be a boolean\n";
			  raise Exit
		      )
		    | _ -> 
			printf "wrong number of arguments\n";
			raise Exit
		in
		Hsys.setsockopt xmitsock (Hsys.Nonblock onoff);
		printf "Set the xmit socket (blocking mode) to %b\n" onoff;
		()

	    | _ -> 
		printf "No such command\n"; flush ();
		raise Exit
  )
  with 
      Exit -> 
	printf "MENU:\n";
	printf "\t Join [ipm_addr]\n";
	printf "\t Leave [ipm_addr]\n";
	printf "\t Cast [ipm_addr msg]\n";
	printf "\t Ttl [num]\n";
	printf "\t Loopback [onoff]\n";
	printf "\t Sendbuf [size]\n";
	printf "\t Recvbuf [size]\n";
	printf "\t Nonblock [onoff]\n";
	flush ();
	()
    | e -> 
	printf "Uncaught error %s\n" (Util.error e);
	flush ();
	exit 0    

(**************************************************************)

let run () = 
  let xmitport = 0 in
  let recvport = 2000 in

  let xmitsock = setup_xmit_sock xmitport in
  printf "setup_xmit_sock Ok.\n"; flush ();

  begin try 
    Hsys.setsockopt xmitsock (Hsys.Loopback false);
    Hsys.setsockopt xmitsock (Hsys.Ttl 1);
  with _ -> 
    let os_t_v = Socket.os_type_and_version () in
    match os_t_v with 
	Socket.OS_Unix -> exit 1
      | Socket.OS_Win v -> 
	  match v with 
	      Socket.Win_2000 -> exit 1
	    | _ -> 
		eprintf "On Win32 (other than win2000) this is ok, continuing\n"
  end;

  xmit_sock := Some xmitsock ;

  let stdin = Hsys.stdin () in
  let buf = String.create 100 in

  let input_line () =
    let len = Hsys.read stdin buf 0 100 in
    String.sub buf 0 len
  in

  printf "before mainloop\n"; flush ();
  try 
    while true do 
      let r = Array.of_list (stdin::gs.sock_l) in
      let b = Array.map (fun _ -> false) r in
      let info = Hsys.select_info (Some (r,b)) None None in
      let num = Hsys.select  info {Hsys.sec10=1; Hsys.usec=0} in
      printf "select done\n"; flush ();
      (*printf "num>0(\n"; flush ();*)

	(*stdin*)
	if b.(0) then (
	  printf "reading from stdin\n"; flush ();
	  let line = input_line () in
	  (* Remove the newline character from the end of the line
	    *)
	  if String.length line > 0 then (
	    let line = String.sub line 0 (String.length line - 1) in
	    input_handler xmitsock line
	  )
	);

	(* The rest of the sockets.
	 *)
	for i=1 to (Array.length b -1) do 
	  if b.(i) then (
	    let len,_ = Socket.recvfrom r.(i) buf 0 100 in
	    printf "recv: %s\n" (String.sub buf 0 len);
	    flush ()
	  )
	done
    done
  with e -> 
    printf "Uncaught Unix error %s\n" (Util.error e);
    exit 0   

let _ = 
  Appl.exec ["socktest"] run
