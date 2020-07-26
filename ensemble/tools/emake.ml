(*
type info = {
  name : string ;
  depends : string list ;
  mutable time : int ;
  mutable compiled : bool ;
}

let info = Hashtbl.create 100
let failed = Hashtbl.create 100

let run () =
  let depends = open_in ".depend.marsh" in
  let depends = input_value depend in
  
  let q1 = Queue.create () in
  let q2 = Queue.create () in

  begin try while true do
    let file = Queue.take q1 in
    let depends = Hashtbl.find_all file depends in
    List.iter (fun file ->
      Queue.add file q2
    ) depends
  done with Queue.empty -> () end ;

  begin try while true do
    let file = Queue.take q2 in
    let depends = Hashtbl.find_all file depends in
    let stat = Unix.stat file in

    let rec loop = function [] -> true | depend::tl ->
      let failed = 
      	try Hashtbl.find depend failed ; true
        with Not_found -> false
      in
     
      if failed then (
      	Hashtbl.add file failed ;
	true
      ) else (
	let stat_dep = Unix.stat depend in
	if stat_dep.st_mtime < stat.st_mtime then loop tl else (
	  true
        )
      )
    in

    if loop depends then (
      printf "make %s\n" file ;
      flush stdout
    ) ;
  done with Queue.empty -> () end
*)
